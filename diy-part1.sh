#!/bin/bash
echo "[DIY-P1] add feeds"


# QModem
sed -i '$a src-git qmodem https://github.com/kunkun51/QModem;main' feeds.conf.default

#echo 'src-git qmodem https://github.com/kunkun51/QModem.git;main' >> feeds.conf.default
# Argon主题 & 设置面板
# sed -i '$a src-git argon https://github.com/jerrykuku/luci-theme-argon' feeds.conf.default
# sed -i '$a src-git argonconfig https://github.com/jerrykuku/luci-app-argon-config' feeds.conf.default

# Fan Control（修复：去掉 >>，使用单引号避免 $a 被展开）
#sed -i '$a src-git fancontrol https://github.com/JiaY-shi/fancontrol.git' feeds.conf.default

# Aurora 主题
#sed -i '$a src-git aurora https://github.com/eamonxg/luci-theme-aurora.git' feeds.conf.default
# Aurora Config（新增）
#sed -i '$a src-git auroraconfig https://github.com/eamonxg/luci-app-aurora-config.git' feeds.conf.default




echo "[DIY-P1] done"
