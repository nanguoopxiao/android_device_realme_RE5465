# Validation snapshot — 2026-09-12

`lineage_RE5465-bp4a-userdebug` built recovery from LineageOS 23.2 source. The
development image passed 26 static checks after fixing recovery-local ADB key
packaging, fastbootd inclusion and the branch's userdebug-property switch.

| Check | Result |
|---|---|
| Image | Header v4, no kernel, LZ4 ramdisk, 104857600 bytes |
| AVB | Footer, SHA256_RSA4096 test-key signature and recovery hash verified |
| ADB | Key resolves inside ramdisk; secure ADB enabled; debuggable userdebug |
| Tools | recovery, adbd, fastbootd, AIDL fastboot service, shell, getevent, dmesg |
| fstab | Built copy matches device configuration |
| ELF names | 99 files; DT_NEEDED names have matching-class providers |
| Hardware inputs | Preserved inputs match recorded hashes |
| Recovery modules | 455 unique loading-list entries resolve, including S3910 touch modules |
| SELinux | Policy parses; only three expected upstream debug permissive domains |

The local validation image SHA-256 was
`a5926837703e194539277a0b524dd09e0a264ed5bf1f7e3bc1a0120f0ca5a5ea`.
That image contains a development computer's ADB public key and is not
distributed here. Its hash is historical evidence, not an expected hash for
another developer's build.

[`metadata/validation.json`](../metadata/validation.json) is a sanitized
summary without raw logs, host paths or ADB key fingerprints.

## Limits

- Framework images and the boot chain have been built. A complete ROM has not booted on the device.
- Initial Recovery display and authenticated root ADB work. Menu interaction, fastbootd and data decryption remain unvalidated.
- Module presence does not prove runtime loading or hardware compatibility.
- ELF-name checks do not cover all symbols, dlopen or linker namespaces.
- AVB test-key verification does not prove bootloader trust or rollback safety.
- Userdebug retains upstream permissive domains; this is not release validation.

Record new evidence after changing source revisions, kernel/KMI, the firmware
baseline or target ROM.

## On-device Recovery update

Only the active Recovery partition was changed during these trials. The current
kernel, vendor_boot, DTBO and installed system remained the matched baseline.
The original Recovery was restored after each diagnostic cycle and its complete
partition hash was verified from the original system.

The first trial could display the UI but lacked the legacy bootdevice alias
needed by the misc/BCB path. Creating that alias removed the visible BCB error.
USB still failed because init's `peripheral` write to
`/sys/devices/platform/soc/a600000.ssusb/mode` was denied under the generic
`sysfs` label. ADB was running, but the physical UDC did not exist.

The device policy now labels that single node `vendor_sysfs_usb_role` and grants
Recovery init only `getattr`, `open` and `write`. The next device trial confirmed
the new label, peripheral mode, a configured physical UDC and authenticated root
ADB. No additional permissive domain or global SELinux switch was introduced.

An earlier trial reported an unresponsive Advanced menu and unexpected returns
to the installed system. The subsequent input-recording window contained no
touch/key events, so this issue has not been reproduced or declared fixed.
The touchscreen is detected with the same axis ranges as the working system;
that alone does not validate interaction with the aftermarket panel.

Private diagnostic images used bounded log collection and a timed Bootloader
return. Those diagnostic services and device-specific log destinations are not
part of the public tree or a distribution image.

The [sanitized runtime record](../metadata/recovery-runtime.json) separates
observed behavior from the remaining menu and full-system tests.

## Other completed build checks

| Candidate scope | Result | Limit |
|---|---|---|
| boot / vendor_boot / DTBO | 27 static checks passed; kernel and module baseline preserved | Full new boot chain has not been booted |
| system / system_ext / product | Built; 22 image integrity checks passed | No full-system functional test |
| AVB and super assembly | 18 checks passed, including payload hashes and LP metadata copies | Bootloader acceptance and installation remain unvalidated |
| Packaged framework and retained vendor | VINTF compatibility check passed with captured kernel configuration and device SKU | Runtime HAL behavior is untested |
| Native service dependency models | 139 selected startup scenarios resolved strong symbols | Not a hardware/service startup certification |
| Observed vendor plugin models | 404 independent loading scenarios resolved strong symbols | Actual loading order, flags and custom namespaces can differ |

The assembled super candidate contains seven logical partition types and omits
the legacy Oplus `my_*` partitions. Do not infer installation readiness from
successful assembly; the complete restore and first-boot procedure still matters.
