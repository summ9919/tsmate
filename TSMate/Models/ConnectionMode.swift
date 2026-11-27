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

    /// 这个模式实际会调用的真实 Tailscale API
    var apiEffect: String {
        switch self {
        case .p2p: return "启用 MagicDNS（会用 100.x 域名直连对端）"
        case .relay: return "启用 MagicDNS，允许 DERP 兜底"
        case .forced: return "启用 MagicDNS + 写入国内 DNS（223.5.5.5 / 114.114.114.114）"
        case .subnet: return "启用所有设备已发布的子网路由（POST /device/{id}/routes）"
        }
    }

    /// 面向用户的一句话说明
    var explain: String {
        switch self {
        case .p2p: return "打开 MagicDNS，用设备名直连对端，优先走 UDP 打洞路径"
        case .relay: return "打开 MagicDNS，直连不通时允许 DERP 中继兜底"
        case .forced: return "打开 MagicDNS 并把全局 DNS 指向国内解析，避免绕路境外"
        case .subnet: return "批准每台设备已发布的子网路由，让对端子网可经 Tailnet 访问"
        }
    }
}
