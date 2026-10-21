#!/bin/bash
echo "[DIY-P1] add feeds"
# QModem
sed -i '$a src-git qmodem https://github.com/kunkun51/QModem' feeds.conf.default

#echo 'src-git qmodem https://github.com/kunkun51/QModem.git;main' >> feeds.conf.default
# Argon主题 & 设置面板
sed -i '$a src-git argon https://github.com/jerrykuku/luci-theme-argon' feeds.conf.default
# sed -i '$a src-git argonconfig https://github.com/jerrykuku/luci-app-argon-config' feeds.conf.default

sed -i "$a src-git fancontrol https://github.com/JiaY-shi/fancontrol.git" >> feeds.conf.default

echo "[DIY-P1] done"
