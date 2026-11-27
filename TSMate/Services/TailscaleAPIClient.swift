import Foundation

/// 通用 JSON 值：用于原样读写 Tailscale 偏好（保留服务端未知字段）
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let flag = try? container.decode(Bool.self) {
            self = .bool(flag)
            return
        }
        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }
        if let text = try? container.decode(String.self) {
            self = .string(text)
            return
        }
        if let dict = try? container.decode([String: JSONValue].self) {
            self = .object(dict)
            return
        }
        if let list = try? container.decode([JSONValue].self) {
            self = .array(list)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析的 JSON 值")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let text) = self { return text }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let flag) = self { return flag }
        return nil
    }
}

/// Tailscale Admin API 的设备对象子集。
/// 注意：真实返回里 clientConnectivity 是单个对象，不是「区域 → 连接信息」的字典；
/// 它只在 `?fields=all` 时出现，default 字段集不包含它。
struct TailscaleAPIDevice: Decodable, Identifiable {
    struct Connectivity: Decodable {
        var endpoints: [String]?
        var mappingVariesByDestIP: Bool?
        var udp: Bool?
        var ipv6: Bool?
    }

    var id: String
    var nodeId: String?
    var name: String?
    var hostName: String?
    var os: String?
    var addresses: [String]?
    var authorized: Bool?
    var clientVersion: String?
    var lastSeen: String?
    var isExternal: Bool?
    var blocksIncomingConnections: Bool?
    var clientConnectivity: Connectivity?

    enum CodingKeys: String, CodingKey {
        case id, nodeId, name, hostName, os, addresses, authorized
        case clientVersion, lastSeen, isExternal, blocksIncomingConnections
        case clientConnectivity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nodeId = (try? c.decode(String.self, forKey: .nodeId))
        name = (try? c.decode(String.self, forKey: .name))
        hostName = (try? c.decode(String.self, forKey: .hostName))
        os = (try? c.decode(String.self, forKey: .os))
        addresses = (try? c.decode([String].self, forKey: .addresses))
        authorized = (try? c.decode(Bool.self, forKey: .authorized))
        clientVersion = (try? c.decode(String.self, forKey: .clientVersion))
        lastSeen = (try? c.decode(String.self, forKey: .lastSeen))
        isExternal = (try? c.decode(Bool.self, forKey: .isExternal))
        blocksIncomingConnections = (try? c.decode(Bool.self, forKey: .blocksIncomingConnections))
        clientConnectivity = (try? c.decode(Connectivity.self, forKey: .clientConnectivity))
    }

    /// 展示名：优先主机名，其次去掉 .ts.net 后缀的 name，最后用 id
    var displayName: String {
        if let value = hostName, !value.isEmpty { return value }
        if let value = name, !value.isEmpty {
            let short = value.split(separator: ".").first.map(String.init) ?? value
            return short
        }
        return id
    }

    /// 第一个 IPv4 地址
    var ipv4: String? {
        guard let list = addresses else { return nil }
        for item in list where !item.contains(":") { return item }
        return list.first
    }

    /// 是否已授权（未授权 = 待准入）
    var isAuthorized: Bool {
        return authorized ?? true
    }

    /// 真实在线判定：官方 API 没有布尔型 online 字段，只有 lastSeen。
    /// 规则：已授权 + 非外部设备 + lastSeen 在 2 分钟内 → 在线，否则离线。
    var isOnline: Bool {
        guard isAuthorized else { return false }
        if isExternal == true { return false }
        if blocksIncomingConnections == true { return false }
        guard let seen = lastSeen, !seen.isEmpty else { return false }
        return TailscaleAPIDevice.recent(seen, within: 120)
    }

    static func recent(_ text: String, within: TimeInterval) -> Bool {
        guard let date = parseTime(text) else { return false }
        return Date().timeIntervalSince(date) <= within
    }

    /// 最近在线时间的可读形式
    var lastSeenText: String {
        guard let value = lastSeen, !value.isEmpty else { return "" }
        guard let date = TailscaleAPIDevice.parseTime(value) else { return value }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 0 { return value }
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前" }
        if seconds < 86400 { return "\(seconds / 3600) 小时前" }
        return "\(seconds / 86400) 天前"
    }

    /// 是否拿到了打洞地址（有 endpoints 才有直连可能）
    var hasDirectPath: Bool {
        if let list = clientConnectivity?.endpoints, !list.isEmpty { return true }
        return false
    }

    var supportsUDP: Bool {
        return clientConnectivity?.udp ?? false
    }

    static func parseTime(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }
}

struct TailscaleAPIError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? {
        if statusCode == 404 {
            return "Tailscale API 404：接口不存在（检查 tailnet 名称或 API Key 权限）"
        }
        return "Tailscale API \(statusCode)：\(message)"
    }
}

/// 真实的 Tailscale Admin API 客户端（Bearer = API Key）
final class TailscaleAPIClient {
    static let shared = TailscaleAPIClient()

    private let base = "https://api.tailscale.com/api/v2"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: config)
    }

    private func perform(_ method: String, path: String, token: String, body: Data?) async throws -> Data {
        guard let url = URL(string: base + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 12
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            var message = String(data: data, encoding: .utf8) ?? ""
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = obj["message"] as? String {
                message = text
            }
            throw TailscaleAPIError(statusCode: http.statusCode, message: message)
        }
        return data
    }

    private struct DeviceListResponse: Decodable {
        var devices: [TailscaleAPIDevice]?
    }

    /// 真实设备列表。
    /// 必须带 fields=all，否则默认字段集不含 lastSeen / clientConnectivity，
    /// 会让所有设备看起来都在线。
    func devices(tailnet: String, token: String) async throws -> [TailscaleAPIDevice] {
        let path = "/tailnet/\(tailnet)/devices?fields=all"
        let data = try await perform("GET", path: path, token: token, body: nil)
        let response = try JSONDecoder().decode(DeviceListResponse.self, from: data)
        return response.devices ?? []
    }

    /// 授权（放行）一台待批准的设备 —— 「新设备自动入网」的真实实现
    func authorize(deviceID: String, token: String) async throws {
        let path = "/device/\(deviceID)/authorized"
        _ = try await perform("POST", path: path, token: token, body: nil)
    }

    // MARK: - 真实可写的 tailnet 配置

    /// MagicDNS 开关（真实端点 /tailnet/{tailnet}/dns/preferences）
    func dnsPreferences(tailnet: String, token: String) async throws -> Bool {
        let path = "/tailnet/\(tailnet)/dns/preferences"
        let data = try await perform("GET", path: path, token: token, body: nil)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return obj?["magicDNS"] as? Bool ?? false
    }

    func setMagicDNS(_ enabled: Bool, tailnet: String, token: String) async throws {
        let path = "/tailnet/\(tailnet)/dns/preferences"
        let body = try JSONSerialization.data(withJSONObject: ["magicDNS": enabled])
        _ = try await perform("POST", path: path, token: token, body: body)
    }

    /// 全局 DNS 列表（真实端点 /tailnet/{tailnet}/dns/nameservers）
    func nameservers(tailnet: String, token: String) async throws -> [String] {
        let path = "/tailnet/\(tailnet)/dns/nameservers"
        let data = try await perform("GET", path: path, token: token, body: nil)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return obj?["dns"] as? [String] ?? []
    }

    func setNameservers(_ list: [String], tailnet: String, token: String) async throws {
        let path = "/tailnet/\(tailnet)/dns/nameservers"
        let body = try JSONSerialization.data(withJSONObject: ["dns": list])
        _ = try await perform("POST", path: path, token: token, body: body)
    }

    /// 某台设备已发布 / 已启用的子网路由（真实端点 /device/{deviceID}/routes）
    func deviceRoutes(deviceID: String, token: String) async throws -> (advertised: [String], enabled: [String]) {
        let path = "/device/\(deviceID)/routes"
        let data = try await perform("GET", path: path, token: token, body: nil)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let advertised = obj?["advertisedRoutes"] as? [String] ?? []
        let enabled = obj?["enabledRoutes"] as? [String] ?? []
        return (advertised, enabled)
    }

    /// 启用 / 停用某台设备的子网路由（真实端点 POST /device/{deviceID}/routes）
    func setDeviceRoutes(_ routes: [String], deviceID: String, token: String) async throws {
        let path = "/device/\(deviceID)/routes"
        let body = try JSONSerialization.data(withJSONObject: ["routes": routes])
        _ = try await perform("POST", path: path, token: token, body: body)
    }
}
