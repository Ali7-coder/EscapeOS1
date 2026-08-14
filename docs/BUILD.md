# Building EscapeOS

## iOS 26 Liquid Glass tab bar

Apple’s floating Liquid Glass tab bar is applied automatically when the app is **linked against the iOS 26 SDK (Xcode 26)**. This is an OS-level “linked on or after” rule — runtime hacks or custom blur styling cannot substitute for it.

| Build environment | Tab bar appearance | Use case |
|---|---|---|
| **Xcode 26 on macOS** (iOS 26 SDK) | Native Liquid Glass | App Store / public release |
| **Theos on Linux/WSL** (iPhoneOS 16.5 SDK) | Legacy system tab bar | Local sideload / dev |

Do **not** set `UIDesignRequiresCompatibility` in `Info.plist` for release builds — that flag opts out of Liquid Glass.

### Public release (recommended)

1. Open the project on a Mac with **Xcode 26**.
2. Build with the iOS 26 SDK (deployment target iOS 18).
3. Archive and export the IPA for distribution.

EscapeOS uses SwiftUI `TabView` for the tab bar. A Mac with Xcode 26 can relink against the iOS 26 SDK for Liquid Glass; see above.

### Local sideload (WSL Theos)

```bash
export THEOS=~/theos
cd ~/apps/EscapeOS
make clean package
```

The Makefile pins `iphone:clang:16.5:18.0` because newer Apple SDKs require Xcode’s Apple Clang and fail under Linux clang.

`EscapeOS/Tunnel/libidevice_ffi.a` is not in git (≈93 MB). Download it from the same GitHub Release as the IPA, or rebuild `jkcoxson/idevice` for `aarch64-apple-ios`, and place it at `EscapeOS/Tunnel/libidevice_ffi.a` before `make package`.

After install, place `pairingFile.plist` again from iPASide Settings → Pairing file → Place (or Files sharing / House Arrest).

### App icon

Regenerate PNGs from the master artwork:

```bash
python3 tools/generate_icons.py
```

Master icon: `assets/EscapeOS-icon-master.png` (teal escape/sandbox motif, transparent corners).
