import Foundation

enum DeviceStatus: String, Codable, Hashable {
    case online
    case offline
    /// 待授权（新设备自动入网会处理）
    case pending

    var statusText: String {
        switch self {
        case .online: return "在线"
        case .offline: return "离线"
        case .pending: return "待授权"
        }
    }

    /// 列表排序：在线 > 待授权 > 离线
    var sortOrder: Int {
        switch self {
        case .online: return 0
        case .pending: return 1
        case .offline: return 2
        }
    }
}

struct Device: Identifiable, Codable, Hashable {
    /// Tailscale 设备 ID（Admin API 的 device id）
    let id: String
    let name: String
    let subtitle: String
    /// 打码后的 Tailscale IP（IP 隐藏开启时展示）
    let ip: String
    /// 完整 Tailscale IP（IP 隐藏关闭时展示）
    let fullIP: String
    let port: Int
    let status: DeviceStatus

    /// 实测 TCP 可达时延（毫秒）；0 表示未探测到
    var latencyMs: Int = 0
    /// 操作系统（Tailscale 上报）
    var osName: String = ""
    /// 客户端版本
    var clientVersion: String = ""
    /// 最近在线时间（原始字符串）
    var lastSeen: String = ""
    /// Node Key
    var nodeId: String = ""
    /// 全部地址（IPv4 + IPv6）
    var addresses: [String] = []
    /// 是否已被授权
    var isAuthorized: Bool = true

    var statusText: String { status.statusText }

    var isOnline: Bool { status == .online }

    var latencyText: String {
        latencyMs > 0 ? "\(latencyMs)ms" : "—"
    }

    /// IP 打码：100.116.28.170 -> 100.116.*.*
    static func mask(_ address: String) -> String {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "—" }
        if text.contains(":") {
            let parts = text.split(separator: ":")
            guard parts.count > 2 else { return text }
            return "\(parts[0]):\(parts[1]):****:****:****:****:****:****"
        }
        let parts = text.split(separator: ".")
        guard parts.count == 4 else { return text }
        return "\(parts[0]).\(parts[1]).*.*"
    }
}
