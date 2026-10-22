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

echo "[DIY-P2] done"

