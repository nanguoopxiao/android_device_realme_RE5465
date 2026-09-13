# 从可运行基线到可复现、可维护的硬件适配

厂商闭源 HAL、固件和部分驱动通常仍需以二进制形式配套使用。这里要补齐的是
来源、提取、校验、构建接入和功能验收；提取文件不等于还原它们的源代码。

## 当前已具备的复现入口

仓库保留设备配置及硬件校验清单。配套的 `community-test02` 线刷包提供硬件
载荷，新脚本可从该包的 `images/` 目录还原以下 463 个输入：

| 输入 | 获取位置 |
|---|---|
| `kernel/Image` | boot v4 中的内核 |
| `dtb/gt2master.dtb` | vendor_boot v4 中完整的 DTB 区域 |
| `ramdisk-modules/*.ko` | vendor_boot ramdisk 中的 456 个原始模块 |
| `dtbo.img` | 配套包中经核验的 DTBO |
| `images/vendor.img`、`images/odm.img` | super 中对应的槽 A 逻辑分区 |
| `images/vendor_dlkm.img`、`images/odm_dlkm.img` | super 中对应的模块分区 |

脚本在 Linux 上运行，需要 Python 3.11+ 及 `simg2img`、`lpunpack`、`lz4`。
它会在所选 Android 源码树的 host 输出、extract-tools/build-tools 和 PATH 中寻找
工具，也支持 `--host-tools /path/to/bin`。预留至少 16 GiB 临时磁盘空间。
已经编译过本项目的环境具有这些 host 工具；全新环境需要先准备它们。

在 Android 源码根目录执行，输出目录必须尚不存在：

```bash
python3 device/realme/RE5465/scripts/extract-hardware-inputs.py \
  --images-dir /path/to/community-test02/images \
  --output-dir /path/to/recovered-RE5465-inputs \
  --android-root "$PWD"

python3 device/realme/RE5465/scripts/prepare-prebuilts.py \
  --source-dir /path/to/recovered-RE5465-inputs \
  --android-root "$PWD"
```

然后按 [构建说明](BUILDING.md) 选择产品。公共构建默认不预授权任何电脑。
提取过程不连接手机、不访问网络，也不自动写入已有 vendor 构建目录。

输入容器首先按 `metadata/hardware-extraction-sources.json` 核验，再验证全部
463 个输出。当前只接受明确登记的 test02 容器，不把其他同平台 ROM 当成等价输入。
DTBO 在构建时重签了 AVB：硬件表已逐字节确认相同，整文件哈希则不同。因此
`metadata/prebuilt-inputs.json` 同时登记原始值及这一个已验证变体，不接受任意哈希。
既有目标文件若符合任一已登记值，会保留原文件。

已完成真实 test02 容器的提取及 463 文件校验，在独立目录暂存全部 463 个文件后
再次校验通过，并验证原有硬件目录仍符合清单。9 项输入/CPIO 测试及已有输出目录
拒绝覆盖检查也已通过。
这是输入恢复测试，不等于使用新目录完成了一次全新 ROM 编译或全硬件验收。

## 接下来整理逐文件 vendor

现有四个硬件分区审计覆盖 7,078 个条目、3,691 个 ELF，初筛得到 5,995 个候选文件。
这个候选集包含其他 SKU 和未确认用途的文件，不能直接冒充完成的
`proprietary-files.txt`。

逐文件迁移按以下顺序进行：

1. 对照 HAL 清单、init 服务、链接依赖和实机加载记录，确定本型号所需组件。
2. 明确保留的二进制、由源码生成的配置、需修改的兼容接口和多硬件变体。
3. 从原镜像核对权限、SELinux 标签、文件能力及符号链接；现有提取目录的宿主机
   `stat` 结果不能直接作为完整文件系统元数据。
4. 生成并审查逐文件提取清单、Android.bp/产品配置，在独立目录构建新 vendor/odm。
5. 对照当前基线检查启动、数据加密、无线通信、显示输入等功能，通过后再切换
   `BOARD_PREBUILT_*IMAGE` 路线。

当前 `extract-files.py` 会在清单仍为空时停止，避免生成空的 vendor 目录。
当前工作中的整镜像基线继续有效。

## 内核和模块单独推进

当前匹配内核为 `5.10.226-android12-9-o-g11c6e37b2a8e`；已检查的 OEM Android T
参考代码为 5.10.101，尚未确认能复现当前内核与模块。后续需要确认对应源码、
配置、工具链及 KMI/模块符号兼容性，再进行独立构建和设备验证。

GKI 内核与厂商模块可以分别维护，但必须保持兼容的模块接口。仅有相似的
版本号不足以证明能替换，见 [AOSP KMI 说明](https://source.android.com/docs/core/architecture/kernel/stable-kmi)。
即使完成内核源码构建，厂商闭源用户空间 HAL 也可能继续保留为二进制。
