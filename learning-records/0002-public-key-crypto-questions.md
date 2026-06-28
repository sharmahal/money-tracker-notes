# Questions demonstrated understanding gap: public/private key pairs not yet understood

Nishant asked 4 follow-up questions after Lesson 1 — all four traced back to not yet knowing how asymmetric key pairs work: what keytool generates, why certificate theft is harmless, how SSH fingerprints differ from Android fingerprints, and where the certificate comes from. Lesson 2 covers all four via public-key cryptography as the single unifying concept.

**Implications:** Next natural step is Google Play App Signing (where Google holds the release key and you register Google's fingerprint in Firebase, not your own) — a common real-world source of confusion for Flutter/Android developers.
