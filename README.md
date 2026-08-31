# MSG1500 X.00 · ImmortalWrt 21.02 自动编译

> RAISECOM MSG1500 X.00（别名 Nokia A-040W-Q）· MT7621A + MT7615 · GitHub Actions 云编译
> 底座 **ImmortalWrt openwrt-21.02**（内核 5.4，冻结分支，不受上游 rebase 影响）

## 需求实现清单

| 需求 | 实现方式 |
|---|---|
| ImmortalWrt openwrt-21.02 底座 | `git clone -b openwrt-21.02 immortalwrt/immortalwrt` |
| helloworld master 源 | `feeds.conf.default` 追加 `src-git helloworld .../fw876/helloworld.git;master` |
| MSG1500 X.00 机型 | 设备名 `raisecom_msg1500-x-00`（21.02 原生支持，NAND 128M） |
| MT7615 闭源驱动 | 从 `coolsnowwolf/lede` 固定 commit `e698151`（2023-04-02）提取 `package/lean/mt`，并把设备 `DEVICE_PACKAGES` 里的 `kmod-mt7615e` 换成 `kmod-mt7615d + luci-app-mtwifi` |
| 剔除所有 rust | 物理删除 helloworld 里的 `shadowsocks-rust` / `dns2socks-rust` / `shadow-tls` 三个包，配置里双保险关闭，编译前校验兜底 |
| 升级 golang | 用 `openwrt/packages master` 的 `lang/golang`（**Go 1.27**）覆盖 21.02 feed 自带的 1.19 |
| luci-app-ngrokc | immortalwrt 21.02 luci/packages feed 原生有，直接勾选 |
| luci-app-frpc | immortalwrt 21.02 原生有（frp 0.51.2，Go 编译，兼容新 golang） |

## ⚠️ 一个重要事实修正（比之前调研更深入的结论）

**ImmortalWrt openwrt-21.02 并不自带 mt7615d 闭源驱动**。主树 `package/kernel`（42 个目录）和
immortalwrt/packages feed 的 kernel 目录里都只有开源 mt76，luci feed 里也没有 luci-app-mtwifi。
之前"21.02 自带 kmod-mt7615d"的说法不对，抱歉 🐾

全网唯一维护 MT7615 闭源驱动的仍然是 coolsnowwolf/lede（`package/lean/mt/`）。本项目绕开 lede
不稳定的 master（正迁移内核 6.18 + 切 APK），采用 **"冻结底座 + 从 lede 借驱动"** 的组合：

```
ImmortalWrt 21.02（稳定底座）
  + helloworld master（feed）
  + openwrt/packages master 的 golang 1.27（覆盖 1.19）
  + lede@e698151 的 package/lean/mt（闭源驱动，与内核 5.4 同代）
  - 全部 rust 包
```

锚点 `e698151`（2023-04-02）的选择理由：包含 mt7615d DBDC 的 client 模式 / apcli 网桥 /
dbdc 信道修复（**MSG1500 X.00 正是 MT7615 DBDC 单芯片双频**，这些修复直接相关）；该时点
lede ramips 同时支持内核 5.4/5.10，驱动与 ImmortalWrt 21.02 的 5.4 内核匹配。

## 使用方法

1. 在 GitHub 新建仓库（如 `msg1500-actions`），把本目录全部内容推上去：

   ```bash
   cd msg1500-actions
   git init && git add . && git commit -m "MSG1500 X.00 iwrt 21.02 builder"
   git remote add origin git@github.com:<你的用户名>/msg1500-actions.git
   git push -u origin main
   ```

2. 仓库 **Actions** 页 → `Build MSG1500 X.00 (ImmortalWrt 21.02)` → **Run workflow**
   - `wifi_driver` 选 `mt7615d`（闭源，默认）或 `mt7615e`（开源兜底）
3. 首次编译约 1.5～2.5 小时；完成后在 Artifacts 下载 `msg1500-x00-iwrt2102-fw`
   （sysupgrade.bin + sha256sums）
4. 失败时 Artifacts 里会有 `msg1500-x00-build-logs`（logs + .config）用于定位

刷机：原厂/ Breed 下刷 sysupgrade.bin；MSG1500 为 NAND 机型，**保留配置跨大版本升级有风险，
建议首次不带配置刷入**。

## 目录结构

```
├── .github/workflows/build.yml   # 主 workflow（磁盘清理→依赖→拉源→改造→编译→上传）
├── config/msg1500-x00.config     # 种子配置（defconfig 自动补全）
└── scripts/
    ├── 10-add-feeds.sh           # 追加 helloworld master feed，feeds update
    ├── 20-golang-upgrade.sh      # golang 1.19 → 1.27（openwrt/packages master 覆盖）
    ├── 30-remove-rust.sh         # 物理剔除 3 个 rust 包（缺一即报错退出）
    └── 40-mt7615d.sh             # 从 lede@e698151 提取闭源驱动 + 替换设备驱动包
```

脚本顺序刻意安排为 **update → golang 覆盖 → 删 rust → 注入驱动 → feeds install -a → defconfig**，
让 install 与 defconfig 看到的都是"改造后"的 feed。

## 关键技术点

- **golang 覆盖的兼容性**：openwrt/packages master 的新版 lang/golang 带 `golang` 虚拟包
  （`HOST_BUILD_DEPENDS:=golang1.27/host`），所以 21.02 feed 里老包（frp 等）的
  `PKG_BUILD_DEPENDS:=golang/host` 写法继续可用；`golang-package.mk` 保留了
  `GoBinPackage`/`GO_PKG` 等老 API。xray-core 26.x 的 go.mod 要求 go ≥ 1.26 且
  `GOTOOLCHAIN=local` 禁止自动下载工具链，1.19/1.21/1.23 都不够，必须上 1.27。
- **rust 判定**：不只按目录名，还 grep Makefile 里的 `rust-package.mk` / `rust/host` /
  `Cargo.toml` 标记（`shadow-tls` 就是靠这个抓出来的——它名字里没有 rust）。
  `luci-app-ssr-plus` 本体只在可选项里提到 rust 包名，有白名单保护不会被误删。
- **闭源驱动替换点**：`target/linux/ramips/image/mt7621.mk` 中
  `define Device/raisecom_msg1500-x-00` 块内一行 sed 替换，其余机型不受影响。

## 风险与回退

| 风险 | 概率 | 回退 |
|---|---|---|
| mt7615d（lede 2023 版）在 iwrt 21.02 内核 5.4 上编译失败 | 中 | workflow 里选 `mt7615e` 开源模式重跑（其余逻辑不变） |
| golang 1.27 与 21.02 构建系统 / 老包不兼容 | 低-中 | `env.GOLANG_REF` 改为 `openwrt-24.10`（Go 1.23）——但需同时把 helloworld 的 xray-core 降级（1.23 编不了 xray 26.x） |
| helloworld master 后续跟进新内核 API，某包在 5.4 上编译失败 | 随时间上升 | 定位失败包后在该包 Makefile 钉旧版本号，或 feeds.conf 里把 helloworld 换成其旧 tag |
| ubuntu-22.04 host gcc 11 编内核 5.4 报编译警告/错误 | 低 | job 上加 `container: debian:11` |

已知取舍：21.02 已 EOL（无安全更新）；helloworld master 跟最新，个别包偶发翻车属正常，
失败日志会随 Artifacts 一起上传。

---
🐾 阿宝定制 · 2026-08-31 · 数据来源：GitHub API 实时核查（immortalwrt/lede/helloworld/openwrt-packages 四仓库）
