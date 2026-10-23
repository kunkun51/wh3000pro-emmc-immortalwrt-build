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

# ===== 拷贝自定义文件（files/ 下含 WiFi、LED、root密码、fancontrol 的 uci-defaults，由构建系统覆盖进固件根文件系统）=====
# 注意：必须放到编译根目录的 files/ 下，OpenWrt 才会原样打包进固件
rm -rf files
cp -r "$GITHUB_WORKSPACE/files" .
chmod +x files/etc/uci-defaults/*

echo "[DIY-P2] done"
