import Foundation
import SwiftUI

final class AppModel: ObservableObject {
    @Published var devices: [Device] = SampleData.devices
    @Published var logs: [LogEntry] = SampleData.seedLogs
    @Published var mode: ConnectionMode = .forced
    @Published var autoJoinNewDevice = false
    @Published var hideIP = true
    @Published var isMenuOpen = false
    @Published var isTailscaleRunning = true

    var onlineCount: Int { devices.filter { $0.isOnline }.count }
    var statusCards: [StatusCard] {
        [
            StatusCard(id: "speed",
                       icon: .bolt,
                       title: "组网速率",
                       detail: "Wi-Fi · 双栈直连 · 5 ms · 丢包 0%"),
            StatusCard(id: "optimize",
                       icon: .rocket,
                       title: "网络优化",
                       detail: "5ms 直连 √"),
            StatusCard(id: "launch",
                       icon: .globe,
                       title: "启动 Tailscale",
                       detail: isTailscaleRunning ? "已打开 · Tailscale里点连接" : "已关闭 · 请在 Tailscale 中打开"),
            StatusCard(id: "sdwan",
                       icon: .network,
                       title: "SD-WAN",
                       detail: "192.168.1.170 · 5ms")
        ]
    }

    private let service: TailscaleServicing = MockTailscaleService()
    private var timer: Timer?
    private var logCursor = 0

    // MARK: - 日志

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            self?.appendSimulatedLog()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func appendSimulatedLog() {
        let pool = SampleData.simulatedLogPool
        let message = pool[logCursor % pool.count]
        logCursor += 1
        appendLog(message)
    }

    func appendLog(_ message: String) {
        let entry = LogEntry(time: Self.nowStamp(), message: message)
        logs.append(entry)
        if logs.count > 200 { logs.removeFirst(logs.count - 200) }
    }

    static func nowStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    // MARK: - 交互

    func select(mode newMode: ConnectionMode) {
        guard newMode != mode else { return }
        mode = newMode
        appendLog("模式切换：(newMode.logDescription)")
    }

    func toggleAutoJoin() {
        autoJoinNewDevice.toggle()
        appendLog(autoJoinNewDevice
                  ? "已开启「新设备自动入网」，新设备将自动加入 Tailnet"
                  : "已关闭「新设备自动入网」")
    }

    func toggleHideIP() {
        hideIP.toggle()
        appendLog(hideIP ? "已开启「IP 隐藏」，设备列表 IP 已打码" : "已关闭「IP 隐藏」，展示完整 Tailnet IP")
    }

    func logout() {
        appendLog("已退出组网助手")
    }

    func ipText(for device: Device) -> String {
        hideIP ? device.ip : device.fullIP
    }
}
