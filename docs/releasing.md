# Releasing EscapeOS

**Never replace `v0.1.0`.** That tag already has real users. Recutting the same version (force-push tag, overwrite `EscapeOS-0.1.0.ipa`) leaves people on a silent different binary with the same number.

The next public IPA is **0.1.1 or higher**: bump `Resources/Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`), `control` `Version`, tag `v0.1.1`, and attach a new asset name. Leave `v0.1.0` on GitHub as shipped.

Verify on a physical iPhone before publishing. CI must not upload release assets.
