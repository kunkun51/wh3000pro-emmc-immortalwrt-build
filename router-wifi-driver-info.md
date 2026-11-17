# WH3000 Pro（QWRT）WiFi 驱动信息采集

- 采集时间：2026-11-17 11:11（设备本地时间）
- 采集方式：SSH（root@192.168.1.1）远程执行命令，原始输出整理后归档
- 设备：Huasifei WH3000 Pro（`/tmp/sysinfo/board_name` = `huasifei,wh3000-pro`）

## 1. 系统 / 固件

| 项目 | 值 |
| --- | --- |
| 发行版 | OpenWrt 25.12.3（`DISTRIB_DESCRIPTION='QWRT '`） |
| 版本修订 | `R26.10.10`，`/etc/openwrt_version` = `r7703+16-94d2ccb044` |
| 目标平台 | `mediatek/mt798x`，`aarch64_cortex-a53` |
| 内核 | Linux 6.6.129（`#0 SMP Thu Oct 8 19:01:26 2026`） |
| 内核编译工具链 | aarch64-openwrt-linux-musl-gcc 14.3.0（OpenWrt GCC 14.3.0 r7241-bdec0000c1），Binutils 2.44 |
| 编译主机 | `lean@lean-esx` |
| 内核污染标记 | `no-all`（闭源 WiFi 驱动为 out-of-tree 模块） |

## 2. WiFi 硬件

| 项目 | 值 |
| --- | --- |
| WiFi 芯片 | MediaTek MT7981（DDBD 单芯片双频） |
| PCI/USB ID | `14C3:7981` |
| RF A-die | CHIP ID `0x7976`（MT7976），HW Version `0x8b00` |
| ConnInfra HW IP | `0x02090000`（`CONNSYS HW IP version`） |
| A-die 版本 | `a-die version:1` |
| EEPROM | `e2p`，offset 0x0，size 0x5000；运行时功率覆盖 2G/5G = `0x2b` |
| 校准 | `eeprom 0x19a bit0 = 0` → 启动时做 runtime cal（DPD flatness） |

## 3. WiFi 驱动（重点）

| 项目 | 值 |
| --- | --- |
| 驱动类型 | MTK 闭源驱动（非 mt76） |
| 驱动版本 | **7.6.7.0**（模块内版本字符串 `7.6.7.0`；编译路径 `target-aarch64_cortex-a53_musl/linux-mediatek_mt798x/mt798x-mt7981/mt798x-7.6.7.0/mt_wifi_ap/...`） |
| 内核模块名 | `mt798x.ko`（13,521,440 字节，加载名 `mt798x`；`mt_wifi`/`mt_wifi_mt7981` 模块名均不存在，已被合并为 `mt798x`） |
| 模块路径 | `/lib/modules/6.6.129/mt798x.ko`（构建日期 2026-10-09 03:01） |
| 配套加速模块 | `mtk_warp.ko`（WED/WARP v2）、`mtk_warp_proxy.ko`、`mtkhnat.ko`（HNAT）、`conninfra.ko` |
| 驱动内部版本函数 | `Driver Version = %s`（可经私有 ioctl 读取；本机 `iwpriv ra0 show driverver` 不被接受） |

驱动加载后的 `lsmod` 依赖关系：

```
mt798x            9306112  3 mtk_warp_proxy      # 闭源 WiFi 主模块（含 MT7981 固件）
mtk_warp           294912  1 mtk_warp_proxy      # WARP v2 / WED 加速
mtk_warp_proxy      16384  0
mtkhnat             90112  2 mt798x,mtk_warp    # 硬件 NAT
conninfra          151552  1 mt798x             # 连接子系统（WiFi/BT 共用）
```

## 4. 相关软件包版本（opkg）

| 软件包 | 版本 |
| --- | --- |
| kmod-conninfra-mt7981 | `6.6.129+bbf588-2` |
| kmod-warp-mt7981 | `6.6.129-3` |
| kmod-mediatek_hnat | `6.6.129-1` |
| mtwifi_service | `8` |
| ralink-wifi-base | `3` |
| wireless-tools | `29-6` |

## 5. 无线接口状态（iwinfo）

| 接口 | 角色 | SSID | 频段/信道 | 模式 | 发射功率 | 加密 |
| --- | --- | --- | --- | --- | --- | --- |
| ra0 | AP（主） | QWRT-2.4G | 2.4G ch1 (2412 MHz) | 802.11ax，HE40 | 24 dBm | WPA PSK (CCMP) |
| rax0 | AP（主） | QWRT-5G | 5G ch36 (5180 MHz) | 802.11ac/ax，HE160 | 24 dBm | WPA PSK (CCMP) |
| apcli0 / apclix0 | Client（未连接） | - | 2.4G / 5G | HT20 | - | - |

- `wireless.ra.type='mt_dbdc'`、`wireless.rax.type='mt_dbdc'`（DDBD 双频双并发）
- 2.4G MAC `58:23:BC:00:BA:27`，5G MAC `5A:23:BC:50:BA:27`
- 国家码 CN，`txpower=100`（即 24 dBm）
- 驱动上报支持模式：802.11 a/b/g/n/ac/ax（HW 字符串另含 be/ad 标记，但当前接口仅协商到 ax）

## 6. 配置文件

- `/etc/wireless/l1profile.dat`：`INDEX0=MT7981`，profile 路径 `/etc/wireless/mediatek/mt7981.dbdc.b0.dat;/etc/wireless/mediatek/mt7981.dbdc.b1.dat`
- `/etc/wireless/mediatek/`：`mt7981.dbdc.b0.dat`、`mt7981.dbdc.b1.dat`、`DBDC_card0.dat`、`mt7981-sku.dat`、`mt7981-sku-bf.dat`（SKU/波束成形表）
- 接口命名：主接口 `ra0;rax0`，扩展 `ra;rax`，WDS `wds;wdsx`，AP-Client `apcli;apclix`，Mesh `mesh;meshx`

## 7. 启动日志要点（dmesg）

```
conninfra: loading out-of-tree module taints kernel.
conninfra@(_consys_polling_chipid_int:306) Read CONNSYS HW IP version successfully! (0x02090000)
conninfra@(_connsys_a_die_cfg_7976:918) adie_idx[0], A-die CHIP ID = 0x7976, HW Version = 0x8b00
MT7976: runtime EEPROM power override 2G 0x441-0x444=0x2b, 5G 0x445-0x458=0x2b
WiFi@C00L1,mt7981_apply_dpd_flatness_data() 622: eeprom 0x19a bit 0 is 0, do runtime cal
WiFi@C02L1,is_cal_free_ic() 886: [a-die version:1]
WiFi@C12L1,RTMPWirelessModeCfg() 611: Init: BSS0 PhyMode=78 ... BSS5 PhyMode=177
WiFi@C00L2,red_tail_drop_init() 82: red_tail_drop_init: available token:8192, whnat_en:1
warp_dev0 15010000.wed: Using 32bit DMA for streaming/coherent map
```

说明：`PhyMode=78` 为 2.4G（11ax/n）、`PhyMode=177` 为 5G（11ax/ac）；`whnat_en:1` 表示 WiFi HNAT 加速已开启。

## 8. 与本地编译工程对照

- 本机工程 `mt798x-7.6.6.1-src.tar.xz` 对应驱动 **7.6.6.1**；`devconfig/.config` 中 `CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673=y`
- 路由器当前运行的是 **7.6.7.0**，版本高于工程内源码。
- 工程里 2.4G/5G 由 `mt_wifi` 双包 + `warp`/`conninfra`/`mediatek_hnat` 组成；路由器固件（QWRT）已把 WiFi 主驱动裁剪/合并为单个 `mt798x.ko`，并保留 `kmod-warp-mt7981`、`kmod-conninfra-mt7981`、`kmod-mediatek_hnat` 独立包。

## 9. 复现采集命令

```sh
cat /etc/openwrt_release; cat /etc/openwrt_version; uname -a
cat /tmp/sysinfo/board_name; cat /tmp/sysinfo/model
lsmod | grep -iE "mt798x|warp|conninfra|hnat"
opkg list-installed | grep -iE "mt_wifi|mtwifi|warp|conninfra|hnat|wireless"
strings /lib/modules/$(uname -r)/mt798x.ko | grep -E "^7\.[0-9]+\.[0-9]+" | head
iwinfo; dmesg | grep -aiE "WiFi|conninfra|warp"
head -40 /etc/wireless/l1profile.dat
```
