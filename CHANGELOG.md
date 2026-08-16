# Changelog

## [0.1.3] - 2026-08-16

Production IPA after 0.1.1. Hardware-checked on iPhone 17, iOS 26.5.1 (list, browse, pairing place).

### Added

- **Compress** in the file browser (long-press or Select → More) zips files and folders into the current folder.
- **Extract** for zip / IPA: tap the archive (or Extract in the menu) to unpack a folder next to it. Open as Hex stays on the menu.

### Fixed

- Share / Save to Files keeps the original filename (no `shared_` prefix). Folders share as `FolderName.zip`.
- Empty Apps list says “No apps found.” instead of a blank search miss.

A–Z jump is the same small index as 0.1.1 (no extra inset beside search).

v0.1.0 and v0.1.1 are unchanged on GitHub.

## [0.1.1] - 2026-08-16

### Added

- **Apps search** and an **A–Z jump index** on the right edge of the app list.
- **Copy confirmation** (banner + haptic) for Bundle ID, name, path, SHA-256, and file Copy/Cut.

v0.1.0 is unchanged on GitHub. This is a new tag and IPA.

## [0.1.0] - 2026-08-14

First public sideload IPA.

- App list via LocalDevVPN. iOS 26.4+ uses Remote Pairing/RSD (`10.7.0.1:49152`); iOS 18 falls back to lockdown loopback (`10.7.0.1:62078`). No USB while using the app.
- Path-scoped Data-container browse, edit, share, backup zip + restore. Select for multi-select Copy/Cut/Paste/Duplicate/Delete; Copy Path, Copy Bundle ID, and Copy SHA-256.
- Pairing setup names EscapeOS and iPASide. iLoader is not required; iPASide writes the same merged pairing file as iLoader and places `pairingFile.plist`.
- README shows the app icon with transparent corners (no black frame).
- Supported container access follows [bad_query](https://github.com/forcequitOS/bad_query): **iOS 26.0–26.6.1** and **iOS 27.0 beta 4**. Later 26.x / 27.x builds are unsupported. IPA `MinimumOSVersion` is 18.0; iOS 18 listing is in code, untested. Hardware-verified: iPhone 17, **iOS 26.5.1**.
- Verified on iPhone 17, iOS 26.5.1, with iPASide placing the pairing file after install (list, browse, Select/copy-paste, backup).
