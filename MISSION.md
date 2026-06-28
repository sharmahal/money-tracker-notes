# Mission: SHA Fingerprints & Cryptographic Hashing

## Why
Nishant is an Android/Flutter developer who keeps encountering SHA fingerprints when setting up Firebase projects and cloud services. He wants to stop copy-pasting commands blindly and actually understand what the fingerprint is, why it's required, and what SHA is doing under the hood — so he can debug issues and make informed decisions when configuring app security.

## Success looks like
- Can explain to a colleague why Firebase requires a SHA-1/SHA-256 fingerprint without looking it up
- Understands the difference between SHA-1 and SHA-256 and when each is used
- Knows how to generate a fingerprint, what it represents, and what happens if it's wrong
- Understands the core properties of a cryptographic hash function at a conceptual level

## Constraints
- Primarily interested in the Android/Firebase/cloud use cases — not academic cryptography
- Wants conceptual understanding first; math is out of scope

## Out of scope
- Internal SHA algorithm mechanics (Merkle-Damgård construction, compression functions, etc.)
- SHA-3, BLAKE, or other hash families
- Implementing a hash function from scratch
