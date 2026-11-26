# TSMate · 组网助手

Tailscale 组网 / 网络优化管理的 iOS 客户端界面复刻版（原生 Swift + SwiftUI）。

- 显示名：**组网助手**
- Bundle ID：`com.niugit.tsmate`
- 最低系统：**iOS 16.0**
- 目标设备：iOS 16.1 + TrollStore（巨魔）免证书安装
- 配色：主蓝 `#1B6EF3` / 强调青 `#00C2A8` / 墨黑 `#0B0B0C`

## 一期范围

本期为 **UI 复刻外壳**：完整还原截图中的全部模块，数据取自截图真实值写死。

| 模块 | 说明 |
| --- | --- |
| 顶部栏 | 汉堡菜单、模式下拉（强制直连）、`2/5在线`、TS 头像、退出 |
| 四张状态卡 | 组网速率 / 网络优化 / 启动 Tailscale / SD-WAN |
| 我的设备 | 新设备自动入网、IP 隐藏两个开关 + 5 台设备列表（设备 / IP / 状态） |
| 策略卡 | 直连达标（5ms ≤ 40ms），超时断开重连改走国内直连 |
| 模式四按钮 | P2P 直连 / 中继优先 / 强制直连 / 子网路由，单选高亮并写日志 |
| 运行日志 | 黑底控制台，4 条种子日志 + 定时追加带时间戳的模拟行 |

## 二期（Tailscale 真集成）

`TSMate/Services/TailscaleService.swift` 定义了协议 `TailscaleServicing`，
一期由 `MockTailscaleService` 提供写死数据；二期替换为 LocalAPI 客户端：

- `GET  /api/v2/status`   → 连接状态、出口节点、延迟
- `GET  /api/v2/peer`     → 设备列表
- `POST /api/v2/preferences` → 模式 / 开关落地

API Key 在 `SettingsStore` 中配置（Tailscale 客户端「设置 → 偏好设置 → 运营控制」生成）。

## 构建

本仓库不提交 `.xcodeproj`，改用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project TSMate.xcodeproj -scheme TSMate -sdk iphoneos \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 会自动完成：生成工程 → 编译 → `ldid` 伪签 → 打包 `.ipa` 与 `.tipc` → 上传 Artifact。

## 安装（TrollStore）

1. 在 iOS 16.1 设备上安装 TrollStore 2（TrollInstallerX / TrollStar 方式）。
2. 从本仓库 Actions 的 Artifacts 下载 `TSMate-1.0.0.ipa`。
3. 用 TrollStore 打开该 IPA 安装即可（TrollStore 会用 CoreTrust 证书重签，无需 Apple 开发者证书）。

## License

MIT
