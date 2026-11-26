# TSMate · 组网助手

iOS 上的 Tailscale 组网 / 网络优化管理助手。原生 Swift + SwiftUI，最低 iOS 16.0，无 Apple 证书，使用 TrollStore 直装（.tipc）或侧载（.ipa）。

## 一期已实现（真实功能）

| 模块 | 说明 |
| --- | --- |
| 本机状态探测 | `getifaddrs` 枚举真实网卡，识别 Wi-Fi / 蜂窝 / 有线、Tailscale IPv4（100.64/10）与 IPv6（fd7a:115c:a1e0::/48）、双栈判定 |
| 真实时延与丢包 | 对局域网网关（优先）或国内 DNS（223.5.5.5 / 114.114.114.114）做真实 TCP 握手，取中位时延与丢包率 |
| 真实设备列表 | Tailscale Admin API `GET /api/v2/tailnet/{tailnet}/devices`，显示名称 / 系统 / 客户端版本 / 最近在线 / 全部地址 |
| 真实设备时延 | 对每台在线设备的 Tailnet IP 依次尝试管理端口、22、445、80 做真实 TCP 握手 |
| 待授权设备 | 识别 `unauthorized` 设备，可单台授权；「新设备自动入网」开关会批量授权 |
| 模式写回 | 四个模式按钮会真实写回 tailnet 偏好（ExitNodeID / RouteAll / ShieldsUp / CorpDNS / NoPortForwarding / AdvertiseExitNode） |
| 策略执行 | 实测时延超过阈值（默认 40ms）立即断开重连并强制改走国内直连 |
| IP 隐藏 | 列表中 IP 掩码显示（100.116.*.*），可在设置里开关 |

## 二期（已留接口）

- 与 Tailscale 客户端 LocalAPI（Mac / Windows：`http://127.0.0.1:41112/localapi/v1/...`）互通
- 本机子网路由表与分流策略可视化
- 后台持续探测与通知

## 配置 Tailscale Admin API

1. 打开 <https://login.tailscale.com/admin/settings/keys> 创建 API Key（建议勾选 Devices:Read / Devices:Write / DNS:Read）。
2. 打开 App 右上角齿轮 → 「Tailscale 接入」，填入：
   - API Key（`tskey-…`）
   - tailnet，形如 `user@example.com`
3. 点「测试连接」确认，返回设备台数即成功。

> API Key 与 tailnet 存入 iOS Keychain，不写 UserDefaults。

## 关于 Tailscale 隧道

iOS 上 Tailscale 隧道必须由官方 App 建立，本 App 右上角电源按钮会直接跳转 Tailscale 官方 App，请在那里点击「连接」。本 App 负责真实探测、真实设备管理、待授权设备入网与 tailnet 偏好写回。

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

产物：

- `TSMate-1.0.0.tipc` —— TrollStore 直装
- `TSMate-1.0.0.ipa` —— 备用侧载

## 目录结构

```
TSMate/
├─ Models/        Device / DeviceStatus / ConnectionMode / LogEntry / StatusCard / SampleData
├─ Services/      TailscaleManager / TailscaleAPIClient / NetworkProbe / LogStore / SettingsStore / KeychainStore
├─ ViewModels/    AppModel（真实状态、刷新、策略执行、探测与授权）
├─ Views/         AppView / SettingsView / Components（TopBar、StatusCardView、DeviceListCard、DeviceDetailView、PolicyCard、ModeSelector、LogConsole）
├─ Theme/         Theme（#1B6EF3 主蓝 / #00C2A8 青 / #0B0B0C 墨黑）
└─ TSMateApp.swift
```

## 许可

仅供个人组网管理使用。Tailscale 为其各自所有者的商标。
