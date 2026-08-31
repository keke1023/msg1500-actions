#!/usr/bin/env bash
# 添加 helloworld(master) feed 并更新 feeds。
# 注意：这里只做 update，不 install —— install 放到 golang 升级 / rust 剔除 /
# 闭源驱动注入全部完成后统一执行，保证 feeds install -a 看到的是"改造后"的 feed。
set -euo pipefail
cd "$(dirname "$0")/../openwrt"

HW_BRANCH="${HELLOWORLD_BRANCH:-master}"

echo "[*] 追加 helloworld(${HW_BRANCH}) 到 feeds.conf.default"
grep -q "^src-git helloworld" feeds.conf.default || \
  echo "src-git helloworld https://github.com/fw876/helloworld.git;${HW_BRANCH}" >> feeds.conf.default

./scripts/feeds update -a

echo "[*] feeds 更新完成："
grep "helloworld" feeds.conf.default
