import Foundation

enum DeviceStatus: String, Codable, Hashable {
    case online
    case offline
}

struct Device: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    /// 打码后的 Tailscale IP（IP 隐藏开启时展示）
    let ip: String
    /// 完整 Tailscale IP（IP 隐藏关闭时展示）
    let fullIP: String
    let port: Int
    let status: DeviceStatus

    var statusText: String {
        switch status {
        case .online: return "在线"
        case .offline: return "离线"
        }
    }

    var isOnline: Bool { status == .online }
}
