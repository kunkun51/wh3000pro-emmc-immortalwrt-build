#!/bin/bash
echo "[DIY-P2] start"
# 可选修改后台IP，默认192.168.1.1 --> 192.168.8.1
#sed -i 's/192.168.1.1/192.168.8.1/g' package/base-files/files/bin/config_generate
# 设置默认主题为 aurora（覆盖 bootstrap 默认）
sed -i 's/luci-theme-bootstrap/luci-theme-aurora/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

echo "update submodules"
cd $GITHUB_WORKSPACE
git submodule update --init --recursive || { echo "submodule init failed"; exit 1; }
cd -

echo "===== Copy plugin folder into package ====="
# 先清理旧的，避免文件残留
if [ -d "package/plugin" ]; then
    echo "remove old package/plugin"
    rm -rf package/plugin
fi
cp -r $GITHUB_WORKSPACE/plugin package/

# ===== 设置默认 WiFi（自动探测硬件后只改关心的字段）=====
WIFI_SSID="651"
WIFI_PASSWORD="11111111"
WIFI_ENCRYPTION="psk-mixed"

mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wifi <<'EOF'
#!/bin/sh
. /lib/functions.sh
# 首次启动设置默认 WiFi，升级时不覆盖用户配置
[ "$PKG_UPGRADE" = 1 ] && exit 0

# 若尚未生成无线配置，让系统自动探测生成（wifi detect 已在 22.03+ 移除，用 wifi config）
[ -f /etc/config/wireless ] || wifi config 2>/dev/null || wifi detect 2>/dev/null || true

# 关键：ssid / encryption / key / disabled 必须设在 wifi-iface（接口）段，不是 wifi-device（设备）段
set_wifi() {
	uci -q set wireless."$1".ssid="$WIFI_SSID"
	uci -q set wireless."$1".encryption="$WIFI_ENCRYPTION"
	uci -q set wireless."$1".key="$WIFI_PASSWORD"
	uci -q set wireless."$1".disabled='0'
}
config_load wireless
config_foreach set_wifi wifi-iface

# 设备段（wifi-device）属性：国家码/信道/htmode/频段/信号密度，按你给的配置写全
set_dev() {
	uci -q set wireless."$1".country='CN'
	uci -q set wireless."$1".channel='auto'
	uci -q set wireless."$1".cell_density='0'
	local band
	config_get band "$1" band
	case "$band" in
		5g) uci -q set wireless."$1".band='5g';  uci -q set wireless."$1".htmode='HE80' ;;
		*)  uci -q set wireless."$1".band='2g';  uci -q set wireless."$1".htmode='HE40' ;;
	esac
}
config_foreach set_dev wifi-device

uci commit wireless
wifi up 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-wifi

# ===== 设置默认 LED 配置 =====
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-led <<'EOF'
#!/bin/sh
. /lib/functions.sh
# 首次启动设置默认 LED，升级时不覆盖用户配置
[ "$PKG_UPGRADE" = 1 ] && exit 0

# 清空已有 led 段，避免重复添加
for s in $(uci -q show system 2>/dev/null | grep -oE 'system\.@led\[[0-9]+\]' | sort -u); do
	uci -q delete "$s"
done

# blue:status -> 关闭（trigger none）
cfg=$(uci -q add system led)
uci -q set system."$cfg".name='1'
uci -q set system."$cfg".sysfs='blue:status'
uci -q set system."$cfg".trigger='none'
uci -q set system."$cfg".default='0'

uci commit system
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-led

# ===== 设置默认 root 登录密码 =====
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-rootpw <<'EOF'
#!/bin/sh
# 首次启动设置 root 登录密码，升级时不覆盖用户已改的密码
[ "$PKG_UPGRADE" = 1 ] && exit 0
echo "root:101311" | chpasswd
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-rootpw

echo "[DIY-P2] done"

