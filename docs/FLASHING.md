# Windows 线刷包

适用机型为 **真我 GT2 大师探索版 RMX3551 / RE5465，硬件项目 21605**。
GT2、GT2 Pro 及其他使用 taro / SM8475 的设备不适用。

源码目录 `flashing/` 提供安装器，发布包还必须带有经过验证的镜像、清单和
Windows platform-tools。只下载源码仓库不能直接刷机。

## 使用

1. 解压完整发布包到本地目录，先阅读该包的 `RELEASE-NOTES.md`。
2. 双击 `check-package.bat`，确认所有文件校验通过。这一步不操作手机。
3. 使用已解锁 Bootloader 的 RMX3551。可以从已授权 USB 调试的 Android
   系统开始，也可以手动进入 Bootloader Fastboot。Windows 需要对应的 USB 驱动。
4. 双击 `flash-all.bat`。脚本核对机型、分区、解锁状态及传输大小后显示计划。
   输入 `ERASE RMX3551` 才开始写入，**手机内所有用户数据都会清空**。
5. 等待脚本报告所有命令成功，手机重启。首次启动后选择自己的数据 SIM。

安装器使用 Windows 自带的 PowerShell 5.1，不依赖 Python，也不需要操作
Recovery 触屏或在 Recovery 内解密 data。路径含空格可以使用。
测试机曾遇到某条线 ADB 正常、Fastboot 无法识别，更换数据线后恢复。
本测试版在重启后还出现过 USB 调试需关闭再开启一次才连接的现象；若系统已正常
启动而电脑看不到 ADB，可先重切该开关并检查授权，或手动进入 Bootloader 线刷。

## 机型判断和容量

从 Android 开始时，脚本读取 `ro.boot.prjname=21605` 和
`ro.board.platform=taro`，然后追踪同一序列号进入 Bootloader。
目前实测的 Bootloader 只提供通用 `product=taro`；这不是完整机型证明。
直接从 Fastboot 开始时必须人工核对实体机型，并输入 `RMX3551`。
分区布局还会再次核验，脚本不会把一台任意 taro 手机自动认作本机。

userdata 容量由 Fastboot 实际查询、格式化，不固定为开发者手机的容量。
super 和启动分区则必须与本机型已验证布局一致。
这支持后续验证不同存储容量的同型号机器，不等于其他容量版本已经实测。
默认数据 SIM、ADB 序列号、开发者电脑公钥及本机副厂屏的 60 Hz 选择均未
固化到公共包。原装屏的刷新率选择保留，由实际屏幕能力决定。

## 写入范围

顺序为 `super`、`boot_a`、`vendor_boot_a`、`dtbo_a`、`recovery_a`、
`vbmeta_system_a`、`vbmeta_vendor_a`、`vbmeta_a`，随后格式化 metadata / userdata、
选择槽 A 并重启。完整 super 会替换动态分区布局，因此不能依赖旧槽 B 作为
完整可启动系统。脚本不提供“保留数据升级”选项；该流程需独立验证后再提供。

每次操作都会检查返回码和 `FAILED` / `fastboot: error:` 输出，任一步失败
立即停止，不继续清数据或重启。执行日志保存在包内 `logs/`，日志只留在本机。
传输分块取 Bootloader 上限与 512 MiB 的较小值。脚本不自动解锁或重新上锁。

包内不刷基带、Bootloader 固件或设备独有的校准分区。底层固件必须符合该包
发行说明的基线；尚不能宣称从任何历史固件版本直接刷入均兼容。

## 开发验证

```powershell
powershell.exe -NoProfile -File flashing\test-flash.ps1
```

测试使用模拟设备，覆盖损坏文件、稀疏镜像展开大小、多设备、未授权 ADB、
锁定 Bootloader、fastbootd、布局不匹配、不同 userdata 容量、分块大小及刷写失败
立即停止。发行包还要单独校验 AVB 全链和 super 拆包内容。

SHA-256 清单检查文件是否完整；它不替代可信下载渠道或发布者签名。
