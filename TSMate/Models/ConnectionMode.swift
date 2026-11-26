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

    /// 写回 tailnet 偏好时实际改动的字段（显示在日志里）
    var apiEffect: String {
        switch self {
        case .p2p: return "清空 ExitNode、RouteAll=false、AdvertiseExitNode=false"
        case .relay: return "清空 ExitNode、RouteAll=false、NoPortForwarding=true"
        case .forced: return "清空 ExitNode、RouteAll=false、ShieldsUp=false、CorpDNS=true"
        case .subnet: return "RouteAll=true、WantRunning=true"
        }
    }

    /// 面向用户的一句话说明（详情页展示）
    var explain: String {
        switch self {
        case .p2p: return "关闭出口节点与全量路由，优先尝试 UDP 打洞直连对端"
        case .relay: return "关闭出口节点并停用端口转发，允许走 DERP 中继，弱网更稳"
        case .forced: return "禁用出口节点与防火墙屏蔽、保持 MagicDNS，国内直连不绕路"
        case .subnet: return "打开 RouteAll，启用子网路由（需对端已发布 subnet routes）"
        }
    }
}
