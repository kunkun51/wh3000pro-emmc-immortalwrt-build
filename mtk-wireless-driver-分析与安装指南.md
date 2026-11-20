# luhujp/mtk-wireless-driver 分析与安装指南

- 信息来源：<https://github.com/luhujp/mtk-wireless-driver/tree/master/drivers> 及其仓库内 `README.md`、`about-mtk-wifi.md`、各驱动 `Makefile`
- 核对方式：GitHub 仓库目录树、README、驱动 Makefile、全仓库 `7981` 搜索
- 说明：本文只整理该页面及其仓库公开内容；标注为「OpenWrt 通用流程」的部分，是该页面未展开、但按 OpenWrt 常规构建方式必须执行的标准步骤

---

## 1. 是否包含 MT7981 驱动

**结论：否，不包含 MT7981 驱动。**

依据：

1. `drivers/` 目录下只有 12 个目录：`exfat-nofuse`、`mt7603`、`mt7603e`、`mt7610`、`mt7610e`、`mt7612`、`mt7615`、`mt7615e`、`mt7620`、`mt7628`、`mt7628sta`、`mt76x2e`，没有 `mt7981`。
2. 仓库 README 明确列出的型号为：`mt7603 / mt7603e / mt7610 / mt7610e / mt76x2e / mt7612 / mt7615 / mt7615e / mt7620 / mt7628 / mt7628sta`，没有 MT7981。
3. 对仓库全部文件路径搜索 `7981`：无匹配；代码搜索 `7981`：结果为 0。
4. `mt7615e` 的芯片配置项只覆盖 `CHIP_MT7603E`、`CHIP_MT7615E`、`CHIP_MT7622`、`CHIP_MT7663E` 等上一代芯片，没有 MT7981。

因此该仓库不能用于 MT7981 设备（包括 WH3000 Pro），也不存在可套用的 MT7981 安装步骤。

---

## 2. 无线驱动型号清单

### 2.1 主清单（README 与 drivers/ 目录一致）

| 目录 | 型号 / 包名 | 构建方式 | 页面/Makefile 中的关键信息 |
| --- | --- | --- | --- |
| `mt7603` | MT7603 | 预编译 `.ko` 下载 | 包名 `mt7603`，`DEPENDS:=+wireless-tools` |
| `mt7603e` | MT7603e | 源码编译 | 源包 `MT7603e_LinuxAP_V4.0.1.0rev1_DPA_20150629.tar.bz2`，`PKG_SOURCE_URL:=http://localhost/` |
| `mt7610` | MT7610 | 预编译 `.ko` 下载 | 包名 `mt7610`，`+wireless-tools` |
| `mt7610e` | MT7610e | 源码编译 | 源包 `mt7610e-$(P4REV).tar.bz2`，`PKG_SOURCE_URL:=http://localhost/` |
| `mt7612` | MT7612 | 预编译 `.ko` 下载 | 包名 `mt7612`，`+wireless-tools +mt76x2` |
| `mt7615` | MT7615 | 预编译 `.ko` 下载 | 包名 `mt7615`，`+wireless-tools` |
| `mt7615e` | MT7615e | 源码编译 | 源包 `MT7622_7615_SoftAP_v5.0.2.0_20180430.tar.xz`，`PKG_SOURCE_URL:=http://luhu.vn:85/` |
| `mt7620` | MT7620 | 预编译 `.ko` 下载 | 包名 `mt7620`，`+wireless-tools` |
| `mt7628` | MT7628 | 预编译 `.ko` 下载 | 包名 `mt7628`，`+wireless-tools` |
| `mt7628sta` | MT7628 STA | 源码编译 | 包名 `mt7628sta`，仅限 `TARGET_ramips_mt7628` |
| `mt76x2e` | MT76x2e | 源码编译 | 包名 `mt76x2e`，`DEPENDS:=+kmod-cfg80211`，源包 `MT76x2e_MT7620_LinuxAP_V3.0.4.0_DPA_20150617.tar.bz2`，`PKG_SOURCE_URL:=http://localhost/` |

### 2.2 容易漏掉的同包型号

`mt7612/Makefile` 除了 `mt7612` 外，还定义了：

- `mt76x2`：隐藏包（`HIDDEN:=1`），提供共用模块；
- `mt7602`：MT7602 型号，依赖 `+mt76x2`，与 MT7612 共用同一个 `mt7612.ko` 和对应的 `.dat` 配置。

所以如果按“芯片型号”统计，页面实际涉及 **MT7602**；`MT76x2` 则是共用驱动包/系列名。

### 2.3 非无线项

`drivers/exfat-nofuse` 是 exFAT 文件系统驱动，不属于 WiFi 驱动。列出它是为了说明 `drivers/` 目录的完整性，安装 WiFi 驱动时不要选它。

---

## 3. 安装操作指南

### 3.1 前置检查

1. 确认设备芯片型号与目标驱动一致；MT7981 不在支持列表内。
2. 记录内核版本和目标平台，预编译模块必须严格匹配：

```sh
uname -r
cat /etc/openwrt_release
```

3. 备份当前固件与 `/lib/modules`、`/etc/wireless`、`/lib/firmware`，MTK 闭源驱动与具体设备强相关，页面也明确提示“可能不适用甚至导致系统崩溃”。

### 3.2 方式 A：作为 OpenWrt feed 编译（README 推荐）

**依赖准备**

- 一个可正常编译的 OpenWrt/LEDE 工作区（README 明确要求）；
- 页面/Makefile 明确声明的运行依赖：`wireless-tools`、`base-files`；`mt76x2e` 还需要 `kmod-cfg80211`；
- 如需网页管理，先装好 LuCI（`mtk-luci-plugin` 依赖 `lua`）；
- 下载外部源码包需要 `wget`、`tar`、`bzip2`、`xz`（Makefile 使用 `wget`/`tar`）。

**步骤**

1. 进入 OpenWrt 工作区根目录：

```sh
cd openwrt
```

2. 在 `feeds.conf.default` 末尾加入 feed。README 原文写的是：

```sh
src-git mtk https://github.com/luuhungit/mtk-wireless-driver.git
```

说明：`luuhungit` 是旧命名，GitHub 会重定向到本页的 `luhujp/mtk-wireless-driver`；两者当前都能解析。若不想依赖重定向，可直接写本页地址：

```sh
src-git mtk https://github.com/luhujp/mtk-wireless-driver.git
```

3. 更新并安装 feed：

```sh
./scripts/feeds update -f mtk
./scripts/feeds install -a -p mtk
```

4. 进入菜单选择驱动：

```sh
make menuconfig
```

路径为 **MTK Properties → Drivers**，选择与设备匹配的驱动包；建议同时选择 **MTK Properties → Misc → mtk-luci-plugin**（提供 LuCI 管理页和 `/sbin/mtkwifi`）。

5. 编译（OpenWrt 通用流程）：

```sh
# 全量编译
make -j$(nproc) V=s

# 或只编译某个驱动包，包名见第 2 节表格
make package/mt7615/compile V=s
make package/mt7615e/compile V=s
```

6. 安装生成的 ipk（OpenWrt 通用流程）：产物在 `bin/packages/<架构>/mtk/`，上传到设备后：

```sh
opkg install /tmp/<包名>.ipk
```

> 注意：`mt7603e`、`mt7610e`、`mt7628sta`、`mt76x2e` 的 `PKG_SOURCE_URL` 是 `http://localhost/`，仓库并未真正托管这些源码包。编译前必须自行准备对应 tarball 放入 `dl/`，否则下载阶段会失败。

### 3.3 方式 B：直接使用预编译 `.ko`（about-mtk-wifi.md 的 Case 2）

适用于 `mt7603`、`mt7610`、`mt7612`、`mt7615`、`mt7620`、`mt7628` 这类通过 `PKG_URLS` 下载 `.ko` 的驱动。

1. 确认平台与内核，拼出文件名，页面给出的规则是：

```
<驱动名>-for-<subtarget>-linux-<内核版本>.ko
```

例如页面示例：MT7621 + mt7603 + linux-4.4.112，对应：

```
http://nossiac.com/download/mtk-wifi-ko/mt7603-for-mt7621-linux-4.4.112.ko
```

2. 在设备上下载：

```sh
wget http://nossiac.com/download/mtk-wifi-ko/<驱动名>-for-<subtarget>-linux-<内核版本>.ko -O /tmp/<驱动名>.ko
```

3. 放入模块目录（页面明确要求使用 `modprobe` 时放到这里）：

```sh
mkdir -p /lib/modules/$(uname -r)
cp /tmp/<驱动名>.ko /lib/modules/$(uname -r)/
```

4. 加载并拉起接口：

```sh
modprobe <驱动名>
ifconfig ra0 up
```

页面示例写的是 `modprobe mt7615e.ko` 后 `ifconfig ra0 up`；实际模块名以文件名/`lsmod` 为准，部分驱动接口名可能是 `rai0` 或 `wlan`。

5. 若安装了 `mtk-luci-plugin`，也可用：

```sh
/sbin/mtkwifi start
/sbin/mtkwifi reload
/sbin/mtkwifi stop
```

### 3.4 配置方法

MTK 闭源驱动**不使用 OpenWrt 的 UCI**，页面明确说明：

- 驱动读取 `/etc/wireless/<驱动名>/*.dat` 形式的 profile（例如 `mt7620.dat`、`mt7615.1.dat`、`mt7615e.1.dat` 等），文件内容是 `Key=Value`；
- 校准数据为 `e2p.bin` / `eeprom.bin`，通常位于 `/lib/firmware/`，由设备的 `factory` 分区生成；
- 配置方式三选一：
  1. **mtk-luci-plugin**：在 LuCI 中直接读写 `.dat`，并提供 `/sbin/mtkwifi`；
  2. **uci2dat**：把 `/etc/config/wireless` 翻译成 MTK profile；
  3. **wificonf**：命令行读写 `Key=Value` 配置；
- `mtk-nvram` 是旧式 raw flash nvram 工具，页面说明保留它只是为了兼容旧设备；
- 如需开机自动启动，页面给出的“最简单 hack”是用 `/sbin/mtkwifi` 覆盖 `/sbin/wifi`，或自行编写 rcS 脚本。

### 3.5 验证驱动是否安装成功

按页面给出的检查顺序：

```sh
# 1) 模块是否加载
lsmod | grep mt

# 2) 是否创建了无线接口
ifconfig -a

# 3) 无线接口是否被驱动识别（需要 wireless-tools）
iwconfig
# 或
iw dev
```

补充（页面 Troubleshooting 明确要求）：

```sh
# 4) 让无线接口接入 br-lan，才能从 DHCP 获取地址
brctl addif br-lan ra0

# 5) 检查 profile / eeprom 文件是否到位
ls /etc/wireless/<驱动名>/
ls -l /lib/firmware/ | grep -i <驱动名>
```

判定标准：

- `lsmod` 能看到对应模块；
- `ifconfig -a` 出现 `ra0`/`rai0`/`wlan` 等接口；
- `iwconfig`/`iw` 能看到该接口及 SSID；
- 接入 `br-lan` 后客户端能获取 IP；
- LuCI 的 `mtk-luci-plugin` 页面可以执行 Reload/Start/Stop。

---

## 4. 注意事项、常见问题与解决

### 4.1 不要用于 MT7981

本仓库没有 MT7981 驱动。WH3000 Pro（MT7981）不能套用本页任何驱动或 `.ko`；强行加载会导致 `invalid module format`、未知符号或系统崩溃。

### 4.2 驱动不会自动启动

页面明确说明：出于安全考虑，模块加载后不会自动运行。需要手动 `modprobe`、`ifconfig ra0 up`，或使用 `mtkwifi`/LuCI Reload，或自行改 rcS。

### 4.3 提示缺少文件

驱动运行时通常需要两个文件：

- `mt76xx.dat`：运行时 profile。用 feed 编译时会自动安装；手动安装时需要自己创建；
- `e2p.bin` / `eeprom.bin`：芯片校准数据，通常在 `factory` 分区。页面给出的提取示例：

```sh
dd if=/dev/$(grep -i '"factory"' /proc/mtd | cut -c 1-4) of=/lib/firmware/<FILENAME>.bin bs=1 count=512
```

如果提取失败，需要用原厂固件备份恢复 `factory` 分区。

### 4.4 搜不到无线网络

按页面顺序排查：

```sh
lsmod | grep mt          # 驱动是否加载
ifconfig -a              # 接口是否创建
iwconfig                 # 是否能看到 SSID
```

并检查：SSID 是否被设为隐藏、信道是否超出设备支持范围、接口是否已 `up`。

### 4.5 客户端拿不到 IP

OpenWrt 的 DHCP 只服务 `br-lan`，需把无线接口加入网桥：

```sh
brctl addif br-lan ra0
```

### 4.6 预编译模块版本不匹配

`PKG_KO` 的命名包含 `CONFIG_TARGET_SUBTARGET` 和 `LINUX_VERSION`，说明 `.ko` 与平台、内核强绑定。内核或 subtarget 不一致时会出现：

- `insmod: invalid module format`
- `unknown symbol`
- 模块加载后无接口

解决：使用与设备完全匹配的 `.ko`，或在对应 OpenWrt 工作区内用 feed 重新编译。

### 4.7 下载源可能不可用

- README 的预编译下载地址为 `http://nossiac.com/download/mtk-wifi-ko`（实测返回 301 跳转）和 `http://119.23.148.191:8888/mtk-wifi-ko`（实测连接超时）；
- `mt7615e` 的源码地址 `http://luhu.vn:85/` 实测连接超时；
- `mt7603e`、`mt7610e`、`mt7628sta`、`mt76x2e` 的源码地址是 `http://localhost/`，仓库未托管源码包。

遇到下载失败时，只能自行准备对应 tarball 放入 `dl/`，或改用其他可用镜像；这不是编译参数问题。

### 4.8 接口名不固定

页面提示：`mt7612`、`mt7615` 等驱动的接口名可能是 `rai0` 或 `wlan`，不是固定 `ra0`。加载后用 `ifconfig -a` 确认。

### 4.9 不支持标准 mac80211/cfg80211 与 UCI

页面 FAQ 明确：

- MTK 驱动不走 mac80211/cfg80211 标准架构（部分驱动仅部分支持 cfg80211）；
- 不支持 OpenWrt 的 UCI 无线配置；
- 因此标准 LuCI 无线页面不能管理它，必须用 `mtk-luci-plugin` 或 `uci2dat`。

### 4.10 驱动源码与授权

页面 FAQ 说明：MTK WiFi 驱动没有开源许可，仓库不发布驱动源码，合法获取源码需要与 MediaTek 签署 NDA。仓库提供的是 Makefile、配置文件、补丁和预编译模块；`mt7615e` 等目录会从外部 URL 拉取源码包。

### 4.11 文档之间的不一致

- `README.md` 的 feed 地址写的是 `luuhungit/mtk-wireless-driver`，当前重定向到本页 `luhujp/mtk-wireless-driver`；
- `about-mtk-wifi.md` 的 Case 1 使用的是另一个 feed：`https://github.com/Nossiac/mtk-openwrt-feeds;lede-17.01`，与本仓库不是同一套内容；
- `about-mtk-wifi.md` 示例文字写“以 7603 为例”，命令却是 `modprobe mt7615e.ko`。

实操时以本仓库 `README.md` 的 feed 方式为准，不要混用两套 feed。

### 4.12 `exfat-nofuse` 不是 WiFi 驱动

它只是放在 `drivers/` 下的 exFAT 文件系统驱动，与无线无关，安装 WiFi 驱动时忽略。

---

## 5. 对 WH3000 Pro（MT7981）的结论

- 该仓库**不包含 MT7981 驱动**，也没有 MT7981 的 `.dat`、固件、校准文件或 Makefile；
- 因此不能按本页步骤给 WH3000 Pro 安装或替换 WiFi 驱动；
- WH3000 Pro 应继续使用其现有 MT7981 驱动栈（当前设备为 `mt_wifi` 7.6.6.1 + `conninfra` + `mtk_warp`/`mtkhnat`），或使用 MT7981 对应的厂商 SDK/固件，而不是本仓库的 MT7603/MT7615/MT7620/MT7628 系列模块。
