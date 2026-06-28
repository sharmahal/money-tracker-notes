# Demonstrated deep understanding across the full cryptography session

Nishant worked through the entire chain from SHA properties → certificate anatomy → public-key signing → APK verification → MITM threat model → SSH host key verification → TLS handshake (old RSA vs modern ECDHE). Key moments of genuine understanding:

- Independently derived that SHA(modified APK) ≠ SHA(original APK) means the MITM's stapled signature fails
- Caught an imprecision in the teaching ("certificate = public key + fingerprint") and correctly identified it
- Questioned the SSH fingerprint flow correctly ("shouldn't the server sign a challenge?") — correctly predicted how it works before being told
- Understood that fingerprint is a convenience identifier, not a cryptographic mechanism

**Implications:** Strong foundation in place. Next natural topics: Google Play App Signing (which fingerprint to register when Google holds your release key), mTLS (client certificates), or certificate pinning in Flutter/Android apps.
