import Foundation

/// 本机真实组网状态（全部来自实时探测 / Tailscale API，不再写死）
struct TailscaleStatus: Equatable {
    /// 隧道状态：Running / Stopped
    var backendState: String
    /// 对端链路："" 表示直连，DERP 名表示中继
    var relay: String
    /// 实测时延（毫秒），0 表示尚未测得
    var latencyMs: Int
    /// 实测丢包率 0...1
    var packetLoss: Double
    /// Wi-Fi / 蜂窝数据 / 有线
    var connectionType: String
    /// 隧道是否已建立
    var isRunning: Bool
    /// 本机 Tailscale DNS 名
    var selfDNSName: String
    /// 本机 Tailscale 地址（IPv4 / IPv6）
    var selfIPs: [String]
    /// 本机局域网地址
    var lanIPv4: String
    /// 双栈（IPv4 + IPv6 同时可用）
    var dualStack: Bool
    /// 实测目标说明
    var probeTarget: String

    static let empty = TailscaleStatus(backendState: "未知",
                                       relay: "",
                                       latencyMs: 0,
                                       packetLoss: 0,
                                       connectionType: "未知",
                                       isRunning: false,
                                       selfDNSName: "",
                                       selfIPs: [],
                                       lanIPv4: "",
                                       dualStack: false,
                                       probeTarget: "")
}

protocol TailscaleServicing {
    func status() async throws -> TailscaleStatus
    func listPeers() async throws -> [Device]
    func switchMode(_ mode: ConnectionMode) async throws
    func setAutoJoin(_ enabled: Bool) async throws
    func setHideIP(_ enabled: Bool) async throws
    func authorize(deviceID: String) async throws
    func probeLatency(for device: Device) async -> Int
}

/// 真实实现：
/// 1) 本机隧道 / 链路 / 时延 / 丢包 → NetworkProbe（真实网卡 + TCP 握手）
/// 2) 设备列表 / 待授权设备 / tailnet 偏好 → Tailscale Admin API
/// 3) 模式切换 → 写回 tailnet 偏好（ExitNodeID / RouteAll / WantRunning）
final class TailscaleManager: TailscaleServicing {
    private let api = TailscaleAPIClient.shared
    private let settings = SettingsStore.shared

    // MARK: - 本机状态

    func status() async throws -> TailscaleStatus {
        let link = NetworkProbe.linkTypeName()
        let tsIPv4 = NetworkProbe.tailscaleIPv4()
        let tsIPv6 = NetworkProbe.tailscaleIPv6()
        let lan = NetworkProbe.lanIPv4() ?? ""
        let connected = tsIPv4 != nil

        var latency = 0
        var loss = 0.0
        var target = ""

        // 优先测局域网网关，其次国内公网 DNS（用于判断「国内直连」质量）
        if let gateway = NetworkProbe.gatewayIPv4() {
            let result = await NetworkProbe.probe(host: gateway, port: 80, attempts: 3, timeout: 1.2)
            if let ms = result.ms {
                latency = ms
                loss = result.loss
                target = "网关 \(gateway)"
            }
        }
        if latency == 0 {
            for host in ["223.5.5.5", "114.114.114.114"] {
                let result = await NetworkProbe.probe(host: host, port: 53, attempts: 3, timeout: 1.5)
                if let ms = result.ms {
                    latency = ms
                    loss = result.loss
                    target = host
                    break
                }
            }
        }

        var ips: [String] = []
        if let value = tsIPv4 { ips.append(value) }
        if let value = tsIPv6 { ips.append(value) }

        let dnsName = ips.isEmpty ? "" : "本机 (\(link))"

        return TailscaleStatus(backendState: connected ? "Running" : "Stopped",
                               relay: "",
                               latencyMs: latency,
                               packetLoss: loss,
                               connectionType: link,
                               isRunning: connected,
                               selfDNSName: dnsName,
                               selfIPs: ips,
                               lanIPv4: lan,
                               dualStack: (tsIPv4 != nil && tsIPv6 != nil),
                               probeTarget: target)
    }

    // MARK: - 设备列表

    func listPeers() async throws -> [Device] {
        let token = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let tailnet = settings.tailnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !tailnet.isEmpty else {
            LogStore.shared.append("未配置 Tailscale API Key / tailnet，设备列表暂不可用")
            return []
        }

        let remote = try await api.devices(tailnet: tailnet, token: token)
        LogStore.shared.append("已从 Tailscale API 拉取 \(remote.count) 台设备")

        var result: [Device] = []
        for item in remote {
            let ip = item.ipv4 ?? ""
            let osName = item.os ?? "unknown"
            let pending = !item.isAuthorized

            var subtitle = osName
            if pending {
                subtitle = "等待授权 · " + osName
            } else if !item.relayName.isEmpty {
                subtitle = osName + " · 中继 " + item.relayName
            } else {
                subtitle = osName + " · 直连"
            }

            var device = Device(id: item.id,
                                name: item.displayName,
                                subtitle: subtitle,
                                ip: Device.mask(ip),
                                fullIP: ip,
                                port: TailscaleManager.defaultPort(forOS: osName),
                                status: pending ? .pending : (item.isOnline ? .online : .offline))
            device.osName = osName
            device.clientVersion = item.clientVersion ?? ""
            device.lastSeen = item.lastSeenText
            device.nodeId = item.nodeId ?? ""
            device.addresses = item.addresses ?? []
            device.isAuthorized = item.isAuthorized
            result.append(device)
        }

        let sorted = result.sorted { left, right in
            if left.status.sortOrder != right.status.sortOrder {
                return left.status.sortOrder < right.status.sortOrder
            }
            return left.name < right.name
        }
        return sorted
    }

    /// 按操作系统给出常用管理端口
    static func defaultPort(forOS os: String) -> Int {
        let value = os.lowercased()
        if value.contains("windows") { return 445 }
        return 22
    }

    // MARK: - 单设备真实时延探测

    /// 对某台设备做真实 TCP 握手探测（返回毫秒；0 表示不可达）
    func probeLatency(for device: Device) async -> Int {
        guard !device.fullIP.isEmpty else { return 0 }
        let ports: [UInt16] = [UInt16(device.port), 22, 445, 80]
        for port in ports {
            if let ms = await NetworkProbe.tcpLatency(host: device.fullIP, port: port, timeout: 1.5) {
                return ms
            }
        }
        return 0
    }

    // MARK: - 模式切换

    func switchMode(_ mode: ConnectionMode) async throws {
        let token = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let tailnet = settings.tailnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !tailnet.isEmpty else {
            LogStore.shared.append("模式切换未落地：缺少 API Key / tailnet（仅本地记录）")
            return
        }

        var prefs = try await api.prefs(tailnet: tailnet, token: token)

        switch mode {
        case .p2p:
            prefs["ExitNodeID"] = .string("")
            prefs["ExitNodeIP"] = .string("")
            prefs["RouteAll"] = .bool(false)
            prefs["WantRunning"] = .bool(true)
            prefs["AdvertiseExitNode"] = .bool(false)
        case .relay:
            prefs["ExitNodeID"] = .string("")
            prefs["ExitNodeIP"] = .string("")
            prefs["RouteAll"] = .bool(false)
            prefs["WantRunning"] = .bool(true)
            prefs["NoPortForwarding"] = .bool(true)
        case .forced:
            prefs["ExitNodeID"] = .string("")
            prefs["ExitNodeIP"] = .string("")
            prefs["RouteAll"] = .bool(false)
            prefs["WantRunning"] = .bool(true)
            prefs["ShieldsUp"] = .bool(false)
            prefs["CorpDNS"] = .bool(true)
        case .subnet:
            prefs["RouteAll"] = .bool(true)
            prefs["WantRunning"] = .bool(true)
        }

        try await api.updatePrefs(prefs, tailnet: tailnet, token: token)
        LogStore.shared.append("模式已写回 tailnet 偏好：\(mode.rawValue)（\(mode.apiEffect)）")
    }

    // MARK: - 自动入网 / 单台授权

    func authorize(deviceID: String) async throws {
        let token = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            LogStore.shared.append("授权未落地：缺少 API Key")
            return
        }
        try await api.authorize(deviceID: deviceID, token: token)
        LogStore.shared.append("已授权设备 \(deviceID)")
    }

    func setAutoJoin(_ enabled: Bool) async throws {
        let token = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let tailnet = settings.tailnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard enabled else {
            LogStore.shared.append("自动入网已关闭")
            return
        }
        guard !token.isEmpty, !tailnet.isEmpty else {
            LogStore.shared.append("自动入网未落地：缺少 API Key / tailnet")
            return
        }

        let remote = try await api.devices(tailnet: tailnet, token: token)
        var approved = 0
        for item in remote where !item.isAuthorized {
            try await api.authorize(deviceID: item.id, token: token)
            approved += 1
            LogStore.shared.append("已授权新设备：\(item.displayName)")
        }
        if approved == 0 {
            LogStore.shared.append("自动入网检查完成：没有待授权设备")
        }
    }

    // MARK: - IP 隐藏

    func setHideIP(_ enabled: Bool) async throws {
        UserDefaults.standard.set(enabled, forKey: "tsmate.hideIP")
        LogStore.shared.append(enabled ? "IP 隐藏：开（列表 IP 打码）" : "IP 隐藏：关（展示完整 Tailnet IP）")
    }
}
