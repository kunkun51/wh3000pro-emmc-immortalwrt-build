#!/bin/bash
echo "[DIY-P2] start"
# 可选修改后台IP，默认192.168.1.1 --> 192.168.8.1
sed -i 's/192.168.1.1/192.168.8.1/g' package/base-files/files/bin/config_generate
echo "[DIY-P2] done"

