import Foundation
import Combine

/// App 配置。
/// - API Key 与 tailnet 存 Keychain（敏感，不落 UserDefaults）
/// - 刷新间隔、自动刷新等非敏感项存 UserDefaults
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// Tailscale Admin API Key
    @Published var apiKey: String {
        didSet {
            guard apiKey != oldValue else { return }
            KeychainStore.set(apiKey, forKey: Keys.apiKey)
            if !apiKey.isEmpty { LogStore.shared.append("已保存 Tailscale API Key") }
        }
    }

    /// tailnet 名称，形如 user@example.com
    @Published var tailnet: String {
        didSet {
            KeychainStore.set(tailnet, forKey: Keys.tailnet)
            if !tailnet.isEmpty { LogStore.shared.append("已保存 tailnet：\(tailnet)") }
        }
    }

    /// 本机 Tailscale 客户端 LocalAPI（Mac/Windows 客户端才有；iOS 走 Admin API）
    @Published var localAPIBase: String {
        didSet { UserDefaults.standard.set(localAPIBase, forKey: Keys.base) }
    }

    /// 是否自动刷新
    @Published var autoRefresh: Bool {
        didSet { UserDefaults.standard.set(autoRefresh, forKey: Keys.autoRefresh) }
    }

    /// 刷新间隔（秒）
    @Published var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Keys.interval) }
    }

    /// 策略阈值（毫秒），超过即断开重连并强制国内直连
    @Published var latencyThreshold: Int {
        didSet { UserDefaults.standard.set(latencyThreshold, forKey: Keys.threshold) }
    }

    private enum Keys {
        static let apiKey = "tsmate.apiKey"
        static let tailnet = "tsmate.tailnet"
        static let base = "tsmate.localAPIBase"
        static let autoRefresh = "tsmate.autoRefresh"
        static let interval = "tsmate.refreshInterval"
        static let threshold = "tsmate.latencyThreshold"
    }

    private init() {
        apiKey = KeychainStore.get(Keys.apiKey) ?? ""
        tailnet = KeychainStore.get(Keys.tailnet) ?? ""
        localAPIBase = UserDefaults.standard.string(forKey: Keys.base) ?? "http://127.0.0.1:41112"
        autoRefresh = UserDefaults.standard.object(forKey: Keys.autoRefresh) as? Bool ?? true
        let stored = UserDefaults.standard.integer(forKey: Keys.interval)
        refreshInterval = stored > 0 ? stored : 8
        let threshold = UserDefaults.standard.integer(forKey: Keys.threshold)
        latencyThreshold = threshold > 0 ? threshold : 40
    }

    /// 是否已具备拉取真实设备列表的条件
    var hasAPIConfig: Bool {
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !tailnet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
