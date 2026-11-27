import Foundation
import SwiftUI
import Combine
import UIKit

/// App 弹出的页面类型
enum AppSheet: Identifiable {
    case settings
    case device(Device)
    case menu
    case account

    var id: String {
        switch self {
        case .settings: return "settings"
        case .device(let device): return "device-" + device.id
        case .menu: return "menu"
        case .account: return "account"
        }
    }
}

/// App 主状态模型。
/// 数据来源全部为真实探测 + Tailscale Admin API。
final class AppModel: ObservableObject {

    @Published var devices: [Device] = SampleData.devices
    @Published var status: TailscaleStatus = .empty
    @Published var mode: ConnectionMode = .forced
    @Published var autoJoinNewDevice: Bool = UserDefaults.standard.bool(forKey: "tsmate.autoJoin")
    @Published var hideIP: Bool = (UserDefaults.standard.object(forKey: "tsmate.hideIP") as? Bool) ?? true
    @Published var isMenuOpen = false
    @Published var isRefreshing = false
    @Published var isUsingSampleData = true
    @Published var sheet: AppSheet?
    @Published var probingDeviceID: String = ""
    @Published var lastRefreshText = "—"
    /// 正在写回的模式（非空表示有写回在进行）
    @Published var applyingMode: ConnectionMode?
    /// 最近一次模式写回结果文案
    @Published var modeResultText = ""

    private let service: TailscaleServicing = TailscaleManager()
    private var refreshTask: Task<Void, Never>?

    var onlineCount: Int { devices.filter { $0.isOnline }.count }

    var latencyMs: Int { status.latencyMs }

    var lossPercent: Int { Int((status.packetLoss * 100).rounded()) }

    var thresholdMs: Int { SettingsStore.shared.latencyThreshold }

    var statusCards: [StatusCard] {
        let link = status.connectionType
        let stack = status.dualStack ? "双栈" : "单栈"
        let path = status.directPath ? "直连" : "中继"
        let speed = link + " · " + stack + path + " · " + String(status.latencyMs) + " ms · 丢包 " + String(lossPercent) + "%"

        let optimize: String
        if status.latencyMs == 0 {
            optimize = "探测中…"
        } else if status.latencyMs <= thresholdMs {
            optimize = String(status.latencyMs) + "ms 直连 √"
        } else {
            optimize = String(status.latencyMs) + "ms 超阈值，正在强制直连"
        }

        let launch = status.isRunning ? "已打开 · Tailscale里点连接" : "已关闭 · 请在 Tailscale 中打开"
        let sdwan = status.lanIPv4.isEmpty ? "本机 LAN 未获取" : status.lanIPv4 + " · " + String(status.latencyMs) + "ms"

        return [
            StatusCard(id: "speed", icon: .bolt, title: "组网速率", detail: speed),
            StatusCard(id: "optimize", icon: .rocket, title: "网络优化", detail: optimize),
            StatusCard(id: "launch", icon: .globe, title: "启动 Tailscale", detail: launch),
            StatusCard(id: "sdwan", icon: .network, title: "SD-WAN", detail: sdwan)
        ]
    }

    // MARK: - 生命周期

    func start() {
        stop()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let interval = max(3, SettingsStore.shared.refreshInterval)
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - 真实刷新

    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let newStatus = try await service.status()
            status = newStatus
            lastRefreshText = AppModel.nowStamp()
        } catch {
            appendLog("本机状态探测失败：" + error.localizedDescription)
        }

        do {
            let peers = try await service.listPeers()
            if !peers.isEmpty {
                var merged: [Device] = []
                for var device in peers {
                    if let old = devices.first(where: { $0.id == device.id }) {
                        device.latencyMs = old.latencyMs
                    }
                    merged.append(device)
                }
                devices = merged
                isUsingSampleData = false
                await probeAllDevices()
            }
        } catch {
            appendLog("设备列表拉取失败：" + error.localizedDescription)
        }

        await enforcePolicy()
    }

    @MainActor
    private func probeAllDevices() async {
        let targets = devices.filter { $0.status == .online && !$0.fullIP.isEmpty }
        guard !targets.isEmpty else { return }
        for target in targets {
            let ms = await service.probeLatency(for: target)
            if let index = devices.firstIndex(where: { $0.id == target.id }) {
                devices[index].latencyMs = ms
            }
        }
    }

    /// 策略：时延超过阈值立即切强制直连（真实写回 tailnet 配置）
    @MainActor
    private func enforcePolicy() async {
        let threshold = thresholdMs
        guard status.latencyMs > 0, status.latencyMs > threshold, mode != .forced else { return }
        appendLog("时延 " + String(status.latencyMs) + "ms 超过 " + String(threshold) + "ms，执行断开重连并强制改走国内直连")
        mode = .forced
        await applyMode(.forced)
    }

    // MARK: - 设备交互

    func probeDevice(_ device: Device) {
        probingDeviceID = device.id
        Task { [weak self] in
            guard let self else { return }
            let ms = await self.service.probeLatency(for: device)
            await MainActor.run {
                if let index = self.devices.firstIndex(where: { $0.id == device.id }) {
                    self.devices[index].latencyMs = ms
                }
                self.probingDeviceID = ""
                self.appendLog("实测 " + device.name + "：" + (ms > 0 ? String(ms) + " ms" : "不可达"))
            }
        }
    }

    func authorizeDevice(_ device: Device) {
        appendLog("正在授权设备 " + device.name + "…")
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.authorize(deviceID: device.id)
                self.appendLog("设备 " + device.name + " 已授权，正在重新拉取列表")
                await self.refresh()
            } catch {
                self.appendLog("授权失败：" + error.localizedDescription)
            }
        }
    }

    func toggleSubnetRoutes(for device: Device) {
        let enable = device.enabledRoutes.isEmpty
        appendLog(enable ? "正在启用 " + device.name + " 的子网路由…" : "正在停用 " + device.name + " 的子网路由…")
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.setDeviceSubnetRoutes(device, enabled: enable)
                await self.refresh()
            } catch {
                self.appendLog("子网路由设置失败：" + error.localizedDescription)
            }
        }
    }

    // MARK: - 模式 / 开关

    func select(mode newMode: ConnectionMode) {
        guard newMode != mode else { return }
        mode = newMode
        appendLog(newMode.logDescription)
        Task { await applyMode(newMode) }
    }

    /// 真实写回：调用 Tailscale API 并刷新状态
    @MainActor
    func applyMode(_ newMode: ConnectionMode) async {
        applyingMode = newMode
        modeResultText = "正在写回…"
        defer { applyingMode = nil }
        do {
            try await service.switchMode(newMode)
            modeResultText = newMode.rawValue + " 已生效"
            appendLog("模式写回成功：" + newMode.rawValue + "（" + newMode.apiEffect + "）")
            await refresh()
        } catch {
            modeResultText = "写回失败：" + error.localizedDescription
            appendLog("模式写回失败：" + error.localizedDescription)
        }
    }

    func toggleAutoJoin() {
        autoJoinNewDevice.toggle()
        let enabled = autoJoinNewDevice
        UserDefaults.standard.set(enabled, forKey: "tsmate.autoJoin")
        appendLog(enabled ? "已开启「新设备自动入网」，新设备将自动加入 Tailnet" : "已关闭「新设备自动入网」")
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.setAutoJoin(enabled)
            } catch {
                self.appendLog("自动入网设置失败：" + error.localizedDescription)
            }
        }
    }

    func toggleHideIP() {
        hideIP.toggle()
        let enabled = hideIP
        appendLog(enabled ? "已开启「IP 隐藏」，设备列表 IP 已打码" : "已关闭「IP 隐藏」，展示完整 Tailnet IP")
        Task { [weak self] in
            guard let self else { return }
            try? await self.service.setHideIP(enabled)
        }
    }

    func openTailscaleApp() {
        guard let url = URL(string: "tailscale://") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        appendLog("已跳转 Tailscale App，请在官方客户端中点击连接")
    }

    func openSettings() { sheet = .settings }

    func openMenu() {
        isMenuOpen = true
        sheet = .menu
    }

    func openAccount() { sheet = .account }

    func openDevice(_ device: Device) { sheet = .device(device) }

    func logout() {
        appendLog("已退出组网助手（隧道由 Tailscale 官方 App 管理）")
    }

    func ipText(for device: Device) -> String {
        hideIP ? device.ip : device.fullIP
    }

    // MARK: - 日志

    func appendLog(_ message: String) {
        LogStore.shared.append(message)
    }

    static func nowStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}
