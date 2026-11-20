# WH3000 Pro —— 237 编译固件 WiFi 驱动分析

- 采集时间：2026-11-17 14:0x（初版）；2026-11-19 10:24 CST（复测）
- 采集方式：SSH（`root@192.168.1.1`，设备实际 LAN 地址；初版误记为 192.168.6.1）
- 设备：Huasifei WH3000 Pro（`/tmp/sysinfo/board_name` = `huasifei,wh3000-pro`）
- 对应工作流：[build-237.yml](.github/workflows/build-237.yml)（padavanonly/immortalwrt-mt798x-6.6，openwrt-24.10-6.6）

## 1. 结论速览

| 项目 | 结果 |
| --- | --- |
| 固件 | ImmortalWrt 24.10-SNAPSHOT `r0-ec9ef10`（`DISTRIB_TAINTS='no-all busybox'`） |
| 内核 | Linux 6.6.133（2026-07-23 编译，OpenWrt GCC 13.3.0，Binutils 2.42） |
| WiFi 驱动 | MTK 闭源驱动 **7.6.6.1**（`kmod-mt_wifi 6.6.133.7.6.6.1-mt7981-r1`） |
| 驱动模块 | `mt_wifi.ko` 7,192,576 字节（加载名 `mt_wifi`） |
| WiFi 芯片 | MT7981 + MT7976（`14C3:7981`，A-die CHIP ID `0x7976`，HW Version `0x8b00`） |
| DBDC | `one_adie_dbdc = 1`（单 A-die 双频双并发） |
| 无线状态 | 驱动已加载，无线已正常启用（`wifi-scripts` 已补齐；`ra0` / `rax0` 分别为 DIY-CPE-2.4G / DIY-CPE-5G） |

## 2. 系统信息

```
DISTRIB_ID='ImmortalWrt'
DISTRIB_RELEASE='24.10-SNAPSHOT'
DISTRIB_REVISION='r0-ec9ef10'
DISTRIB_TARGET='mediatek/filogic'
DISTRIB_ARCH='aarch64_cortex-a53'
DISTRIB_DESCRIPTION='ImmortalWrt 24.10-SNAPSHOT r0-ec9ef10'
DISTRIB_TAINTS='no-all busybox'

Linux ImmortalWrt 6.6.133 #0 SMP Thu Jul 23 05:34:57 2026 aarch64 GNU/Linux
Linux version 6.6.133 (runner@runnervmy75tu) (aarch64-openwrt-linux-musl-gcc
  (OpenWrt GCC 13.3.0 r0-ec9ef10) 13.3.0, GNU ld (GNU Binutils) 2.42)
```

网络分配（`/etc/board.json`）：`lan = eth0 (static)`、`wan = eth1 (dhcp)`；QModem 5G 槽位挂在 USB `2-1.4`，别名 `wwan0`。

## 3. WiFi 驱动与配套模块

已加载（`lsmod`）：

```
conninfra         151552  1 mt_wifi          # 连接子系统（WiFi/BT 共用）
mt_wifi          7192576  1 mtk_warp_proxy   # MTK 闭源 WiFi 主驱动（含 MT7981 固件/算法）
mtk_warp          348160  1 mtk_warp_proxy   # WARP v2 / WED 硬件加速
mtk_warp_proxy     16384  0
mtkhnat            90112  2 mt_wifi,mtk_warp # 硬件 NAT
```

软件包版本（`opkg`）：

| 软件包 | 版本 |
| --- | --- |
| kmod-mt_wifi | `6.6.133.7.6.6.1-mt7981-r1` |
| kmod-conninfra | `6.6.133.bbf588-r1` |
| kmod-mediatek_hnat | `6.6.133-r1` |
| kmod-warp | `6.6.133.20221209-3e6ae1-r1` |
| mtwifi-cfg | `1-r2` |
| luci-app-mtwifi-cfg | `1-r1` |
| wifi-dats / mii_mgr | `1` / `1` |
| wireless-regdb | `2026.03.18-r1` |
| wireless-tools | `29-r6` |

`kmod-mt_wifi` 依赖链：`kernel (= 6.6.133~1514c4a060c1f4d9829ec1c6ed35a775-r1), wifi-dats, kmod-conninfra, kmod-mediatek_hnat, kmod-warp`。

模块加载顺序（`/etc/modules.d/`）：`conninfra` → `mtkhnat` → `mtk_warp` → `mt_wifi` → `mtk_warp_proxy`。

## 4. 固件 / 校准文件

`/lib/firmware/`：

```
7981_WACPU_RAM_CODE_release.bin      # WA CPU 固件
7981_WOCPU0_RAM_CODE_release.bin     # WO CPU0 固件
WIFI_RAM_CODE_MT7981.bin             # 主固件
mt7981_patch_e1_hdr.bin              # E1 补丁头
MT7981_iPAiLNA_EEPROM.bin            # 内置 PA/LNA 校准
MT7981_ePAeLNA_EEPROM.bin            # 外置 PA/LNA 校准
```

`/etc/wireless/l1profile.dat`：

```
Default
INDEX0=MT7981
INDEX0_profile_path=/etc/wireless/mediatek/mt7981.dbdc.b0.dat;/etc/wireless/mediatek/mt7981.dbdc.b1.dat
INDEX0_init_script=/lib/wifi/mtwifi.lua;/lib/wifi/mtwifi.lua
INDEX0_init_compatible=mtwifi;mtwifi
INDEX0_EEPROM_offset=0x0
INDEX0_EEPROM_size=0x5000
INDEX0_EEPROM_name=e2p
INDEX0_main_ifname=ra0;rax0
INDEX0_ext_ifname=ra;rax
INDEX0_wds_ifname=wds;wdsx
INDEX0_apcli_ifname=apcli;apclix
INDEX0_mesh_ifname=mesh;meshx
INDEX0_nvram_zone=dev1;dev2
INDEX0_single_sku_path=/etc/wireless/mediatek/mt7981-sku.dat
INDEX0_bf_sku_path=/etc/wireless/mediatek/mt7981-sku-bf.dat
```

`/etc/wireless/mediatek/` 下为 `mt7981.dbdc.b0.dat`、`mt7981.dbdc.b1.dat`、`mt7981-sku.dat`、`mt7981-sku-bf.dat`。

启动日志（dmesg，节选）：

```
conninfra: loading out-of-tree module taints kernel.
conninfra@(consys_plt_hw_init:162) adie_cfg_type = 1, one_adie_dbdc = 1
conninfra@(_consys_polling_chipid_int:306) Read CONNSYS HW IP version successfully! (0x02090000)
conninfra@(_connsys_a_die_cfg_7976:918) adie_idx[0], A-die CHIP ID = 0x7976, HW Version = 0x8b00
warp_module_init(): module init and register callback for warp
create warp_ctrl ok!!!
WiFi@C12L1,get_dbg_setting_by_profile() 4309: debug level setting=INDEX0_debug_level not found!!
WiFi@C12L1,match_index_by_chipname() 566: not find chip name INDEX1..INDEX9
mt7981_init()-->
<--mt7981_init()
```

说明：`INDEX0_debug_level`、`INDEX1..9` 的 not found 是单 profile 配置下的正常提示；`mt7981_init()` 结束表示 MTK 驱动初始化完成。

## 5. 无线启用情况（2026-11-19 复测：已正常）

说明：初版（2026-11-17 14:0x）的结论是"无线未启用，根因是镜像缺 `wifi-scripts`"。该问题已在当天下午修复：提交 `79d8bca`（237固件编译缺失了wifi）与 `e84fe6b`（237固件编译缺失了wifi和配置）为 [devconfig/237.config](devconfig/237.config) 增加了 `CONFIG_PACKAGE_wifi-scripts=y`。2026-11-19 10:24 CST 通过 SSH 复测，无线已正常工作。

### 5.1 复测结果

| 检查项 | 结果 |
| --- | --- |
| `opkg list-installed \| grep wifi-scripts` | `wifi-scripts - 1.0-r1`（已安装） |
| `ls -l /sbin/wifi` | 存在，5454 字节，可执行 |
| `/etc/config/wireless` | 存在（1035 字节）；`/rom/etc/config/wireless` 不存在，说明由 `/sbin/wifi config` 启动时生成 |
| `uci show wireless` | `default_MT7981_1_1.ssid='DIY-CPE-2.4G'`、`default_MT7981_1_2.ssid='DIY-CPE-5G'`，均为 `disabled='0'` |
| `ubus call network.wireless status` | `MT7981_1_1`：`up=true`、`autostart=true`、`pending=false` |
| `iwinfo` | `ra0`：DIY-CPE-2.4G，ch3，HE40，25 dBm；`rax0`：DIY-CPE-5G，ch48，HE160，24 dBm |
| `logread \| grep -i ucode` | 无 hostapd ucode 加载报错（初版的 `Unable to resolve path for module 'common'` 未再出现） |

SSID/加密/信道由 [files/etc/uci-defaults/99-custom-wifi](files/etc/uci-defaults/99-custom-wifi) 在首次启动时设置：`DIY-CPE-2.4G`（HE40）/ `DIY-CPE-5G`（HE160）、`psk-mixed`、信道 `auto`；其余 `path/type/band/country` 由 `wifi-scripts` 探测生成。

### 5.2 初版根因（已修复，保留备查）

驱动本身编译、加载正常，问题出在「无线配置生成」这条链路断在 `/sbin/wifi`。当时证据：

| 检查项 | 初版结果（2026-11-17） |
| --- | --- |
| `opkg list-installed \| grep wifi-scripts` | 无 |
| `which wifi` / `ls /sbin/wifi` | 不存在 |
| `/etc/init.d/boot` 第 56 行 | `/sbin/wifi config`（启动时生成无线配置） |
| 手动执行 `/sbin/wifi config` | `ash: /sbin/wifi: not found` |
| `/etc/config/` 与 `/rom/etc/config/` | 都没有 `wireless` |
| `uci show wireless` / `ubus call network.wireless status` | 空 / `{}` |
| `/lib/netifd/wireless/` | 只有 `mtwifi.sh`（驱动适配脚本，正常） |

链路关系：

```
/etc/init.d/boot → /sbin/wifi config          ← /sbin/wifi 由 wifi-scripts 提供（当时缺失）
/etc/hotplug.d/net/10-mtwifi-detect → /sbin/wifi config / up   ← 同上
/lib/wifi/mtwifi.sh (来自 mtwifi-cfg) → 依赖 wifi-scripts 生成 /etc/config/wireless
```

在本分支（padavanonly/immortalwrt-mt798x-6.6）里，`include/target.mk` 的 `DEFAULT_PACKAGES` 不含 `wifi-scripts`，`target/linux/mediatek/filogic/target.mk` 也没有补，`mtwifi-cfg` 的依赖（`libc, iwinfo, wifi-dats, lua-cjson, datconf-lua`）同样不会带入，因此 config 未显式打开时镜像就没有 `/sbin/wifi`。

修复方式即上述两个提交，在 `devconfig/237.config` 中增加：

```
CONFIG_PACKAGE_wifi-scripts=y
```

复测表明修复已生效：`/sbin/wifi` 存在，`/etc/config/wireless` 在启动时正常生成，2.4G/5G 均已起 VAP。

## 6. 与之前 QWRT 固件的对比

| 项目 | 当前 237 固件 | 之前 QWRT 固件 |
| --- | --- | --- |
| 发行版 | ImmortalWrt 24.10-SNAPSHOT `r0-ec9ef10` | QWRT（OpenWrt 25.12.3，`R26.10.10`） |
| 内核 | 6.6.133 | 6.6.129 |
| 驱动版本 | **7.6.6.1**（`kmod-mt_wifi ...7.6.6.1-mt7981-r1`） | **7.6.7.0** |
| 主模块 | `mt_wifi.ko`（7.19 MB） | `mt798x.ko`（9.02 MB，合并版） |
| 加速模块包 | `kmod-warp 6.6.133.20221209` | `kmod-warp-mt7981 6.6.129-3` |
| 无线默认配置 | 有（`wifi-scripts` 已安装，2.4G/5G 分别生成 DIY-CPE-2.4G / DIY-CPE-5G） | 有（QWRT-2.4G / QWRT-5G） |
| 无线接口 | ra0（ch3，HE40）/ rax0（ch48，HE160），均已起 VAP | ra0 / rax0（2.4G ch1、5G ch36） |

结论：237 构建的驱动版本比 QWRT 低一个小版本（7.6.6.1 vs 7.6.7.0），与仓库内 `mt798x-7.6.6.1-src.tar.xz` 一致；驱动、固件、校准文件、加速模块均齐全且初始化正常。`wifi-scripts` 缺失问题已于 2026-11-17 修复，2026-11-19 复测确认 2.4G/5G 无线均已正常启用。

## 7. 复现采集命令

```sh
cat /etc/openwrt_release; uname -a; cat /tmp/sysinfo/board_name
lsmod | grep -iE "mt_wifi|warp|conninfra|hnat"
opkg list-installed | grep -iE "mt_wifi|warp|conninfra|hnat|dats|mii_mgr"
opkg info kmod-mt_wifi
cat /etc/wireless/l1profile.dat
ls /lib/firmware | grep -i mt
dmesg | grep -aiE "conninfra|warp|mt7981|WiFi@"
iwinfo; ubus call network.wireless status
```
