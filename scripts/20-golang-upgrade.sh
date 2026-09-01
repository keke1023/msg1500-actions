#!/usr/bin/env bash
# golang 工具链升级：
#   ImmortalWrt openwrt-21.02 的 packages feed 只带 Go 1.19，而 helloworld 的
#   xray-core 需要更高版本的 Go，所以必须整体替换 lang/golang。
#
# 方案：用 openwrt/packages 的“旧式单版本布局”分支覆盖 feeds/packages/lang/golang。
#   - 选 openwrt-23.05（Go 1.21.13）：与 21.02 buildroot 同代，且旧式单版本布局里
#     golang/host 的写法与 21.02 feed 里的 frp / ngrokc（PKG_BUILD_DEPENDS:=golang/host）
#     完全兼容，不会出现 master 多版本布局那种 go: command not found。
#   - 因降到 23.05 golang（1.21），xray-core 需同步降到 go 1.21 兼容版 v24.12.31，
#     由 25-patch-xray.sh 完成。
#   - 覆盖发生在 feeds update 之后、feeds install 之前，无需重跑 install。
set -euo pipefail
cd "$(dirname "$0")/../openwrt"
GOLANG_REF="${GOLANG_REF:-openwrt-23.05}"

echo "[*] 拉取 openwrt/packages:${GOLANG_REF} 的 lang/golang（sparse checkout）"
rm -rf /tmp/owpkgs
git clone --depth 1 --filter=blob:none --sparse -b "$GOLANG_REF" \
  https://github.com/openwrt/packages.git /tmp/owpkgs
git -C /tmp/owpkgs sparse-checkout set lang/golang

echo "[*] 覆盖 feeds/packages/lang/golang"
rm -rf feeds/packages/lang/golang
cp -r /tmp/owpkgs/lang/golang feeds/packages/lang/golang

echo "[*] 新 golang 版本："
grep -m1 "GO_VERSION_MAJOR_MINOR" feeds/packages/lang/golang/golang-values.mk
echo "[*] golang 升级完成"
