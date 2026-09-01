#!/usr/bin/env bash
# 把 helloworld(master) 的 xray-core 从 26.5.9 降到 v24.12.31。
#
# 为什么必须降：
#   - golang 已回退到 openwrt-23.05（Go 1.21.13，旧式单版本布局）。
#   - xray-core 26.5.9 的 go.mod 要求 go >= 1.26，在 1.21 工具链下会直接拒编。
#   - v24.12.31 是 24.x 末版，go.mod 仅要求 go 1.21.4，与 23.05 golang 完美匹配，
#     且 VLESS / VMess / Trojan / 真实协议等核心功能齐全，对 MSG1500 使用无差异。
#
# 注意：本脚本在 feeds install 之前运行，直接改 feeds/helloworld/xray-core/Makefile，
#       这样 feeds install -a 建立的符号链接指向的就是降级后的源码。
set -euo pipefail
cd "$(dirname "$0")/../openwrt"

F="feeds/helloworld/xray-core/Makefile"
[ -f "$F" ] || { echo "!! 找不到 $F（helloworld 未拉取或路径变化）"; exit 1; }

OLD_VER="26.5.9"
NEW_VER="24.12.31"
OLD_HASH="2cbd37f70b246d93aa4f1f5d4261cf2e622ff78ca71a7f7a4271aa517e749025"
NEW_HASH="e3c24b561ab422785ee8b7d4a15e44db159d9aa249eb29a36ad1519c15267be0"

cur_ver=$(grep -m1 "^PKG_VERSION:=" "$F" | cut -d= -f2)
echo "[*] xray-core 当前版本：$cur_ver"

if [ "$cur_ver" = "$OLD_VER" ]; then
  sed -i "s|^PKG_VERSION:=${OLD_VER}|PKG_VERSION:=${NEW_VER}|" "$F"
  sed -i "s|^PKG_HASH:=${OLD_HASH}|PKG_HASH:=${NEW_HASH}|" "$F"
  echo "[*] 已降级 xray-core -> v${NEW_VER}"
else
  echo "!! 当前版本为 $cur_ver 而非预期的 $OLD_VER，请人工核对 helloworld 是否改了版本号"
  exit 1
fi

# 校验
new_ver=$(grep -m1 "^PKG_VERSION:=" "$F" | cut -d= -f2)
new_hash=$(grep -m1 "^PKG_HASH:=" "$F" | cut -d= -f2)
[ "$new_ver" = "$NEW_VER" ] || { echo "!! PKG_VERSION 替换失败"; exit 1; }
[ "$new_hash" = "$NEW_HASH" ] || { echo "!! PKG_HASH 替换失败"; exit 1; }
echo "[*] 校验通过：PKG_VERSION=$new_ver  PKG_HASH=$new_hash"
grep -m1 "PKG_SOURCE_URL" "$F"
