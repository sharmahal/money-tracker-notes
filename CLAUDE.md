# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on connected Android device
flutter run

# Analyze (no tests exist yet)
flutter analyze

# Build APK
flutter build apk
```

Android-only app — the SMS features are gated behind `Platform.isAndroid` checks throughout, so `flutter run` on iOS/macOS will launch but import is a no-op.

## Architecture

Single `AppProvider` (`lib/providers/app_provider.dart`) owns all mutable state and is provided at the root via `ChangeNotifierProvider`. Every screen reads from it via `context.watch/read`. No other state management layer exists.

### Data flow for SMS import

```
MainActivity.kt (MethodChannel "money_tracker/sms")
  └─ SmsService._readNative()          — raw SMS records, no cap
       └─ _whySkipped()                — filter: needs "debited"/"credited" + extractLast4() hit
            └─ fetchAllNew()           — parse amounts, types, merchants, apply custom rules
                 └─ AppProvider.importFromSMS()  — dedup, insert, update lastImportedAt setting
```

The `flutter_sms_inbox` package is still a dependency but **no longer used for reading** — it was hardcapped at 1000 messages. All SMS reading now goes through the native `MethodChannel` in `MainActivity.kt`.

### Transaction processing pipeline (two-pass rule application)

Custom rules are applied in two ordered passes, everywhere transactions are displayed (`transactions` getter in AppProvider, and `getHistoryMonths()`):
1. **Merchant extraction rules** — override the payee name only
2. **Categorization rules** — override category + sub-category only

Built-in categorization falls back to `categorizer_service.dart`, which keyword-matches against a static map (order matters — first match wins).

### Category registry (module-level singleton)

`lib/models/category_info.dart` holds a module-level `_registry` map that starts as a copy of the 10 built-in categories. `AppProvider.loadCustomCategories()` calls `updateCategoryRegistry()` to merge user-created categories in. All UI that lists categories uses the `allCategories` getter — **never iterate `kCategoryMeta.keys` directly**, or custom categories won't appear.

### Database

SQLite via sqflite, singleton `DatabaseService`. Current schema version: **7**.

| Table | Purpose |
|---|---|
| `transactions` | Active transactions |
| `deleted_transactions` | Soft-deleted (same schema + `deletedAt`) |
| `accounts` | Discovered bank accounts with `isTracked` flag |
| `custom_rules` | User-defined merchant extraction + categorization rules |
| `custom_categories` | User-created categories (name, color, icon codepoint) |
| `settings` | Key-value store; `lastImportedAt` drives incremental import |

When bumping DB version, add a migration branch in `_open()` → `onUpgrade`. Never drop and recreate a table without a version gate.

### SMS filter logic

`_whySkipped()` in `sms_service.dart` gates every message with two checks:
1. Body must contain `"debited"` or `"credited"`
2. `extractLast4(body)` must return non-null (masked account/card number present — e.g. `XXXX1234`, `**1234`, `a/c XX1234`)

This prevents mobile recharges, wallet credits, and other non-bank "credited" messages from being parsed.

### Incremental import

`lastImportedAt` (epoch ms string) is stored in the `settings` table. On import, `sinceMs` is passed as a SQL `WHERE date > ?` clause directly to the Android `ContentResolver` — no Dart-side date filtering. Full scan: pass `null` (no WHERE clause). The import dialog in `HomeScreen` lets the user choose between the two.

### Soft delete

Deleting a transaction moves it to `deleted_transactions` (preserves the raw SMS body). The SMS debug screen has a "Deleted" tab with an "Add Back" button. Deduplication during import checks **both** tables via `allExistingRawMessages()`, so restored-then-deleted transactions don't re-import.

### Trends tab filters

Three independent state variables — `_typeFilter` (null/debit/credit), `_above10k` (bool), `_byCategory` (bool) — combine additively in `_valueFor()`. All three can be active simultaneously. `AutomaticKeepAliveClientMixin` keeps the tab alive across tab switches.
