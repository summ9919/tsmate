# TSMate · 组网助手

iOS 上的 Tailscale 组网 / 网络优化管理助手。原生 Swift + SwiftUI，最低 iOS 16.0，无 Apple 证书，使用 TrollStore 直装（.tipc）或侧载（.ipa）。

## 已实现（全部真实数据，无假数据）

| 模块 | 真实来源 |
| --- | --- |
| 本机状态探测 | `getifaddrs` 枚举真实网卡，识别 Wi-Fi / 蜂窝 / 有线、Tailscale IPv4（100.64/10）与 IPv6（fd7a:115c:a1e0::/48）、双栈判定 |
| 真实时延与丢包 | 对局域网网关（优先）或国内 DNS（223.5.5.5 / 114.114.114.114）做真实 TCP 握手，取时延与丢包率 |
| 真实设备列表 | `GET /api/v2/tailnet/{tailnet}/devices?fields=all`（必须带 fields=all，否则拿不到 lastSeen，会让所有设备看起来在线） |
| 在线判定 | 官方 API 没有 online 字段：已授权 + 非外部设备 + `lastSeen` 在 120 秒内 → 在线；否则离线；未授权 → 待授权 |
| 真实设备时延 | 对每台在线设备的 Tailnet IP 依次尝试管理端口、22、445、80 做真实 TCP 握手 |
| 待授权设备 | `POST /api/v2/device/{id}/authorized`；「新设备自动入网」开关批量授权 |
| 模式写回 | 四个模式真实调用存在的端点（见下表），不再请求不存在的 `/tailnet/{tailnet}/prefs` |
| 子网路由 | `GET/POST /api/v2/device/{id}/routes`，可逐台启用 / 停用已发布路由 |
| 策略执行 | 实测时延超过阈值（默认 40ms）自动切强制直连并写回 tailnet |
| IP 隐藏 | 列表中 IP 掩码显示（100.116.*.*），可开关 |
| 运行日志 | 全部真实事件（探测结果、API 写回、授权、失败原因）写入黑色日志台 |

### 模式按钮 → 真实 API 映射

| 模式 | 实际调用 |
| --- | --- |
| P2P 直连 | `POST /tailnet/{tailnet}/dns/preferences` → `{"magicDNS": true}` |
| 中继优先 | 同上（MagicDNS 打开，允许 DERP 兜底） |
| 强制直连 | MagicDNS 开 + `POST /tailnet/{tailnet}/dns/nameservers` → `{"dns": ["223.5.5.5","114.114.114.114"]}` |
| 子网路由 | MagicDNS 开 + 遍历设备 `POST /device/{id}/routes` 启用其 advertisedRoutes |

> Tailscale 官方 API **没有** tailnet 级 ExitNode / RouteAll / ShieldsUp / CorpDNS / NoPortForwarding 写回端点，请求 `/tailnet/{tailnet}/prefs` 会返回 `404 page not found`。1.1.1 起只写真实存在的端点。

## 配置 Tailscale Admin API

1. 打开 <https://login.tailscale.com/admin/settings/keys> 创建 API Key（建议勾选 Devices:Read / Devices:Write / DNS:Read / DNS:Write）。
2. 打开 App 右上角齿轮 → 「Tailscale 接入」，填入 API Key（`tskey-…`）与 tailnet（形如 `user@example.com`）。
3. 点「测试连接」，返回设备台数即成功。

> API Key 与 tailnet 存入 iOS Keychain，不写 UserDefaults。

## 界面入口

| 位置 | 功能 |
| --- | --- |
| 左上角 ☰ | 弹出侧栏菜单：设置 / 立即刷新 / 运行日志 / 退出 |
| 顶部「强制直连」下拉 | 切换模式（写回期间显示进度环），末尾带设置入口 |
| 顶部 TS 圆形头像 | 弹出账号面板：tailnet、隧道状态、链路、时延、丢包、MagicDNS、全局 DNS、本机 Tailscale / LAN IP、探测目标 |
| 顶部电源图标 | 跳转 Tailscale 官方 App（隧道必须由官方 App 建立） |
| 右上角齿轮 | 设置页 |
| 设备行 | 点开详情：全部地址、Node ID、直连路径、最近活跃、子网路由开关、重新探测时延、单台授权 |

## 关于 Tailscale 隧道

iOS 上 Tailscale 隧道必须由官方 App 建立（NetworkExtension 权限），本 App 右上角电源按钮直接跳转官方 App。本 App 负责真实探测、真实设备管理、待授权设备入网与 tailnet 配置写回。

## 构建

GitHub Actions 自动编译（`macos-15`）：

```bash
brew install xcodegen ldid
xcodegen generate
xcodebuild -scheme TSMate -configuration Release -sdk iphoneos build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
codesign --force --deep --sign - build/.../TSMate.app
ldid -Sscripts/entitlements.plist build/.../TSMate.app
```

产物（Actions artifact 名 `TSMate-1.1.1`）：

- `TSMate-1.1.1.tipc` —— TrollStore 直装
- `TSMate-1.1.1.ipa` —— 备用侧载

## 安装（TrollStore）

1. 从 Actions 下载 artifact `TSMate-1.1.1`。
2. 把 `TSMate-1.1.1.tipc` 传到手机（AirDrop / 微信文件传输助手 / iCloud）。
3. 用 TrollStore 打开该文件 → Install。
4. 首次启动后点右上角齿轮填入 API Key 与 tailnet，点「测试连接」验证。
5. 右上角电源按钮跳转 Tailscale 官方 App，点「连接」建立隧道。

## 目录结构

```
TSMate/
├─ Models/        Device / DeviceStatus / ConnectionMode / LogEntry / StatusCard / SampleData
├─ Services/      TailscaleManager / TailscaleAPIClient / NetworkProbe / LogStore / SettingsStore / KeychainStore
├─ ViewModels/    AppModel（真实状态、刷新、策略执行、探测、授权、模式写回）
├─ Views/         AppView / SettingsView / Components（TopBar、MenuSheet、AccountSheet、StatusCardView、DeviceListCard、DeviceDetailView、PolicyCard、ModeSelector、LogConsole）
├─ Theme/         Theme（#1B6EF3 主蓝 / #00C2A8 青 / #0B0B0C 墨黑）
└─ TSMateApp.swift
```

## 版本

| 版本 | 内容 |
| --- | --- |
| 1.1.1 | 修复模式写回 404（改用真实 DNS / 子网路由端点）、在线状态按 lastSeen 判定、☰ 菜单与 TS 头像面板可用、设备详情配子网路由开关 |
| 1.1.0 | 真实功能版：Admin API 设备列表、真实时延与丢包探测、待授权设备入网、Keychain 凭据、设置页与设备详情页 |
| 1.0.0 | 静态 UI 复刻外壳 |

## 许可

仅供个人组网管理使用。Tailscale 为其各自所有者的商标。
