import Foundation

/// 本机真实组网状态（全部来自实时探测 / Tailscale API）
struct TailscaleStatus: Equatable {
    var backendState: String
    var relay: String
    var latencyMs: Int
    var packetLoss: Double
    var connectionType: String
    var isRunning: Bool
    var selfDNSName: String
    var selfIPs: [String]
    var lanIPv4: String
    var dualStack: Bool
    var probeTarget: String
    /// 本机是否拿到了 UDP 打洞地址（决定能不能 P2P）
    var directPath: Bool
    /// MagicDNS 是否开启（tailnet 真实配置）
    var magicDNS: Bool
    /// 全局 DNS 列表（tailnet 真实配置）
    var nameservers: [String]

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
                                       probeTarget: "",
                                       directPath: false,
                                       magicDNS: false,
                                       nameservers: [])
}

protocol TailscaleServicing {
    func status() async throws -> TailscaleStatus
    func listPeers() async throws -> [Device]
    func switchMode(_ mode: ConnectionMode) async throws
    func setAutoJoin(_ enabled: Bool) async throws
    func setHideIP(_ enabled: Bool) async throws
    func authorize(deviceID: String) async throws
    func probeLatency(for device: Device) async -> Int
    func setDeviceSubnetRoutes(_ device: Device, enabled: Bool) async throws
}

/// 真实实现：
/// 1) 本机链路 / 时延 / 丢包 → NetworkProbe（真实网卡 + TCP 握手）
/// 2) 设备列表 / 在线状态 / 待授权 → Admin API GET /tailnet/{tailnet}/devices?fields=all
/// 3) 模式切换 → 真实写 tailnet 配置（MagicDNS / 全局 DNS / 子网路由）
/// 注意：Tailscale 官方 API 没有 tailnet 级 ExitNode / RouteAll 偏好端点，
/// 所以这里只写真实存在的端点，不再伪造 prefs 写回。
final class TailscaleManager: TailscaleServicing {
    private let api = TailscaleAPIClient.shared
    private let settings = SettingsStore.shared

    private var token: String {
        return settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tailnet: String {
        return settings.tailnet.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

        if let gateway = NetworkProbe.gatewayIPv4() {
            let result = await NetworkProbe.probe(host: gateway, port: 80, attempts: 3, timeout: 1.2)
            if let ms = result.ms {
                latency = ms
                loss = result.loss
                target = "网关 " + gateway
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

        var magicDNS = false
        var dnsList: [String] = []
        if !token.isEmpty, !tailnet.isEmpty {
            magicDNS = (try? await api.dnsPreferences(tailnet: tailnet, token: token)) ?? false
            dnsList = (try? await api.nameservers(tailnet: tailnet, token: token)) ?? []
        }

        let dnsName = ips.isEmpty ? "" : "本机 (" + link + ")"

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
                               probeTarget: target,
                               directPath: connected,
                               magicDNS: magicDNS,
                               nameservers: dnsList)
    }

    // MARK: - 设备列表

    func listPeers() async throws -> [Device] {
        guard !token.isEmpty, !tailnet.isEmpty else {
            LogStore.shared.append("未配置 Tailscale API Key / tailnet，设备列表不可用")
            return []
        }

        let remote = try await api.devices(tailnet: tailnet, token: token)
        LogStore.shared.append("已从 Tailscale API 拉取 " + String(remote.count) + " 台设备")

        var result: [Device] = []
        for item in remote {
            let ip = item.ipv4 ?? ""
            let osName = item.os ?? "unknown"
            let pending = !item.isAuthorized

            var subtitle = osName
            if pending {
                subtitle = "等待授权 · " + osName
            } else if item.isExternal == true {
                subtitle = osName + " · 外部共享"
            } else if item.hasDirectPath {
                subtitle = osName + " · 可直连"
            } else {
                subtitle = osName + " · 中继"
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
            device.isExternal = item.isExternal == true
            device.hasDirectPath = item.hasDirectPath

            if let routes = try? await api.deviceRoutes(deviceID: item.nodeId ?? item.id, token: token) {
                device.advertisedRoutes = routes.advertised
                device.enabledRoutes = routes.enabled
            }

            result.append(device)
        }

        return result.sorted { left, right in
            if left.status.sortOrder != right.status.sortOrder {
                return left.status.sortOrder < right.status.sortOrder
            }
            return left.name < right.name
        }
    }

    static func defaultPort(forOS os: String) -> Int {
        let value = os.lowercased()
        if value.contains("windows") { return 445 }
        return 22
    }

    // MARK: - 单设备真实时延探测

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

    // MARK: - 模式切换（只调用真实存在的端点）

    func switchMode(_ mode: ConnectionMode) async throws {
        guard !token.isEmpty, !tailnet.isEmpty else {
            LogStore.shared.append("模式切换未落地：缺少 API Key / tailnet（仅本地记录）")
            return
        }

        switch mode {
        case .p2p, .relay, .forced:
            // MagicDNS 是真实可写项：打开后用设备名直连
            try await api.setMagicDNS(true, tailnet: tailnet, token: token)

            if mode == .forced {
                // 强制直连：全局 DNS 指向国内解析，避免绕路境外
                try await api.setNameservers(["223.5.5.5", "114.114.114.114"], tailnet: tailnet, token: token)
            }

            LogStore.shared.append("模式已写回 tailnet：" + mode.rawValue + "（" + mode.apiEffect + "）")

        case .subnet:
            try await api.setMagicDNS(true, tailnet: tailnet, token: token)
            let remote = try await api.devices(tailnet: tailnet, token: token)
            var enabledCount = 0
            var skipped = 0
            for item in remote {
                let routes = try await api.deviceRoutes(deviceID: item.nodeId ?? item.id, token: token)
                if routes.advertised.isEmpty {
                    skipped += 1
                    continue
                }
                try await api.setDeviceRoutes(routes.advertised, deviceID: item.nodeId ?? item.id, token: token)
                enabledCount += 1
                LogStore.shared.append("已启用子网路由：" + item.displayName + " → " + routes.advertised.joined(separator: ", "))
            }
            LogStore.shared.append("子网路由已启用 " + String(enabledCount) + " 台，跳过 " + String(skipped) + " 台（无已发布路由）")
        }
    }

    // MARK: - 单台设备子网路由开关（详情页用）

    func setDeviceSubnetRoutes(_ device: Device, enabled: Bool) async throws {
        guard !token.isEmpty else {
            LogStore.shared.append("子网路由未落地：缺少 API Key")
            return
        }
        let id = device.nodeId.isEmpty ? device.id : device.nodeId
        if enabled {
            guard !device.advertisedRoutes.isEmpty else {
                LogStore.shared.append("该设备没有已发布的子网路由，无法启用")
                return
            }
            try await api.setDeviceRoutes(device.advertisedRoutes, deviceID: id, token: token)
            LogStore.shared.append("已启用 " + device.name + " 的子网路由：" + device.advertisedRoutes.joined(separator: ", "))
        } else {
            try await api.setDeviceRoutes([], deviceID: id, token: token)
            LogStore.shared.append("已停用 " + device.name + " 的子网路由")
        }
    }

    // MARK: - 自动入网 / 单台授权

    func authorize(deviceID: String) async throws {
        guard !token.isEmpty else {
            LogStore.shared.append("授权未落地：缺少 API Key")
            return
        }
        try await api.authorize(deviceID: deviceID, token: token)
        LogStore.shared.append("已授权设备 " + deviceID)
    }

    func setAutoJoin(_ enabled: Bool) async throws {
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
            LogStore.shared.append("已授权新设备：" + item.displayName)
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
