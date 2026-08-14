<div align="center">

<img src="docs/brand/icon.png" alt="EscapeOS" width="128" height="128">

# EscapeOS

On-device file browser and App Store app-data backup/restore for sideloaded iOS, using a path-scoped container sandbox escape. No jailbreak. No Keychain.

**Sideload the IPA with [iPASide](https://github.com/pwnapplehat/iPASide)** (Windows). iPASide creates this iPhone's pairing file and places `pairingFile.plist` after install.

</div>

## What it does

- Lists installed user apps through LocalDevVPN + a Remote Pairing file (`10.7.0.1:49152`).
- Browses an app Data container (`Documents`, `Library`, `tmp`) after consuming a `bad_query` sandbox extension for that container UUID.
- Creates, previews, edits, and shares files in that container.
- Exports a zip + `manifest.json` (SHA-256 per file) into Files → On My iPhone → EscapeOS → Backups, and restores that archive into the same app's current container.

## What it does not do

- Keychain
- Other apps' App Groups
- System paths (`/var/mobile`, parent container directories)
- The app's signed `.app` bundle (Data container only)

## Requirements

Working product (list apps + open another app's Data container) is **verified only on iPhone 17, iOS 26.5.1**.

The IPA's `MinimumOSVersion` is 15.0 so it can *install* on older iOS. That is not the same as the features working:

| Piece | What the code actually needs |
|---|---|
| App listing | LocalDevVPN + **Remote Pairing** (`tunnel_create_rppairing` / RSD). That is the iOS **26.4+** StikDebug path. There is no lockdown / iOS 17.4–18 fallback in this tree. |
| Container open | `bad_query` (containermanager sandbox extension). Upstream states **iOS 26.0–26.6.1 / 27.0b4**, and says iOS 18 is untested. |
| LocalDevVPN | App Store lists iOS 14+, but EscapeOS only talks to it as the RSD loopback at `10.7.0.1:49152`. |

iOS 15, 16, 17, and 18 are **not** a supported or hardware-tested product surface. An iPhone 8 Plus on iOS 16.7.15 is on this desk; EscapeOS was not installed there (free Apple ID already at 3 apps).

Also required on the verified path:

- [LocalDevVPN](https://apps.apple.com/app/id6755608044) on default `10.7.0.1`
- Wi-Fi on
- A pairing file with Remote Pairing keys. [iPASide 1.2.3+](https://github.com/pwnapplehat/iPASide) creates those over USB and places the file into EscapeOS. USB-only lockdown pairing files fail on iOS 26.4+.

## Sideload

1. Install [iPASide](https://github.com/pwnapplehat/iPASide/releases/latest) on Windows.
2. Sideload `EscapeOS.ipa` from this repo's [Releases](https://github.com/pwnapplehat/EscapeOS/releases).
3. Trust the developer profile on the iPhone.
4. iPASide places `pairingFile.plist` automatically after sideload. To do it later: Settings → Pairing file → Place.
5. Install LocalDevVPN, connect it, leave Wi-Fi on, then open EscapeOS.

## Build (Theos / WSL)

This tree is built with Theos against the iPhoneOS 16.5 SDK (Linux clang). That IPA is what was verified on hardware. A Mac with Xcode 26 can relink against the iOS 26 SDK for Liquid Glass; see `docs/BUILD.md`.

```sh
export THEOS=~/theos
cd ~/apps/EscapeOS
make package FINALPACKAGE=1
# staged app: .theos/_/Applications/EscapeOS.app
```

After reinstall, place `pairingFile.plist` again: iPASide Settings → Pairing file → Place, Files sharing, or House Arrest.

## License

[GNU AGPL-3.0](LICENSE). Third-party origins are listed in [NOTICE](NOTICE): StikDebug adaptations (AGPL-3.0), `jkcoxson/idevice` (MIT), and `forcequitOS/bad_query` (no upstream license at adaptation time).
