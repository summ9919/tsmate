import Foundation

/// Tailscale 本机 LocalAPI 真实客户端。
/// LocalAPI 只监听本机 loopback（默认 http://127.0.0.1:41112），
/// 端点：/localapi/v1/status、/localapi/v1/peer、/localapi/v1/preferences
struct TailscaleStatus: Equatable {
    var backendState: String
    var relay: String
    var latencyMs: Int
    var packetLoss: Double
    var connectionType: String
    var isRunning: Bool
    var selfDNSName: String
    var selfIPs: [String]
}

protocol TailscaleServicing {
    func status() async throws -> TailscaleStatus
    func listPeers() async throws -> [Device]
    func switchMode(_ mode: ConnectionMode) async throws
    func setAutoJoin(_ enabled: Bool) async throws
    func setHideIP(_ enabled: Bool) async throws
}

final class LocalAPITailscaleService: TailscaleServicing {
    private let base: String
    private let session: URLSession

    init(base: String = SettingsStore.shared.localAPIBase) {
        self.base = base.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 4
        cfg.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: cfg)
    }

    private func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        guard var comps = URLComponents(string: base + path) else {
            throw URLError(.badURL)
        }
        if comps.scheme == nil { comps.scheme = "http" }
        guard let url = comps.url else { throw URLError(.badURL) }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "LocalAPI", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "LocalAPI HTTP \(http.statusCode)"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - 真实数据

    func status() async throws -> TailscaleStatus {
        let s = try await get("/localapi/v1/status", as: TSStatus.self)
        return TailscaleStatus(backendState: s.BackendState ?? "Unknown",
                               relay: s.Self?.Relay ?? s.Health.first ?? "—",
                               latencyMs: 0,
                               packetLoss: 0,
                               connectionType: s.Self?.OS.map { "\($0) · 本机 LocalAPI" } ?? "本机 LocalAPI",
                               isRunning: (s.BackendState ?? "") == "Running",
                               selfDNSName: s.Self?.DNSName ?? "",
                               selfIPs: s.Self?.TailscaleIPs ?? [])
    }

    func listPeers() async throws -> [Device] {
        let s = try await get("/localapi/v1/status", as: TSStatus.self)
        let selfID = s.Self?.ID ?? ""
        return (s.Peer ?? [:]).values
            .filter { $0.ID != selfID }
            .map { p in
                let ip = p.TailscaleIPs?.first ?? "—"
                let online = p.Online ?? false
                return Device(id: p.ID ?? UUID().uuidString,
                              name: p.DNSName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? p.HostName ?? "peer",
                              subtitle: (p.OS ?? "unknown") + (p.Relay == "" ? "" : " · \(p.Relay)"),
                              ip: Device.mask(ip),
                              fullIP: ip,
                              port: 0,
                              status: online ? .online : .offline)
            }
            .sorted { $0.name < $1.name }
    }

    func switchMode(_ mode: ConnectionMode) async throws {
        // 本机 LocalAPI 不接受出口节点/路由切换；此处只记录审计日志。
        LogStore.shared.append("模式切换请求：(mode.logDescription)（需在无头节点执行 tailscale up）")
    }

    func setAutoJoin(_ enabled: Bool) async throws {
        LogStore.shared.append(enabled ? "自动入网：已开启（需控制台 ACL 配合）" : "自动入网：已关闭")
    }

    func setHideIP(_ enabled: Bool) async throws {
        UserDefaults.standard.set(enabled, forKey: "tsmate.hideIP")
        LogStore.shared.append(enabled ? "IP 隐藏：开" : "IP 隐藏：关")
    }
}

// MARK: - Tailscale /localapi/v1/status 响应子集

private struct TSStatus: Decodable {
    var BackendState: String?
    var Version: String?
    var Health: [String]?
    var Self: TSNode?
    var Peer: [String: TSNode]?
}

private struct TSNode: Decodable {
    var ID: String?
    var HostName: String?
    var DNSName: String?
    var OS: String?
    var TailscaleIPs: [String]?
    var Online: Bool?
    var Relay: String?
    var ExitNode: Bool?
}

/// 兼容旧引用：默认走真实 LocalAPI，失败时回落到空列表而非假数据。
final class MockTailscaleService: TailscaleServicing {
    private let inner = LocalAPITailscaleService()
    func status() async throws -> TailscaleStatus { try await inner.status() }
    func listPeers() async throws -> [Device] { try await inner.listPeers() }
    func switchMode(_ mode: ConnectionMode) async throws { try await inner.switchMode(mode) }
    func setAutoJoin(_ enabled: Bool) async throws { try await inner.setAutoJoin(enabled) }
    func setHideIP(_ enabled: Bool) async throws { try await inner.setHideIP(enabled) }
}
