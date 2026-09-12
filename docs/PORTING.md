# Continue the device port or adapt another ROM

The conventional checkout path is `device/realme/RE5465`. This is an initial
device configuration, not a finished OS-independent HAL/vendor implementation.

| Component | Reuse boundary |
|---|---|
| Hardware identity and sizes | Reuse measured values; verify a new unit or firmware baseline |
| BoardConfig.mk | Starting point for architecture, boot layout and modules; review destination-branch variables and AVB |
| rootdir/fstab.qcom | Review first-stage, filesystem and encryption requirements |
| modules/ | Preserve the matched kernel/module loading order |
| recovery/init.recovery.qcom.rc | QCOM USB role and bootdevice alias; review the destination recovery's ADB/fastboot triggers |
| sepolicy/vendor | Exact USB role-node label and Recovery init permissions; revalidate against the destination policy |
| lineage_RE5465.mk | Replace Lineage-specific inheritance and product name |
| extract-files.py | Depends on Lineage extract-utils; the proprietary list is still a placeholder |

Make an OS-specific branch and keep hardware changes separate from branding
and feature choices. Changing the product name alone does not complete a port.

## Remaining milestones

- [x] Confirm hardware identity and capture matching inputs.
- [x] Capture working replacement-panel input events.
- [x] Build source recovery and inspect ramdisk and AVB.
- [x] Package authenticated ADB, fastbootd and diagnostic tools.
- [x] Build and statically inspect matching boot/vendor_boot/DTBO outputs.
- [x] Verify VNDK 32 payload and pass a staged VINTF metadata preflight.
- [ ] Curate proprietary-files and ABI fixups from the vendor/odm audit.
- [ ] Validate final-image VINTF, runtime linkage and SELinux compatibility.
- [ ] Trace the exact kernel source/KMI for the 5.10.226 baseline.
- [ ] Complete a source ROM build.
- [ ] Validate bootloader recovery paths and obtain logs without screen input.
- [ ] Validate display, touch, encryption, radio/IMS, audio, Wi-Fi, Bluetooth,
      GNSS, NFC, sensors, charging/power, camera and fingerprint.
- [ ] Validate suspend and message delivery, including QQ/WeChat where relevant.

## Retain these bring-up decisions

Keep kernel, modules and hardware binaries paired until new combinations are
validated. Older OEM source does not automatically reproduce the captured kernel.
Keep diagnostic tools and the computer's public key inside the recovery ramdisk.

Bootloader fastboot and recovery fastbootd are different paths. Neither has been
tested with the new images, and a second slot is not automatically an untouched
fallback. Validate AVB trust chains and rollback indexes before device writes.

Upstream userdebug policy has permissive `su`, `recovery` and `backuptool`
domains. The device tree adds no global permissive switch. Release policy
needs a separate review.
