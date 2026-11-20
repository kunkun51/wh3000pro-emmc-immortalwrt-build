# MTK WiFi 硬件加速检测指南（WHNAT / HNAT / WARP-WED）

- 适用设备：Huasifei WH3000 Pro（MT7981 + MT7976），ImmortalWrt 24.10-SNAPSHOT，内核 6.6.133
- 适用固件：`build-237.yml` 产物（MTK 闭源 `mt_wifi` 7.6.6.1 + `mtkhnat` + `mtk_warp`）
- 检测方式：SSH 登录路由器（`root@192.168.1.1`），或 LuCI 页面
- 最后实测：2026-11-19

> 这里说的「MTK WiFi 硬件加速」由三部分组成，必须分开验证：
> 1. **HNAT**：PPE 硬件 NAT，负责把已建立的连接从 CPU 转发路径卸载到硬件；
> 2. **WHNAT**：让 WiFi 接口（`ra0` / `rax0`）也参与 HNAT；
> 3. **WARP / WED**：WiFi 数据面卸载（WED + WO CPU），负责 WiFi ↔ 以太网的收发路径加速。
>
> 只有三者都正常，才是完整的 WiFi 硬件加速。

---

## 0. 当前设备实测结论（先给答案）

| 检测项 | 实测值 | 结论 |
| --- | --- | --- |
| TurboACC Fastpath | `mediatek_hnat` | 已启用 |
| `ubus call luci.turboacc getFastPathStat` | `{"type":"MediaTek HNAT"}` | 正常（无 "Wireless HNAT Disabled"） |
| `hook_toggle` | `enabled` | HNAT 钩子已启用 |
| 无线 profile `WHNAT` | `mt7981.dbdc.b0.dat`、`mt7981.dbdc.b1.dat`、`DBDC_card0.dat` 均为 `WHNAT=1` | 无线 HNAT 已开启 |
| `whnat_interface` | `1:ra0`、`2:rax0` | 两个 WiFi 接口已注册 |
| `external_interface` | `ra0`、`rax0`、`eth2` | WiFi 与有线接口都已纳入 |
| WED | `WED_VERSION: 2.2` | 已初始化 |
| WO CPU | `WO MCU status: Alive(e8aa8)` | 已运行 |
| PPE 绑定 | `BIND_PPE0` 2~3，`BIND_PPE1` 0，`ALL=16384` | 有线流量已被硬件绑定 |
| 无线客户端 | `iwinfo ra0/rax0 assoclist` = `No station connected` | 当前无 WiFi 客户端，WHNAT 尚未被实际流量触发 |

**结论：硬件加速链路已正确启用；有线 HNAT 已用实际流量验证（PPE 绑定数增长、表项 bytes/packets 非 0）。WiFi 侧处于「就绪但未压测」状态，需要按第 5 节接入无线客户端做动态验证。**

---

## 1. 快速检测：5 条命令（普通用户可直接复制）

SSH 登录后执行：

```sh
# 1) TurboACC 快速路径类型
ubus call luci.turboacc getFastPathStat

# 2) PPE 绑定数量
ubus call luci.turboacc getMTKPPEStat

# 3) HNAT 钩子开关
cat /sys/kernel/debug/hnat/hook_toggle

# 4) 无线 profile 的 WHNAT 标志
grep -H 'WHNAT' /etc/wireless/mediatek/*.dat

# 5) 已注册的 WiFi HNAT 接口
cat /sys/kernel/debug/hnat/whnat_interface
```

### 判断标准

| 命令 | 正常输出 | 异常输出 | 含义 |
| --- | --- | --- | --- |
| `getFastPathStat` | `{"type":"MediaTek HNAT"}` | `{"type":""}`、`"Flow offloading"`、末尾带 `"/ Ethernet HNAT Disabled"` 或 `"/ Wireless HNAT Disabled"` | 快速路径引擎未切到 MTK HNAT，或对应 HNAT 被关闭 |
| `getMTKPPEStat` | `PPE_NUM=2`，`BIND_PPE0 > 0`（有流量时） | `BIND_PPE0=0` 持续存在（有持续流量） | 没有任何连接被硬件绑定 |
| `hook_toggle` | `enabled` | `disabled` | HNAT 钩子被关闭，新连接不会被卸载 |
| `WHNAT` | 相关 `.dat` 均 `WHNAT=1` | `WHNAT=0` 或文件缺失 | WiFi 侧未开启 HNAT |
| `whnat_interface` | 包含 `ra0`、`rax0` | 为空或缺少 WiFi 接口 | WiFi 接口未注册到 HNAT |

> `BIND_PPE1=0` 是正常的：当前拓扑所有流量绑定在 PPE0 上，不代表加速失败。

---

## 2. LuCI 页面检测（无需命令行）

1. 浏览器打开 `http://192.168.1.1`，登录 LuCI。
2. 进入 **网络 → TurboACC**（`admin/network/turboacc`）。
3. 查看 **Acceleration Status / 加速状态**：
   - **FastPath Engine**：应显示 `MediaTek HNAT`；
   - 若显示 `MediaTek HNAT / Wireless HNAT Disabled`，说明无线 profile 的 `WHNAT=1` 缺失；
   - 若显示 `MediaTek HNAT / Ethernet HNAT Disabled`，说明 `hook_toggle` 被关闭；
   - **PPE0 / PPE1 Bind Entrys**：有流量时应看到绑定数量与进度条变化。
4. 同一页面向下检查设置：
   - **Fastpath engine** = `MediaTek HNAT`
   - **Enable ethernet HNAT** = 开启
   - **Enable ethernet IPv6 HNAT** = 开启
   - **HNAT bind rate threshold (pps)** = 30（默认；低于该包速率的连接不会绑定）
   - **Number of HNAT PPE** = 2

TurboACC 页面本质调用以下 ubus 方法，可与命令行结果互相印证：

```sh
ubus call luci.turboacc getFastPathStat
ubus call luci.turboacc getMTKPPEStat
ubus call luci.turboacc getSystemFeatures
```

---

## 3. 驱动与系统层检测（进阶）

### 3.1 模块与初始化

```sh
lsmod | grep -E 'mtkhnat|mtk_warp|mtk_warp_proxy|mt_wifi|conninfra'
dmesg | grep -iE 'PPE[0-9]+ hwnat start|WHNAT support list|create wed ok|WO_STATE_ENABLE|warp entry_acquire|mtk_ppe_dev_register_hook'
```

**正常样例（本机实测）**

```
mediatek_soc_hnat 15100000.hnat: PPE0 hwnat start
mediatek_soc_hnat 15100000.hnat: PPE1 hwnat start
warp_cap_support(): chip_id=7981 is in WHNAT support list
create wed ok!!!
warp_woctrl_init_state(), wo_state: WO_STATE_ENABLE
mtk_ppe_dev_register_hook : ineterface ra0 register (1)
red_tail_drop_init: available token:8192, whnat_en:1
```

**异常特征**

```
mtkhnat / mtk_warp 未加载
PPE0 hwnat start 缺失
create wed ok 缺失，或出现 wed_init / wed_ring_init failed
WHNAT support list 中没有 7981
whnat_en:0
```

### 3.2 WARP / WED / WO CPU 状态

```sh
cat /proc/warp_ctrl/warp0/wed | head -5
cat /proc/warp_ctrl/warp0/wo | head -10
cat /proc/warp_ctrl/warp0/cfg | head -25
```

**正常样例**

```
WED_VERSION: 2.2
WED_BRANCH/ECO: 0/0
WO MCU status: Alive(e8aa8)
WED_REV :20020000
WED_CTRL:3015505
```

**异常特征**：文件不存在、`WO MCU status` 不是 `Alive`、`WED_*` 寄存器全 0、`wed` 文件报错。

> 启动日志中出现一次 `warp_woctrl_kickout ... state:HALT` 不一定代表故障；以 `wo` 文件中的实时 `WO MCU status` 和实际绑定结果为准。若同时出现 `warp`/`wed` 的 fail/error 且 `WO MCU status` 非 Alive，才判定异常。

### 3.3 配置与接口注册

```sh
cat /etc/config/turboacc
grep -H 'WHNAT' /etc/wireless/mediatek/*.dat
cat /sys/kernel/debug/hnat/whnat_interface
cat /sys/kernel/debug/hnat/external_interface
```

**正常样例**

```
# /etc/config/turboacc
option fastpath 'mediatek_hnat'
option fastpath_mh_eth_hnat '1'
option fastpath_mh_eth_hnat_v6 '1'
option fastpath_mh_eth_hnat_bind_rate '30'
option fastpath_mh_eth_hnat_ppenum '2'

# WHNAT
/etc/wireless/mediatek/mt7981.dbdc.b0.dat:418:WHNAT=1
/etc/wireless/mediatek/mt7981.dbdc.b1.dat:420:WHNAT=1
/etc/wireless/mediatek/DBDC_card0.dat:268:WHNAT=1

# whnat_interface
1:ra0
2:rax0

# external_interface
ext devices [0] = ra0
ext devices [1] = rax0
ext devices [2] = eth2
```

### 3.4 HNAT 表项与统计（核心判据）

```sh
cat /sys/kernel/debug/hnat/hnat_stats
cat /sys/kernel/debug/hnat/hnat_entry
grep -E 'state=BIND' /sys/kernel/debug/hnat/all_entry
```

**`hnat_stats` 正常样例**

```
PPE_NUM=2
ALL_PPE0=16384
BIND_PPE0=3
ALL_PPE1=16384
BIND_PPE1=0
```

**`hnat_entry` 正常样例**

```
============================
PPE_ID = 0
NAPT(1152): 36.248.11.158:443->10.17.156.84:58897 => 36.248.11.158:443->192.168.1.202:58897
IPv6_5T(10924): 2408871A:30000001:00000000:00000331:443 => ...
Total State = BIND cnt = 3
============================
```

**`all_entry` 正常样例（关键字段）**

```
bytes=644776|packets=2507|...|index=10924|state=BIND|type=IPV6_5T_ROUTE|192.168...|58:23:bc:00:ba:29=>68:da:73:af:03:a7|etype=0x86dd
```

判读要点：

| 字段 | 正常 | 异常 |
| --- | --- | --- |
| `state` | `BIND` | 长期只有 `UNBIND` |
| `bytes` / `packets` | 持续增长（两次快照对比） | 一直为 0 |
| `type` | `IPV4_HNAPT`、`IPV6_5T_ROUTE` | 无任何条目 |
| MAC 对 | 路由器 MAC => 客户端 MAC | 全 0 或与实际客户端不符 |
| `BIND_PPE0` | 有流量时增长 | 高负载下始终为 0 |

> `hnat_version`、`hnat_setting`、`hnat_ppd_if` 在本固件中读取为空，属正常现象，不要用它们判断成败。

### 3.5 HNAT 钩子状态

```sh
cat /sys/kernel/debug/hnat/hook_toggle   # 期望 enabled
cat /sys/kernel/debug/hnat/qos_toggle    # 本机为 disabled，正常
```

启动日志中常见：

```
hnat hook is going to be disabled !
hnat hook is going to be enabled !
```

这是 `turboacc` 启动脚本按 `1 → 0 → 1` 重置钩子的正常动作（脚本逻辑：`echo 1`、`echo 0`、再写入配置值），**不是故障**。

---

## 4. 动态验证原理（为什么必须压流量）

HNAT 只有在连接达到绑定阈值后才会把流量卸载到 PPE。默认阈值：

```
option fastpath_mh_eth_hnat_bind_rate '30'
```

即连接需要持续约 30 pps 才容易触发绑定。因此：

- 打开网页、刷 LuCI、SSH 到路由器本身：**不会产生可绑定的转发流**；
- 必须由 LAN/WiFi 客户端发起持续的**跨 WAN 下载/上传**（speedtest、iperf3、大文件下载）。

---

## 5. WiFi 硬件加速动态验证（推荐流程）

### 5.1 准备

1. 用手机或笔记本连接 `DIY-CPE-2.4G` / `DIY-CPE-5G`（密码见 `files/etc/uci-defaults/99-custom-wifi`，默认 `11111111`）。
2. 确认客户端已关联：

```sh
iwinfo ra0 assoclist
iwinfo rax0 assoclist
```

正常会列出客户端 MAC、信号、速率；未连接时显示 `No station connected`。

3. 取客户端 IP：

```sh
cat /tmp/dhcp.leases
```

### 5.2 基线快照

```sh
cat /sys/kernel/debug/hnat/hnat_stats
grep -c 'state=BIND' /sys/kernel/debug/hnat/all_entry
```

### 5.3 在无线客户端上制造持续流量

任选其一，持续 20~30 秒：

```sh
# 客户端为 Linux/macOS 时
curl -o /dev/null --max-time 30 http://<路由器WAN侧可访问的大文件>
# 或使用 speedtest / iperf3 客户端
```

建议同时记录客户端实际速率。

### 5.4 压测期间在路由器上复查

```sh
# 1) 绑定数是否增长
cat /sys/kernel/debug/hnat/hnat_stats

# 2) 是否有该客户端的绑定表项（把 <MAC> 换成 assoclist 中的客户端 MAC）
grep -i '<MAC>' /sys/kernel/debug/hnat/all_entry | grep 'state=BIND'

# 3) 表项的 bytes/packets 是否在增长（间隔 2 秒对比）
grep -i '<客户端IP>' /sys/kernel/debug/hnat/all_entry
sleep 2
grep -i '<客户端IP>' /sys/kernel/debug/hnat/all_entry

# 4) 确认 WiFi 接口仍注册
cat /sys/kernel/debug/hnat/whnat_interface
```

**通过标准（全部满足）**

- `BIND_PPE0` 比基线增加；
- 出现客户端 IP 对应的 `state=BIND` 表项，`type` 为 `IPV4_HNAPT` 或 `IPV6_5T_ROUTE`；
- 两次快照的 `bytes`/`packets` 持续增长；
- 同一时间路由器 CPU 的 softirq/ksoftirqd 占用较低（说明数据面没有全部压在 CPU 上）。

**未通过特征**

- 持续大流量下 `BIND_PPE0` 仍为 0；
- 客户端表项一直是 `UNBIND` 或 `bytes=0`；
- CPU 单核被 softirq 占满、吞吐上不去。

### 5.5 A/B 对照（可选，仅用于排障）

> 会临时影响全部转发加速，测完必须恢复。

```sh
# 关闭新连接绑定
echo 0 > /sys/kernel/debug/hnat/hook_toggle
cat /sys/kernel/debug/hnat/hook_toggle     # 应为 disabled

# 重复 5.3~5.4 的测速与快照，观察 CPU 占用/吞吐变化

# 恢复
echo 1 > /sys/kernel/debug/hnat/hook_toggle
cat /sys/kernel/debug/hnat/hook_toggle     # 应为 enabled
```

注意：已经绑定的旧表项不会立即消失，会按老化时间逐步释放；A/B 结果以新连接为准。

---

## 6. 判断标准总表

| 层级 | 检查项 | 正常 | 未启用 / 异常 |
| --- | --- | --- | --- |
| 配置 | TurboACC `fastpath` | `mediatek_hnat` | `disabled`、`flow_offloading`、`fast_classifier` 等 |
| 配置 | `WHNAT=1` | 三个 dat 文件均为 1 | 任一为 0 或缺失 |
| 接口 | `whnat_interface` | 含 `ra0`、`rax0` | 空 / 缺少 WiFi 接口 |
| 接口 | `external_interface` | 含 `ra0`、`rax0` | 缺少 WiFi 接口 |
| 钩子 | `hook_toggle` | `enabled` | `disabled` |
| 驱动 | `PPE0/PPE1 hwnat start` | 两条都存在 | 缺失 |
| 驱动 | `whnat_en` | `1` | `0` |
| WARP | `WED_VERSION` | 2.x | 文件不存在 / 全 0 |
| WARP | `WO MCU status` | `Alive` | 非 Alive / 报错 |
| 表项 | `BIND_PPE0` | 有流量时 > 0 且增长 | 持续为 0 |
| 表项 | BIND 条目 `bytes/packets` | 持续增长 | 长期为 0 |
| 压测 | CPU softirq | 低 | 单核 100% softirq |
| LuCI | FastPath Engine | `MediaTek HNAT` | 带 `Disabled` 后缀或为空 |

---

## 7. 常见失败原因与排查方向

1. **TurboACC 被切到别的引擎**：`fastpath` 不是 `mediatek_hnat`（如 `flow_offloading`、`fast_classifier`、`shortcut_fe_cm`），MTK HNAT 不会工作。改成 `MediaTek HNAT` 并重启 `turboacc`。
2. **`hook_toggle` 为 disabled**：可能是手动 `echo 0`、脚本异常或 `turboacc` 未正常启动。执行 `/etc/init.d/turboacc restart` 后复查。
3. **`WHNAT=0`**：无线 profile 未开启 HNAT，表现为 TurboACC 显示 `Wireless HNAT Disabled`。检查 `/etc/wireless/mediatek/*.dat`；修改前先备份，改后重启 WiFi。
4. **`whnat_interface` 为空**：WiFi 接口未注册到 HNAT。多为 `mt_wifi` 初始化失败、`whnat_en=0`、或驱动未带 WHNAT 支持；看 `dmesg | grep -iE 'whnat|ppe_dev_register'`。
5. **WED/WO 异常**：`WED_VERSION` 缺失、`WO MCU status` 非 Alive，常见于固件文件缺失（`7981_WOCPU0_RAM_CODE_release.bin`）、`mtk_warp` 未加载或加载顺序错误。
6. **绑定阈值为 30 pps**：低速流量不会绑定。用持续大流量测试，不要用 ping 或打开网页判断。
7. **测速对象选错**：测路由器本身（LuCI、SSH、路由器上的 curl）不会经过转发路径，不会产生 HNAT 表项；必须从 LAN/WiFi 客户端访问 WAN。
8. **只有 IPv6 表项**：当前网络可能以 IPv6 为主，`IPV6_5T_ROUTE` 同样算硬件加速；不要因为没有 `IPV4_HNAPT` 就判定失败。
9. **表项老化快**：停止流量后 BIND 条目会很快消失，必须在压测过程中查看。
10. **软件流分载冲突**：本机 `firewall.flow_offloading=0` 是正常的；TurboACC 对 mt798x 默认禁用软件 flow offloading。若被手动开启，会与 HNAT 争夺路径，建议关闭。
11. **命令工具不适用**：MTK 闭源驱动不支持 nl80211，`iw dev ...` 会报 `nl80211 not found`，这是正常的；请用 `iwinfo`、`iwpriv` 或 LuCI 查看客户端。
12. **PPE1 为 0**：当前拓扑流量集中在 PPE0，属正常，不是故障。

---

## 8. 启用 / 恢复方法

### 8.1 LuCI

1. **网络 → TurboACC**；
2. Fastpath engine 选择 **MediaTek HNAT**；
3. 勾选 **Enable ethernet HNAT**、**Enable ethernet IPv6 HNAT**；
4. 保存并应用，等待 `turboacc` 重启完成；
5. 按第 1 节命令复查 `getFastPathStat`、`hook_toggle`、`whnat_interface`。

### 8.2 命令行

```sh
uci set turboacc.config.fastpath='mediatek_hnat'
uci set turboacc.config.fastpath_mh_eth_hnat='1'
uci set turboacc.config.fastpath_mh_eth_hnat_v6='1'
uci commit turboacc
/etc/init.d/turboacc restart

# 复查
ubus call luci.turboacc getFastPathStat
cat /sys/kernel/debug/hnat/hook_toggle
cat /sys/kernel/debug/hnat/whnat_interface
```

`fastpath_mh_eth_hnat_ppenum` 修改后需要重启设备生效。

---

## 9. 一键自检脚本（在路由器上执行）

```sh
#!/bin/sh
echo "== FastPath =="
ubus call luci.turboacc getFastPathStat
echo "== PPE =="
ubus call luci.turboacc getMTKPPEStat
echo "== hook =="
cat /sys/kernel/debug/hnat/hook_toggle
echo "== WHNAT profile =="
grep -H 'WHNAT' /etc/wireless/mediatek/*.dat
echo "== WHNAT interfaces =="
cat /sys/kernel/debug/hnat/whnat_interface
echo "== WED =="
head -3 /proc/warp_ctrl/warp0/wed
echo "== WO =="
grep -m1 'WO MCU status' /proc/warp_ctrl/warp0/wo
echo "== BIND entries =="
grep -c 'state=BIND' /sys/kernel/debug/hnat/all_entry
echo "== WiFi stations =="
iwinfo ra0 assoclist; iwinfo rax0 assoclist
```

**判读**

- FastPath 为 `MediaTek HNAT`、hook 为 `enabled`、WHNAT 全为 1、接口含 ra0/rax0、WO 为 Alive → 基础链路正常；
- 有无线客户端时 `BIND entries > 0` 且在压测中增长 → WiFi 硬件加速已实际生效；
- 无无线客户端时只能证明「已就绪」，不能证明「已实际卸载」，需按第 5 节补做动态验证。

---

## 10. 最终判定口诀

1. **看引擎**：TurboACC FastPath = `MediaTek HNAT`；
2. **看开关**：`hook_toggle=enabled`，`WHNAT=1`；
3. **看注册**：`whnat_interface` 含 `ra0`/`rax0`；
4. **看驱动**：dmesg 有 `PPE hwnat start`、`WHNAT support list`、`create wed ok`，`WO MCU Alive`；
5. **看表项**：有 WiFi 客户端持续流量时出现 `state=BIND`，且 `bytes/packets` 持续增长；
6. **看 CPU**：高速转发时 CPU softirq 不饱和。

前 4 条决定「是否启用」，后 2 条决定「是否真正生效」。
