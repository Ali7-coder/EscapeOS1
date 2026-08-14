# Changelog

## [0.1.0] - 2026-08-14

First public sideload IPA.

- App list via LocalDevVPN + RPPairing (`pairingFile.plist` in Documents).
- Path-scoped Data-container browse, edit, share, backup zip + restore.
- Pairing setup names EscapeOS and iPASide. iLoader is not required; iPASide creates Remote Pairing keys and places `pairingFile.plist`.
- README shows the app icon with transparent corners (no black frame).
- README does not claim iOS 15–18 as a working product. Hardware-verified path is iOS 26.5.1; app listing is the 26.4+ Remote Pairing tunnel; `bad_query` is documented upstream for iOS 26/27.
- Verified on iPhone 17, iOS 26.5.1, with iPASide placing the pairing file after install.
