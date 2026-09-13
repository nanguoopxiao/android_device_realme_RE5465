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
| scripts/extract-hardware-inputs.py | Recover the pinned image-based hardware inputs from community-test02 |
| extract-files.py | Future Lineage extract-utils entry; currently stops because the per-file list is still a placeholder |

Make an OS-specific branch and keep hardware changes separate from branding
and feature choices. Changing the product name alone does not complete a port.

## Remaining milestones

- [x] Confirm hardware identity and capture matching inputs.
- [x] Capture working replacement-panel input events.
- [x] Build source recovery and inspect ramdisk and AVB.
- [x] Package authenticated ADB, fastbootd and diagnostic tools.
- [x] Build and statically inspect matching boot/vendor_boot/DTBO outputs.
- [x] Verify VNDK 32 payload and pass a staged VINTF metadata preflight.
- [x] Recover and verify the hardware-input layout from the matching community package.
- [ ] Curate proprietary-files and ABI fixups from the vendor/odm audit.
- [ ] Validate final-image VINTF, runtime linkage and SELinux compatibility.
- [ ] Trace the exact kernel source/KMI for the 5.10.226 baseline.
- [x] Complete a source ROM build and verify normal/repeat boot on the test unit.
- [x] Use bootloader flashing and collect startup logs without Recovery screen input.
- [ ] Validate display, touch, encryption, radio/IMS, audio, Wi-Fi, Bluetooth,
      GNSS, NFC, sensors, charging/power, camera and fingerprint.
- [ ] Validate suspend and broader hardware stability. App-specific compatibility is outside the current work scope.

## Retain these bring-up decisions

Keep kernel, modules and hardware binaries paired until new combinations are
validated. Older OEM source does not automatically reproduce the captured kernel.
Shared builds must keep personal ADB pre-authorization and private diagnostic
helpers disabled. A developer can opt in for a private lab build.

Bootloader fastboot and recovery fastbootd are different paths. Bootloader
physical flashing has been tested, while fastbootd and
Recovery UI/data decryption remain unqualified. A second slot is not automatically
an untouched fallback. Validate a new image set's AVB chain before device writes.

Upstream userdebug policy has permissive `su`, `recovery` and `backuptool`
domains. The device tree adds no global permissive switch. Release policy
needs a separate review.
