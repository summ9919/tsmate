import Foundation

enum ConnectionMode: String, CaseIterable, Identifiable, Codable {
    case p2p = "P2P 直连"
    case relay = "中继优先"
    case forced = "强制直连"
    case subnet = "子网路由"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .p2p: return "P2P"
        case .relay: return "中继"
        case .forced: return "强制直连"
        case .subnet: return "子网"
        }
    }

    var logDescription: String {
        switch self {
        case .p2p: return "已切换到 P2P 直连模式，优先 UDP 打洞"
        case .relay: return "已切换到中继优先模式（DERP 中转）"
        case .forced: return "强制直连生效：国内直连，禁用境外中继"
        case .subnet: return "已切换到子网路由模式，转发子网流量"
        }
    }
}
