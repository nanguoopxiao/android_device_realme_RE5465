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

- No complete ROM build or device boot test has passed.
- Recovery display/touch/fastbootd and data decryption remain untested on-device.
- Module presence does not prove runtime loading or hardware compatibility.
- ELF-name checks do not cover all symbols, dlopen or linker namespaces.
- AVB test-key verification does not prove bootloader trust or rollback safety.
- Userdebug retains upstream permissive domains; this is not release validation.

Record new evidence after changing source revisions, kernel/KMI, the firmware
baseline or target ROM.
