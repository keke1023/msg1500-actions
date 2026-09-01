# MSG1500 X.00 · coolsnowwolf/lede 自动编译

> RAISECOM MSG1500 X.00（别名 Nokia A-040W-Q）· MT7621A + MT7615 · GitHub Actions 云编译
> 底座 **coolsnowwolf/lede @ 20251001**（内核 5.10，opkg，自带闭源驱动 + golang 1.27）

## 为什么从 ImmortalWrt 21.02 切到 lede

之前在 ImmortalWrt 21.02 上想把闭源驱动 / helloworld / 新版 golang 拼起来，踩了三个坑：
1. 21.02 **不自带** `kmod-mt7615d`，得从 lede 借驱动 → 跨代编译不稳；
2. helloworld master 的 xray 要 go ≥1.26，而把 openwrt/packages **master** 的 golang（多版本布局）
   盖进 21.02 后，老包 `frp`/`ngrokc` 的 `golang/host` 写法拿不到 host go → `go: command not found`；
3. 降级 golang 又得同步降级 xray，链路脆弱。

**lede 路线把这些坑一次性消除**：lede 自带闭源驱动、自带 golang 1.27、helloworld 只是个被注释掉的 feed。
全部组件同源演进，不再跨代拼凑。

## 需求实现清单

| 需求 | 实现方式 |
|---|---|
| 底座 coolsnowwolf/lede 稳定版 | `git clone coolsnowwolf/lede` 后 `git checkout 20251001`（日期 tag） |
| helloworld master 源 | `feeds.conf.default` 里去掉 `#src-git helloworld` 的注释启用（脚本 `10-add-feeds.sh`） |
| MSG1500 X.00 机型 | 设备 `raisecom_msg1500-x-00`（lede 原生支持）。**注意**：该设备默认 `DEVICE_PACKAGES` 不带 WiFi 驱动，故在 `.config` 显式勾选 `kmod-mt7615d` |
| MT7615 闭源驱动 | lede 自带 `package/lean/mt/{drivers/mt7615d, luci-app-mtwifi}`，直接勾选即可（无需注入） |
| 剔除所有 rust | 物理删除 helloworld 里的 `shadowsocks-rust` / `dns2socks-rust` / `shadow-tls` 三个包（脚本 `30-remove-rust.sh`） |
| golang 升级 | **无需操作**——lede 自带 golang 1.27（coolsnowwolf/packages master），已满足 xray-core 26.x 的 go ≥1.26 要求 |
| luci-app-ngrokc | lede luci feed（openwrt-23.05）原生有，直接勾选 |
| luci-app-frpc | lede packages/luсi feed 原生有（frp + luci-app-frpc），直接勾选 |

## 使用方法

1. 本目录即一个完整 GitHub Actions 项目，已推到 `keke1023/msg1500-actions`。
2. 仓库 **Actions** 页 → `Build MSG1500 X.00 (coolsnowwolf/lede)` → **Run workflow**
   - `wifi_driver` 选 `mt7615d`（闭源，默认）或 `mt7615e`（开源兜底）
3. 首次编译约 1.5～2.5 小时；完成后在 Artifacts 下载 `msg1500-x00-lede-fw`
   （sysupgrade.bin + sha256sums）
4. 失败时 Artifacts 里会有 `msg1500-x00-build-logs`（logs + .config）用于定位

刷机：原厂 / Breed 下刷 sysupgrade.bin；MSG1500 为 NAND 机型，**首次建议不带配置刷入**。

## 目录结构

```
├── .github/workflows/build.yml   # 主 workflow（拉 lede→启用 helloworld→删 rust→install→编译→上传）
├── config/msg1500-x00.config     # 种子配置（defconfig 自动补全）
└── scripts/
    ├── 10-add-feeds.sh           # 启用 helloworld master feed，feeds update
    └── 30-remove-rust.sh         # 物理剔除 3 个 rust 包（缺一即报错退出）
```

脚本顺序：**feeds update → 删 rust → feeds install -a → 写入 .config → defconfig**。

## 关键技术点

- **为什么选 `20251001` 这个 tag**：lede 用日期快照作 tag。该 tag 内核 5.10、仍是 opkg
  （未切 APK）、自带 golang 1.27、自带闭源驱动、`luci` feed 指向 `openwrt-23.05`。
  lede **master** 已迁移内核 6.18 + 切 APK，编译翻车是常态，故不跟 master。
- **golang 同源**：lede 的 golang 包（coolsnowwolf/packages master，Go 1.27）与 lede 的
  buildroot 同代演进，`frp`/`ngrokc`/`xray` 的 `golang/host` 写法都能正常产出 host go，
  不会出现 21.02 上"master golang 多版本布局 → go: command not found"的问题。
- **rust 判定**：不只按目录名，还 grep Makefile 里的 `rust-package.mk` / `rust/host` /
  `Cargo.toml`（`shadow-tls` 名字不带 rust，靠这个标记抓出）。`luci-app-ssr-plus` 本体只在
  可选项里提到 rust 包名，有白名单保护不会被误删。
- **MT7615 闭源 vs 开源**：`mt7615d` 走 MTK 官方 `mt_wifi`（性能/吞吐更好，但 lede 20251001
  的该驱动在 5.10 内核上仍有小概率编译问题）；`mt7615e` 走开源 `mt76`（最稳，4x4 吞吐与
  HWNAT 略弱）。失败优先选 `mt7615e` 重跑。

## 风险与回退

| 风险 | 概率 | 回退 |
|---|---|---|
| `kmod-mt7615d`（lede 20251001 版）在 5.10 内核上编译失败 | 低-中 | workflow 选 `mt7615e` 开源模式重跑（其余逻辑不变） |
| helloworld master 后续更进新内核 API，某包在 5.10 上失败 | 随时间上升 | 定位失败包后钉旧版本号，或把 helloworld 换成其旧 tag |
| ubuntu-22.04 host gcc 编内核 5.10 报异常 | 低 | job 加 `container: debian:11` |

已知取舍：lede master 持续演进，20251001 是"冻结稳定点"；helloworld master 跟随最新，个别
包偶发翻车属正常，失败日志会随 Artifacts 一起上传。

---
🐾 阿宝定制 · 2026-09-01 · 数据来源：GitHub API 实时核查（coolsnowwolf/lede 各 tag / helloworld / packages）
