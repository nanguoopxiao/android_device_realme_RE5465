# realme GT2 Master Explorer — RE5465 / RMX3551

Device-specific Android source bring-up for **realme GT2 Master Explorer Edition
(真我 GT2 大师探索版)**, hardware project **21605**, Qualcomm **SM8475**.
The initial target is **LineageOS 23.2 / Android 16**.

**Status: recovery compiles and passed 26 static checks. A complete ROM build,
device boot, recovery touchscreen and userdata decryption have not been
validated. This repository is a development baseline, not a flashable release.**

## What is here

- Android product definitions, BoardConfig, fstab and recovery USB configuration.
- Captured module loading order and a SHA-256 manifest for the matched hardware inputs.
- Hardware observations, source provenance, build instructions and a porting checklist.
- A local prebuilt staging tool; each developer supplies their own hardware files
  and ADB public key. Firmware, kernel/module binaries and recovery images are
  not distributed in this repository.

The initial kernel, DTB/DTBO and hardware partitions remain a matched prebuilt
baseline. Recovery is compiled from source. Replacing these with a complete
kernel source build and a curated per-file vendor tree remains future work.

| Identity | Value |
|---|---|
| Device / model | RE5465 / RMX3551 |
| Project / board | 21605 / Jennie-a / CAPE |
| SoC / Android platform | SM8475 / taro |
| Launch API / baseline VNDK | 31 / 32 |
| Captured kernel | 5.10.226-android12-9-o-g11c6e37b2a8e |
| Display geometry | 1080 × 2412 |
| Recovery layout | Dedicated partition, header v4, no embedded kernel |

## Getting started

Clone this branch into an existing LineageOS 23.2 checkout:

```bash
git clone -b lineage-23.2 https://github.com/nanguoopxiao/android_device_realme_RE5465.git device/realme/RE5465
```

Then follow [the build guide](docs/BUILDING.md) to stage the matched inputs and
your own ADB public key before selecting `lineage_RE5465-bp4a-userdebug`.

- [Hardware and partition notes](docs/HARDWARE.md)
- [Reproducing the recovery build](docs/BUILDING.md)
- [Adapting another Android distribution](docs/PORTING.md)
- [Build validation and its limits](docs/VALIDATION.md)
- [Vendor compatibility preflight](docs/COMPATIBILITY.md)
- [Source provenance and upstream DTS](docs/PROVENANCE.md)
- [Machine-readable input manifest](metadata/prebuilt-inputs.json)

## 中文说明

这是本机专用源码适配的起点，已经完成设备资料核对、Lineage Recovery
编译和 26 项静态检查。**完整系统、实机启动、触控、指纹、相机和 data
解密尚未验收。** 后续适配其他 ROM 时，可以复用这里的硬件信息和板级配置，
再调整对应系统的产品入口、HAL、vendor 依赖、VINTF 和 SELinux。

当前保留匹配的预编译内核及硬件分区作为初期基线。固件文件和电脑的 ADB
授权公钥由使用者在本地提供，具体目录、校验值和构建步骤见上面的文档。
`proprietary-files.txt` 仍是占位入口，不是完整的 vendor 提取清单。

## License

Authored device configuration, tools and documentation are provided under
[Apache-2.0](LICENSE). Third-party source links and locally supplied hardware
files retain their own licenses; see [NOTICE](NOTICE).
