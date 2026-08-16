# Releasing EscapeOS

**Never replace `v0.1.0`.** That tag already has real users. Recutting the same version (force-push tag, overwrite `EscapeOS-0.1.0.ipa`) leaves people on a silent different binary with the same number.

The next public IPA after **0.1.1** is **0.1.2 or higher**. Never replace `v0.1.0` or `v0.1.1` once they have downloads.

Verify on a physical iPhone before publishing. CI must not upload release assets.
