#!/usr/bin/env bash
# golang 工具链升级：
#   ImmortalWrt openwrt-21.02 的 packages feed 只带 Go 1.19，而 helloworld master
#   的 xray-core 26.x 要求 go >= 1.26，且 golang-package.mk 设定 GOTOOLCHAIN=local
#   （禁止编译期自动下载工具链），所以必须整体替换 golang。
#
# 方案：用 openwrt/packages master 的 lang/golang（Go 1.27，多版本布局）覆盖
#   feeds/packages/lang/golang。
#   - 新布局里有 "golang" 虚拟包（HOST_BUILD_DEPENDS:=golang1.27/host），
#     老包的 PKG_BUILD_DEPENDS:=golang/host 写法依然可用（frp 等不受影响）
#   - golang-package.mk 保留了 GoBinPackage / GO_PKG 等老 API，前后兼容
#   - 覆盖发生在 feeds update 之后、feeds install 之前，无需重跑 install
set -euo pipefail
cd "$(dirname "$0")/../openwrt"
GOLANG_REF="${GOLANG_REF:-master}"

echo "[*] 拉取 openwrt/packages:${GOLANG_REF} 的 lang/golang（sparse checkout）"
rm -rf /tmp/owpkgs
git clone --depth 1 --filter=blob:none --sparse -b "$GOLANG_REF" \
  https://github.com/openwrt/packages.git /tmp/owpkgs
git -C /tmp/owpkgs sparse-checkout set lang/golang

echo "[*] 覆盖 feeds/packages/lang/golang"
rm -rf feeds/packages/lang/golang
cp -r /tmp/owpkgs/lang/golang feeds/packages/lang/golang

echo "[*] 新 golang 默认版本："
grep -m1 "GO_DEFAULT_VERSION" feeds/packages/lang/golang/golang-values.mk
echo "[*] golang 升级完成"
