# WH3000 Pro —— 237 编译固件 WiFi 驱动分析

- 采集时间：2026-11-17 14:0x（设备本地时间）
- 采集方式：SSH（`root@192.168.6.1`，237 固件默认 LAN 已变为 192.168.6.1）
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
| 无线状态 | 驱动已加载、接口已创建，但无线未配置（镜像缺 `wifi-scripts`，`/sbin/wifi` 不存在） |

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

## 5. 关键发现：无线未启用，根因是缺 `wifi-scripts` 包

说明：WiFi 驱动本身编译、加载都正常（见第 3、4 节），问题出在「无线配置生成」这条链路断在了 `/sbin/wifi`。

证据（设备实测）：

| 检查项 | 结果 |
| --- | --- |
| `opkg list-installed \| grep wifi-scripts` | 无（`wifi-scripts` 未安装） |
| `which wifi` / `ls /sbin/wifi` | 不存在 |
| `/etc/init.d/boot` 第 56 行 | `/sbin/wifi config`（启动时生成无线配置） |
| 手动执行 `/sbin/wifi config` | `ash: /sbin/wifi: not found` |
| `/etc/config/` 与 `/rom/etc/config/` | 都没有 `wireless`（镜像里本来就不带，靠启动时生成） |
| `uci show wireless` / `ubus call network.wireless status` | 空 / `{}` |
| `/lib/netifd/wireless/` | 只有 `mtwifi.sh`（驱动适配脚本，正常） |
| `/etc/hotplug.d/net/10-mtwifi-detect` | 检测到 `ra*` 接口后会调用 `/sbin/wifi config`、`/sbin/wifi up`（同样会失败） |

链路关系：

```
/etc/init.d/boot → /sbin/wifi config          ← /sbin/wifi 由 wifi-scripts 提供（缺失）
/etc/hotplug.d/net/10-mtwifi-detect → /sbin/wifi config / up   ← 同上
/lib/wifi/mtwifi.sh (来自 mtwifi-cfg) → detect_mtwifi() 生成默认配置
   默认 SSID：ImmortalWrt-2.4G / ImmortalWrt-5G 等
```

在本分支（padavanonly/immortalwrt-mt798x-6.6）里：

- `include/target.mk` 的 `DEFAULT_PACKAGES` 不含 `wifi-scripts`
- `target/linux/mediatek/filogic/target.mk` 只额外加了 `fitblk kmod-phy-aquantia kmod-crypto-hw-safexcel wpad-openssl uboot-envtools`
- `mtwifi-cfg` 的依赖是 `libc, iwinfo, wifi-dats, lua-cjson, datconf-lua`，也不会带入 `wifi-scripts`

所以只要 config 里没显式打开 `CONFIG_PACKAGE_wifi-scripts`，镜像就没有 `/sbin/wifi`，`/etc/config/wireless` 永远不会被生成——与仓库 `files/`（自定义 SSID/密码等）无关，`files/` 只是覆盖默认配置，不是这份最小构建的必需项。

次要问题：`logread` 中 hostapd 报

```
daemon.err hostapd: Error loading ucode: ... Unable to resolve path for module 'common'
```

因为镜像里 `/usr/share/ucode/` 只有 `fw4.uc` 和 `luci`，没有 hostapd 的 ucode 脚本目录。补上 `wifi-scripts`（依赖 `ucode + ucode-mod-nl80211 + ucode-mod-rtnl + ucode-mod-ubus + ucode-mod-uci`）后此问题通常一并消失。

修复方式：在 [devconfig/237.config](devconfig/237.config) 里加一行

```
CONFIG_PACKAGE_wifi-scripts=y
```

重新编译后首次启动，`/etc/init.d/boot` 会自动生成 `/etc/config/wireless`，默认开出 `ImmortalWrt-2.4G` / `ImmortalWrt-5G`；如需自定义 SSID/密码，再用 `files/etc/config/wireless` 覆盖或刷机后修改。

## 6. 与之前 QWRT 固件的对比

| 项目 | 当前 237 固件 | 之前 QWRT 固件 |
| --- | --- | --- |
| 发行版 | ImmortalWrt 24.10-SNAPSHOT `r0-ec9ef10` | QWRT（OpenWrt 25.12.3，`R26.10.10`） |
| 内核 | 6.6.133 | 6.6.129 |
| 驱动版本 | **7.6.6.1**（`kmod-mt_wifi ...7.6.6.1-mt7981-r1`） | **7.6.7.0** |
| 主模块 | `mt_wifi.ko`（7.19 MB） | `mt798x.ko`（9.02 MB，合并版） |
| 加速模块包 | `kmod-warp 6.6.133.20221209` | `kmod-warp-mt7981 6.6.129-3` |
| 无线默认配置 | 无（缺 `wifi-scripts`，`/sbin/wifi` 不存在，无法生成） | 有（QWRT-2.4G / QWRT-5G） |
| 无线接口 | ra0/rai0/ra1/rai1/rax0/raxx0（未起 VAP） | ra0 / rax0（2.4G ch1、5G ch36） |

结论：237 构建的驱动版本比 QWRT 低一个小版本（7.6.6.1 vs 7.6.7.0），与仓库内 `mt798x-7.6.6.1-src.tar.xz` 一致；驱动、固件、校准文件、加速模块均齐全且初始化正常，唯一缺失的是 `wifi-scripts` 包（导致无线配置无法生成）。

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
