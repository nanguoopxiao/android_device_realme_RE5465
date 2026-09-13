# realme GT2 Master Explorer — RE5465 / RMX3551

Device-specific Android source bring-up for **realme GT2 Master Explorer Edition
(真我 GT2 大师探索版)**, hardware project **21605**, Qualcomm **SM8475**.
The initial target is **LineageOS 23.2 / Android 16**.

**Status: LineageOS boots on the test device, including a repeat boot of the same
source-built image set with existing userdata. Both SIMs register on NR-SA and
Settings shows 5G as the preferred mode. This remains a community-test baseline;
complete telephony, camera, fingerprint and long-term stability are not qualified.**

## What is here

- Android product definitions, BoardConfig, fstab, recovery USB configuration and its scoped policy.
- Captured module loading order and a SHA-256 manifest for the matched hardware inputs.
- Hardware observations, source provenance, build instructions and a porting checklist.
- A local prebuilt staging tool and Windows flashing scripts. Developers supply
  their own hardware inputs; pre-authorizing an ADB key is an optional private-lab
  setting, disabled by default. Firmware, kernel/module binaries and recovery images are
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

Then follow [the build guide](docs/BUILDING.md) to stage the matched inputs before
selecting `lineage_RE5465-bp4a-userdebug`. Shared builds contain no personal ADB key.

- [Hardware and partition notes](docs/HARDWARE.md)
- [Reproducing the recovery build](docs/BUILDING.md)
- [Adapting another Android distribution](docs/PORTING.md)
- [Recovering hardware inputs and completing the vendor tree](docs/VENDOR_PLAN.md)
- [Build validation and its limits](docs/VALIDATION.md)
- [First full-system bring-up findings](docs/FIRST_BOOT.md)
- [Windows flashing and installation scope](docs/FLASHING.md)
- [Vendor compatibility preflight](docs/COMPATIBILITY.md)
- [Source provenance and upstream DTS](docs/PROVENANCE.md)
- [Machine-readable input manifest](metadata/prebuilt-inputs.json)

## 中文说明

这是 RMX3551 / RE5465 同型号源码适配的起点，已验证完整系统启动及同一镜像
保留数据再次启动；双卡注册 NR SA，设置中显示并选中 5G。已加入通用 Windows
线刷脚本，并修正运行时挂载表及存储 HAL 的启动配置。**当前仍是社区测试基线：
完整通话/短信/IMS、指纹、相机、Recovery 交互及长期稳定性尚未验收。**
后续适配其他 ROM 时，可以复用这里的硬件信息和板级配置，
再调整对应系统的产品入口、HAL、vendor 依赖、VINTF 和 SELinux。

当前保留匹配的预编译内核及硬件分区作为初期基线。固件文件由使用者本地提供；
个人 ADB 预授权仅可选择用于私有调试构建，公共配置默认不包含。测试机的
60 Hz 限制和数据 SIM 选择未固化到公共镜像。重启后 USB 调试曾需要关闭再开启
才重新连接，原因仍待单独调查。具体校验值和构建步骤见上面的文档。
`proprietary-files.txt` 仍是占位入口，不是完整的 vendor 提取清单。

## License

Authored device configuration, tools and documentation are provided under
[Apache-2.0](LICENSE). Third-party source links and locally supplied hardware
files retain their own licenses; see [NOTICE](NOTICE).
