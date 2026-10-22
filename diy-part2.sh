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

# ===== 设置默认 WiFi（按现有配置生成）=====
WIFI_SSID="651"
WIFI_PASSWORD="11111111"
WIFI_ENCRYPTION="psk-mixed"

mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wifi <<EOF
#!/bin/sh
. /lib/functions.sh
# 首次启动设置默认 WiFi，升级时不覆盖用户配置
[ "\$PKG_UPGRADE" = 1 ] && exit 0

# 确保无线配置已生成（OpenWrt 首次启动由 30_wifi.sh 生成，这里兜底）
[ -f /etc/config/wireless ] || wifi config 2>/dev/null

# ---- radio0 (2.4G) ----
uci -q set wireless.radio0.country='CN'
uci -q set wireless.radio0.channel='auto'
uci -q set wireless.radio0.htmode='HE40'
uci -q set wireless.radio0.cell_density='0'

# ---- radio1 (5G) ----
uci -q set wireless.radio1.country='CN'
uci -q set wireless.radio1.channel='auto'
uci -q set wireless.radio1.htmode='HE80'
uci -q set wireless.radio1.cell_density='0'

# ---- default_radio0 (2.4G AP) ----
uci -q set wireless.default_radio0.mode='ap'
uci -q set wireless.default_radio0.network='lan'
uci -q set wireless.default_radio0.ssid='${WIFI_SSID}'
uci -q set wireless.default_radio0.encryption='${WIFI_ENCRYPTION}'
uci -q set wireless.default_radio0.key='${WIFI_PASSWORD}'
uci -q set wireless.default_radio0.disabled='0'

# ---- default_radio1 (5G AP) ----
uci -q set wireless.default_radio1.mode='ap'
uci -q set wireless.default_radio1.network='lan'
uci -q set wireless.default_radio1.ssid='${WIFI_SSID}'
uci -q set wireless.default_radio1.encryption='${WIFI_ENCRYPTION}'
uci -q set wireless.default_radio1.key='${WIFI_PASSWORD}'
uci -q set wireless.default_radio1.disabled='0'

uci commit wireless
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

echo "[DIY-P2] done"

