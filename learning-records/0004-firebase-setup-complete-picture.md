# Firebase Setup: The Complete Picture

Nishant provided detailed notes from a prior Claude session covering the full Firebase setup for this project (money_tracker). The lesson (0003) was built from those notes, connecting Firebase setup to the SHA/cryptography foundation from lessons 1–2.

**What was covered:**
- Firebase as BaaS: Auth + Firestore (not the full suite — scoped to what this project uses)
- The 7-step cloud setup (console → flutterfire configure)
- Why there are two config files: google-services.json (Gradle/build time) vs firebase_options.dart (Flutter SDK/runtime)
- The two-package Google Sign-In pattern: google_sign_in handles the UI/credential, firebase_auth handles the session
- Firestore data model: collections → documents → fields/subcollections
- Security rules as the gatekeeper (no rules = public data)
- File-by-file breakdown of where Firebase lives in this specific project

**Key connection to prior lessons:**
SHA-1 fingerprint (Lesson 1) is explicitly the identity check at step 6 of the Firebase setup. The lesson reinforces this connection.

**Prior knowledge the user brought:**
User came in with detailed working notes — had already implemented the setup and wanted to consolidate understanding. No gaps were apparent in the notes; the quiz will test whether the concepts stuck.

**Implications for next sessions:**
Natural next topics:
- Google Play App Signing: when you have a release keystore, which SHA do you register? (connects directly to lessons 1–3)
- Certificate pinning in Flutter: advanced SHA use
- Firestore queries: orderBy, where, pagination (if the sync feature needs it)
- Offline persistence in Firestore
