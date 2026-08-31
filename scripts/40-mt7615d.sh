#!/usr/bin/env bash
# 注入 MT7615 闭源驱动（mt_wifi / kmod-mt7615d）：
#
# 背景事实（已逐一核实）：
#   - ImmortalWrt openwrt-21.02 主树 package/kernel 与 immortalwrt/packages feed
#     都【没有】mt7615d 闭源驱动（只有开源 mt76），luci feed 里也没有 luci-app-mtwifi
#   - 唯一维护闭源驱动的是 coolsnowwolf/lede，位置 package/lean/mt/
#     （drivers/{mt7615d,mt7603e,mt7612e,mt_wifi} + luci-app-mtwifi + mtk_apcli + mtkiappd）
#   - 锚点 commit e698151（2023-04-02）：
#       * 包含 mt7615d DBDC 的 client 模式 / apcli 网桥 / dbdc 信道修复
#       * 该时点 lede ramips 内核 5.10 默认 + 5.4 并行支持，
#         驱动同时兼容 5.4 / 5.10 —— 与 ImmortalWrt 21.02 的 5.4 内核匹配
#       * 避开 lede master 当前的 6.18 大迁移（不稳定根源）
#
# 动作：
#   1. sparse 拉取 lede@LEDE_PIN 的 package/lean/mt -> openwrt/package/lean/mt
#   2. 把 MSG1500 X.00 的 DEVICE_PACKAGES：
#        kmod-mt7615e kmod-mt7615-firmware  ->  kmod-mt7615d luci-app-mtwifi
set -euo pipefail
cd "$(dirname "$0")/../openwrt"
LEDE_PIN="${LEDE_PIN:-e69815120ad5d1b5e9b1aa4c98d69e6ce6e8f3b4}"

echo "[*] sparse 拉取 coolsnowwolf/lede @ ${LEDE_PIN}"
rm -rf /tmp/lede-src
git clone --depth 1 --filter=blob:none --no-checkout \
  https://github.com/coolsnowwolf/lede.git /tmp/lede-src
git -C /tmp/lede-src sparse-checkout set --cone package/lean/mt
git -C /tmp/lede-src fetch --filter=blob:none --depth 1 origin "${LEDE_PIN}"
git -C /tmp/lede-src checkout FETCH_HEAD

echo "[*] 拷贝 package/lean/mt -> openwrt/package/lean/mt"
mkdir -p package/lean
rm -rf package/lean/mt
cp -r /tmp/lede-src/package/lean/mt package/lean/mt

echo "[*] 校验闭源驱动包存在"
if ! grep -q "Package/kmod-mt7615d" package/lean/mt/drivers/mt7615d/Makefile; then
  echo "!! 未在 package/lean/mt 中找到 kmod-mt7615d，lede 布局可能已变化。现有驱动包："
  grep -h "^PKG_NAME" package/lean/mt/drivers/*/Makefile || true
  exit 1
fi

echo "[*] 替换 MSG1500 X.00 无线驱动（kmod-mt7615e -> kmod-mt7615d + luci-app-mtwifi）"
sed -i \
  '/define Device\/raisecom_msg1500-x-00/,/^endef/ s/kmod-mt7615e kmod-mt7615-firmware/kmod-mt7615d luci-app-mtwifi/' \
  target/linux/ramips/image/mt7621.mk

echo "[*] 修改后的设备定义："
sed -n '/define Device\/raisecom_msg1500-x-00/,/^endef/p' target/linux/ramips/image/mt7621.mk
