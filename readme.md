# 华思飞 WH3000Pro eMMC · GitHub Actions 编译

## 固件默认信息

| 项目 | 值 |
| --- | --- |
| 管理地址 | `192.168.1.1`（无密码） |
| WiFi 名称 | `DIY-CPE-2.4G` / `DIY-CPE-5G` |
| WiFi 密码 | `11111111`（8 个 1） |

## 工作流说明

| 工作流文件 | 源码分支 | 说明 |
| --- | --- | --- |
| `build.yml` | ImmortalWrt 官方分支 | 适合尝鲜，WiFi 驱动跟随官方 |
| `build-237.yml` | padavanonly 237 分支 | 使用 237 大佬仓库，MTK 闭源 WiFi 驱动7.6.6.1 |
| `build-lede.yml` | coolsnowwolf/lede 分支 | LEDE 仓库编译，放弃了，没有闭源驱动 |
| `build-2512.yml` | ImmortalWrt 25.12 内核6.12.116 官方分支 | mtk闭源驱动7673 |

## 其他

- **QModem**：使用 fork 仓库，已修改部分问题
