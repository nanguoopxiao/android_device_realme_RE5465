# Reproduce the initial recovery build

Use a Linux LineageOS **23.2** source checkout. The validated lunch combination is
`lineage_RE5465-bp4a-userdebug`. A different branch may have different release
configuration, VNDK or build-variable semantics.
The staging tool requires Python 3.11 or newer.

## 1. Place the device repository

Clone into `device/realme/RE5465`, or use [the local manifest example](../local_manifest.xml).
The latter only adds this device repository; the main LineageOS manifest must
already be initialized.

## 2. Supply the matched hardware inputs

Prepare a private directory with this layout:

```text
private-RE5465-prebuilts/
  kernel/Image
  dtb/gt2master.dtb
  dtbo.img
  ramdisk-modules/*.ko
  images/vendor.img
  images/odm.img
  images/vendor_dlkm.img
  images/odm_dlkm.img
```

The 463 required file sizes and hashes are in
[`metadata/prebuilt-inputs.json`](../metadata/prebuilt-inputs.json). The manifest
pins one captured hardware baseline. It is not a statement that arbitrary stock
or donor firmware files can be interchanged.

For an already staged local build, its `vendor/realme/RE5465` directory has this
layout and can be used directly as the source directory. Otherwise obtain the
files from your own matching backup:

| Target path | Source component |
|---|---|
| `kernel/Image` | `kernel` extracted from the matching live boot image |
| `dtb/gt2master.dtb` | Entire `dtb` payload from vendor_boot, preserving concatenated DTBs |
| `ramdisk-modules/*.ko` | `lib/modules/*.ko` from the vendor_boot vendor ramdisk |
| `dtbo.img` | Full matching dtbo partition image |
| `images/*.img` | Full matching vendor, odm, vendor_dlkm and odm_dlkm images |

AOSP's `system/tools/mkbootimg/unpack_bootimg.py` can unpack the boot images. The
vendor ramdisk is LZ4 compressed CPIO. Preserve module names and the provided
loading order. The hardware partition files in this baseline are raw EROFS/ext4
images, not Android sparse containers. The staging tool deliberately requires
matching hashes; review a new baseline as a separate change.

From the Android source root, validate before copying:

```bash
python3 device/realme/RE5465/scripts/prepare-prebuilts.py --source-dir /path/to/private-RE5465-prebuilts --verify-only
```

Then stage into this checkout:

```bash
python3 device/realme/RE5465/scripts/prepare-prebuilts.py --source-dir /path/to/private-RE5465-prebuilts --android-root "$PWD"
```

The tool validates every input before writing, checks existing destination files
and refuses to overwrite conflicting files. Identical files are reused. It does
not download firmware, write phone partitions or alter the source dump.

## 3. Optional private recovery debugging key

Use the public key belonging to the computer you will use for recovery
diagnosis, for example the key created by your platform-tools installation:

```bash
python3 device/realme/RE5465/scripts/prepare-prebuilts.py --adb-public-key "$HOME/.android/adbkey.pub"
```

Skip this step for a shared build. No computer is pre-authorized by default.
For a private lab build only, also export `RE5465_INCLUDE_PRIVATE_ADB_KEY=true`
before building. Never distribute images built with this option enabled.

This writes the ignored `recovery/adb_keys` file in the device repository. It
rejects private-key data and a conflicting existing public key. This file is
copied, only with the opt-in above, inside recovery at `/product/etc/security/adb_keys`, which
resolves `/adb_keys` without loading the installed product or decrypting data.

The checked configuration keeps ADB authentication enabled and sets
`ro.debuggable=1` for the initial userdebug product. Use your own key and review
the debug configuration before preparing a release.

## 4. Check host-tool compatibility

The inspected repo revision `d27d6829a84f488b7253ea693dcc429076c33914`
can abort while generating Lineage's build-manifest XML inside the read-only
build sandbox: an optional Git-config cache write fails, then its cleanup also
fails. This does not require making the source tree or user directory writable.

If using that affected implementation, apply the included cache-handling fix
from the Android source root:

```bash
git -C .repo/repo apply --check ../../device/realme/RE5465/patches/repo-readonly-git-config-cache.patch
git -C .repo/repo apply ../../device/realme/RE5465/patches/repo-readonly-git-config-cache.patch
```

The patch treats cleanup of an unavailable optional cache as best-effort and
preserves reads of the real Git configuration. Fault-injection checks passed,
and the actual sandboxed build generated a valid 1164-project manifest afterward.
If the patch does not apply, inspect the repo version for an equivalent upstream
fix instead of forcing the patch.

## 5. Build

```bash
source build/envsetup.sh
lunch lineage_RE5465-bp4a-userdebug
m -j32 recoveryimage sepolicy-analyze
```

The output is `out/target/product/RE5465/recovery.img`. The validated image is
100 MiB. Files required by the prebuilt hardware configuration must be staged
even though recovery is the first build target.

`extract-files.py` is reserved for the future curated per-file vendor list.
It does not currently replace the prebuilt staging procedure.

## 6. Inspect before any device testing

Use a fresh output directory when unpacking:

```bash
python3 system/tools/mkbootimg/unpack_bootimg.py --boot_img out/target/product/RE5465/recovery.img --out /tmp/RE5465-recovery-inspection
python3 external/avb/avbtool.py verify_image --image out/target/product/RE5465/recovery.img --key external/avb/test/data/testkey_rsa4096.pem
```

See [validation](VALIDATION.md) for the ramdisk, authentication, module, ELF and
SELinux checks performed on the development image. Hashes will differ with
your ADB key, build timestamp or source revisions. A successful build is not
a bootloader rollback/trust-chain verification and does not establish device
boot or touchscreen behavior.
