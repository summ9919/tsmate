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
/// 注意：真实返回里 clientConnectivity 是「区域 → 连接信息」的字典，
/// 也有版本直接返回单个对象，这里做兼容解析。
struct TailscaleAPIDevice: Decodable, Identifiable {
    struct Connectivity: Decodable {
        var active: Bool?
        var lastSeen: String?
        var relay: String?
        var curAddr: String?
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
    var relay: String?
    var clientConnectivity: [String: Connectivity]?

    enum CodingKeys: String, CodingKey {
        case id, nodeId, name, hostName, os, addresses, authorized
        case clientVersion, lastSeen, relay, clientConnectivity
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
        relay = (try? c.decode(String.self, forKey: .relay))

        if let map = (try? c.decode([String: Connectivity].self, forKey: .clientConnectivity)) {
            clientConnectivity = map
        } else if let single = (try? c.decode(Connectivity.self, forKey: .clientConnectivity)) {
            clientConnectivity = ["_": single]
        } else {
            clientConnectivity = nil
        }
    }

    /// 展示名：优先短主机名，其次去掉 .ts.net 后缀的 name，最后用 id
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

    /// 是否在线：任一区域连接 active
    var isOnline: Bool {
        if !isAuthorized { return false }
        if let map = clientConnectivity, !map.isEmpty {
            for value in map.values where value.active == true { return true }
            return false
        }
        return authorized ?? true
    }

    /// 中继节点名（DERP 区域）
    var relayName: String {
        if let map = clientConnectivity {
            for value in map.values where value.active == true {
                if let relay = value.relay, !relay.isEmpty { return relay }
            }
        }
        return relay ?? ""
    }

    /// 最近在线时间
    var lastSeenText: String {
        if let value = lastSeen, !value.isEmpty { return value }
        if let map = clientConnectivity {
            for value in map.values {
                if let seen = value.lastSeen, !seen.isEmpty { return seen }
            }
        }
        return ""
    }
}

struct TailscaleAPIError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? {
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

    /// 真实设备列表
    func devices(tailnet: String, token: String) async throws -> [TailscaleAPIDevice] {
        let path = "/tailnet/\(tailnet)/devices"
        let data = try await perform("GET", path: path, token: token, body: nil)
        let response = try JSONDecoder().decode(DeviceListResponse.self, from: data)
        return response.devices ?? []
    }

    /// 授权（放行）一台待批准的设备 —— 「新设备自动入网」的真实实现
    func authorize(deviceID: String, token: String) async throws {
        let path = "/device/\(deviceID)/authorized"
        _ = try await perform("POST", path: path, token: token, body: nil)
    }

    /// 读取 tailnet 偏好（原始 JSON，保留未知字段）
    func prefs(tailnet: String, token: String) async throws -> [String: JSONValue] {
        let path = "/tailnet/\(tailnet)/prefs"
        let data = try await perform("GET", path: path, token: token, body: nil)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        return decoded
    }

    /// 写回 tailnet 偏好
    func updatePrefs(_ prefs: [String: JSONValue], tailnet: String, token: String) async throws {
        let path = "/tailnet/\(tailnet)/prefs"
        let body = try JSONEncoder().encode(prefs)
        _ = try await perform("POST", path: path, token: token, body: body)
    }
}
