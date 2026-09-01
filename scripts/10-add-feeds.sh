#!/usr/bin/env bash
# 启用 helloworld(master) feed 并更新 feeds。
# lede 的 feeds.conf.default 里 helloworld 默认被注释掉：
#   #src-git helloworld https://github.com/fw876/helloworld.git
# 这里去掉 '#' 启用（默认即 master 分支），然后 feeds update -a。
# 注意：只做 update 不 install —— install 放到 rust 剔除之后统一执行，
# 保证 feeds install -a 看到的是"改造后"的 feed。
set -euo pipefail
cd "$(dirname "$0")/../openwrt"

HW_BRANCH="${HELLOWORLD_BRANCH:-master}"

echo "[*] 启用 helloworld(${HW_BRANCH}) feed"
# 把被注释的 helloworld 行替换为显式 master 分支
sed -i 's|^#src-git helloworld .*|src-git helloworld https://github.com/fw876/helloworld.git;'"${HW_BRANCH}"'|' feeds.conf.default
# 兜底：若上面没匹配到（格式差异），则追加
grep -q "^src-git helloworld" feeds.conf.default || \
  echo "src-git helloworld https://github.com/fw876/helloworld.git;${HW_BRANCH}" >> feeds.conf.default

./scripts/feeds update -a

echo "[*] feeds 更新完成："
grep "helloworld" feeds.conf.default
