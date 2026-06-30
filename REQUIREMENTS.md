# Money Tracker — Requirements & Design Guide

## What the app does

Reads bank SMS messages, extracts transaction amounts, and categorizes spending automatically.
Monthly view shows credit vs debit totals, a pie chart breakdown by category, and drill-down into each category to see sub-categories and individual transactions. Transactions can optionally be synced across devices via Firebase/Firestore.

---

## Implemented

### SMS Parsing

**Filter** (`_whySkipped()` in `sms_service.dart`): a message is treated as a bank transaction if it passes two checks:
1. Body contains `"debited"` or `"credited"`
2. `extractLast4(body)` returns non-null — a masked account/card number must be present (e.g. `XXXX1234`, `**1234`, `a/c XX1234`)

This replaces the old "bank keyword" filter. It prevents wallet credits, mobile recharges, and other non-bank "credited" messages from being parsed.

**SMS reading**: uses a native `MethodChannel` (`money_tracker/sms`) implemented in `MainActivity.kt` — not the `flutter_sms_inbox` package. The native path reads directly from Android's `ContentResolver` with no message cap (the package was hardcapped at 1000). The package remains a dependency but is unused.

**Incremental import**: `lastImportedAt` (epoch ms) is stored in the `settings` table. On import, `sinceMs` is passed as a SQL `WHERE date > ?` directly to the Android `ContentResolver`. Full scan passes `null`. The import dialog lets the user choose between the two.

**Amount extraction** uses a two-list combinatorial approach:

```
currencies  = [₹, INR, Indian Rupees, Rupees, Rs, USD, $, EUR, €, GBP, £, ...]
separators  = ["", " ", ".", ". ", ":", ": ", "-", " - ", "/", " /"]
```

For every `(currency, separator)` pair the code searches for that token then reads the number immediately after. INR currencies are tried first — so a message like `"INR 1921.97 … USD 23.00"` correctly yields ₹1921.97, not $23.

**Foreign currency conversion**: if no INR amount is found but a foreign one is, the amount is converted to INR using live rates from `api.frankfurter.app` (free, no API key). Rates are cached for 6 hours. Hardcoded fallback rates are used when the network is unavailable. The description field shows the original amount: `[USD 23.00 → ₹1921]`.

**Dual SIM**: Android stores messages from both SIMs in the same inbox database. Both are read automatically.

### Categorization

Two-pass rule application happens everywhere transactions are displayed (`transactions` getter in `AppProvider`, and `getHistoryMonths()`):
1. **Merchant extraction rules** — override the payee name only
2. **Categorization rules** — override category + sub-category only

Built-in categorization falls back to `categorizer_service.dart`, which keyword-matches in order (more specific before generic):

| Category | What goes here |
|---|---|
| **Grocery** | Blinkit, Zepto, Swiggy Instamart, BigBasket, JioMart, DMart, Reliance Fresh, supermarkets, kirana |
| **Food** | Zomato, Swiggy (food), McDonald's, Dominos, KFC, restaurants, cafes, bakeries |
| **Essential** | Rent, Electricity, Gas, Water, Internet/Mobile recharge, Insurance, EMI/Loans |
| **Transport** | Uber, Ola, Rapido, Metro, Fuel (petrol/CNG), Parking, FastTag |
| **Fun** | Netflix, Hotstar, Spotify, Movies (BookMyShow), Gaming, Events |
| **Shopping** | Amazon, Flipkart, Myntra, Nykaa, Ajio, Meesho |
| **Health** | Pharmacy, Hospital, Doctor, Diagnostics, Gym/Wellness |
| **Travel** | Flights (MakeMyTrip, Indigo…), Hotels (OYO…), IRCTC, RedBus |
| **Investment** | Mutual Funds/SIP, Stocks (Zerodha, Groww…), Gold, FD/RD |
| **Others** | Anything that doesn't match a keyword |

### Custom Rules

Users can define two types of rules (stored in `custom_rules` SQLite table, synced to cloud):
- **Merchant extraction rules** — regex prefix + terminator to pull a payee name from the SMS body
- **Categorization rules** — keyword list that maps to a category + sub-category

Rules are toggled enabled/disabled individually without deletion.

### Custom Categories

Users can create their own categories (name, color, icon) stored in `custom_categories`. The `allCategories` getter in `category_info.dart` merges built-ins with user categories — all UI that lists categories uses this, never the raw `kCategoryMeta` map directly.

### Category Exclusion from Overview

On the overview/home screen, users can tap a category chip to exclude it from the totals and pie chart. Useful for hiding Investment from "money I actually spent" calculations. State is persisted across sessions.

### Manual Entry

Users can add transactions manually via a form with auto-categorization as they type the merchant name. Works on both platforms; required on iOS where SMS cannot be read.

### Soft Delete

Deleting a transaction moves it to `deleted_transactions` (same schema + `deletedAt` column). The raw SMS body is preserved. Deduplication during import checks both tables (`allExistingRawMessages()`), so restored-then-deleted transactions don't re-import.

The SMS Debug screen → Deleted tab lets you:
- **Add Back** — restores to active transactions
- **Remove** (permanent) — deletes from `deleted_transactions` entirely, allowing the SMS to be re-imported fresh on next scan (useful if a transaction was stored with wrong amount before a bug fix)
- **Tap** to expand and see the full raw SMS body; **long-press** to copy it

### Accounts

Bank accounts are auto-discovered from SMS (last-4 digits + bank code). Each account has an `isTracked` flag. Untracked accounts are excluded from import. Stored in `accounts` table.

### Cloud Sync (Firebase/Firestore)

Optional. User signs in with Google. Push/pull syncs transactions across devices.

**Data structure** under `users/{uid}/`:
- `months/{YYYY-MM}` — active transactions, keyed by `rawMessage`
- `deleted-months/{YYYY-MM}` — deleted transactions (same structure)
- `data/accounts`, `data/rules`, `data/categories`
- `data/deletions` — union set of all deleted `rawMessage` strings across devices

**Push merge semantics**: reads cloud state first, layers local on top (local wins on conflict), strips locally-deleted rawMessages from the active set. Deleted transactions are synced to `deleted-months`. Rules are merged by id (cloud first, local wins). The `deletions` list only ever grows.

**Pull merge semantics**: fetches cloud active + deleted transactions. Skips rawMessages in the cloud deletions list. Inserts fresh active transactions. Applies soft-delete to any local active transactions that appear in the cloud deletions list. Inserts cloud deleted transactions into local `deleted_transactions`.

**Security**: data is encrypted at rest by Google. Firestore Security Rules must be set to restrict each user to their own `users/{uid}` path:
```
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```
This is not end-to-end encrypted — Google has backend admin access in principle.

### SMS Diagnostic Screen

Tap the bug icon (🐛) in the app bar to see every SMS from the selected month with four tabs:

| Tab | Content |
|---|---|
| **All** | Every SMS (color-coded) |
| **Parsed** | Successfully imported transactions |
| **Skipped** | Messages that passed the bank filter but couldn't be fully parsed |
| **Deleted** | Soft-deleted transactions with Add Back / Remove options + full SMS body |

Long-press any row to copy the raw SMS body.

### Trends Tab

Spending trend bar chart across months. Three independent filters that combine additively:
- Type filter (null / debit / credit)
- Above ₹10k only
- By category

`AutomaticKeepAliveClientMixin` keeps the tab alive across tab switches.

### Database

SQLite via `sqflite`, singleton `DatabaseService`. Current schema version: **7**.

| Table | Purpose |
|---|---|
| `transactions` | Active transactions |
| `deleted_transactions` | Soft-deleted (same schema + `deletedAt`) |
| `accounts` | Discovered bank accounts with `isTracked` flag |
| `custom_rules` | User-defined merchant extraction + categorization rules |
| `custom_categories` | User-created categories (name, color, icon codepoint) |
| `settings` | Key-value store; `lastImportedAt` drives incremental import |

### Tech Stack

| Concern | Library / Service |
|---|---|
| State management | `provider` |
| Local storage | `sqflite` |
| SMS reading (Android) | Native `MethodChannel` in `MainActivity.kt` |
| Charts | `fl_chart` |
| Date/number formatting | `intl` |
| Permissions | `permission_handler` |
| Exchange rates | `api.frankfurter.app` (free, no key) |
| Cloud sync | Firebase Auth (Google Sign-In) + Cloud Firestore |

---

## Known Limitations

- **iOS**: Apple does not allow apps to read the SMS inbox. Users must add transactions manually on iOS.
- **Play Store SMS permission**: `READ_SMS` is a sensitive permission requiring a declaration and possible manual review by Google. Apps for expense tracking have been approved but expect friction.
- **Merchant extraction**: relies on regex patterns for common bank SMS formats. Unusual formats may show "Unknown".
- **Keyword gaps**: if a merchant isn't in the keyword list it lands in Others.
- **Cloud not E2E encrypted**: data at rest is encrypted by Google, but not end-to-end. Google has backend admin access in principle.

---

## Planned Features

### 1. Shared Rule Library ("App Rules")

**Problem**: users spend time creating rules for common merchants (Swiggy, Blinkit, specific bank SMS formats). Rules for the same banks are identical across users.

**Idea**: build a curated library of rules that ships with app updates — visible in the Rules screen as a collapsible "App Rules" section. Users can disable individual app rules that don't fit their setup.

**How to grow the library**:
- Each device syncs its rules + per-rule match counts to Firestore (piggybacking on the existing rules sync).
- A **Firebase Cloud Function scheduled cron** runs periodically (e.g. weekly): reads all users' rule data, aggregates by rule pattern (same keywords + same bank prefix), counts how many users have it and total transactions matched.
- Developer reviews the aggregation in the Firebase console and manually promotes high-signal rules to an `app_rules` Firestore collection.
- The app fetches `app_rules` on sync/startup and merges them into the rule pipeline. No app update required to distribute new curated rules.
- Over time, rules that recur across users using the same bank SMS formats become part of the library automatically.

**Implementation sketch**:
- Add a `matchCount` column to `custom_rules` table; increment on each import pass.
- Push `matchCount` alongside rule data in the existing rules sync.
- Firebase Cloud Function (Node.js, scheduled trigger): aggregates `users/*/data/rules` across all users, groups by rule fingerprint, writes summary to `app_rules` collection.
- App rules have an `appRuleId` field. A `disabled_app_rules` settings key tracks which ones the user turned off.
- The Rules screen shows user rules first, then "App Rules (from Money Tracker)" section below, each with its match count and a toggle to disable.
- User rules always win over app rules on conflict (same keyword/pattern).

### 2. Order-Level Categorization (Notification Listener)

**Problem**: Blinkit shows ₹342 as one line. We don't know if that's milk or medicine.

**Idea**: capture order notification text from Zomato/Blinkit via Android `NotificationListenerService` (one-time permission), match to the payment SMS by amount + timestamp, attach item list to the transaction.

Recommended starting point: Notification Listener — zero per-order user action, same approach used by Walnut and Money View.

### 3. AI-Powered Categorization (Claude API fallback)

When a transaction lands in Others, call the Claude API with the raw SMS text to classify it. Only fire for "Others" transactions, batch at end of import, cache the result so the same merchant is never re-classified.

### 4. Analytics & Budgets

- Monthly spending trend line (last 6 months per category)
- Monthly budget per category with progress bar + push notification at 80%
- Year-over-year month comparison

### 5. Credit Card Statement Import

Parse PDF credit card statements (HDFC, ICICI, Axis, SBI) as an alternative to SMS.
