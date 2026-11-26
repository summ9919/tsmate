import Foundation

/// Tailscale 状态（本期为本地快照，二期替换为 LocalAPI 真实数据）
struct TailscaleStatus: Equatable {
    var backendState: String
    var relay: String
    var latencyMs: Int
    var packetLoss: Double
    var connectionType: String
    var isRunning: Bool
}

/// 二期接真实 Tailscale 时实现的协议。
/// LocalAPI 参考：GET /api/v2/status, GET /api/v2/peer, POST /api/v2/preferences
protocol TailscaleServicing {
    func status() async throws -> TailscaleStatus
    func listPeers() async throws -> [Device]
    func switchMode(_ mode: ConnectionMode) async throws
    func setAutoJoin(_ enabled: Bool) async throws
    func setHideIP(_ enabled: Bool) async throws
}

/// 一期 mock 实现：返回截图写死的数据，供 UI 层直接消费。
final class MockTailscaleService: TailscaleServicing {
    func status() async throws -> TailscaleStatus {
        TailscaleStatus(backendState: "Running",
                        relay: "cn-hk (直连)",
                        latencyMs: 5,
                        packetLoss: 0.0,
                        connectionType: "Wi-Fi · 双栈直连",
                        isRunning: true)
    }

    func listPeers() async throws -> [Device] {
        SampleData.devices
    }

    func switchMode(_ mode: ConnectionMode) async throws {
        // 二期：调用 POST /api/v2/preferences 设置 ShieldsUp / ExitNode 等参数
    }

    func setAutoJoin(_ enabled: Bool) async throws {
        // 二期：调用 Tailscale ACL / auth key 自动入网逻辑
    }

    func setHideIP(_ enabled: Bool) async throws {
        // 二期：控制设备列表是否展示完整 Tailnet IP
    }
}
