# Changelog

## [0.1.0] - 2026-08-14

First public sideload IPA.

- App list via LocalDevVPN. iOS 26.4+ uses Remote Pairing/RSD (`10.7.0.1:49152`); iOS 18 falls back to lockdown loopback (`10.7.0.1:62078`). No USB while using the app.
- Path-scoped Data-container browse, edit, share, backup zip + restore. Select for multi-select Copy/Cut/Paste/Duplicate/Delete; Copy Path, Copy Bundle ID, and Copy SHA-256.
- Pairing setup names EscapeOS and iPASide. iLoader is not required; iPASide writes the same merged pairing file as iLoader and places `pairingFile.plist`.
- README shows the app icon with transparent corners (no black frame).
- Supported container access follows [bad_query](https://github.com/forcequitOS/bad_query): **iOS 26.0–26.6.1** and **iOS 27.0 beta 4**. Later 26.x / 27.x builds are unsupported. IPA `MinimumOSVersion` is 18.0; iOS 18 listing is in code, untested. Hardware-verified: iPhone 17, **iOS 26.5.1**.
- Verified on iPhone 17, iOS 26.5.1, with iPASide placing the pairing file after install (list, browse, Select/copy-paste, backup).
