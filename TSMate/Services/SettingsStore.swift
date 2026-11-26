import Foundation
import Combine

/// 二期：接入真实 Tailscale LocalAPI 时使用的配置项。
/// API Key 在 Tailscale 客户端「设置 → 偏好设置 → 运营控制」中生成。
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }

    @Published var localAPIBase: String {
        didSet { UserDefaults.standard.set(localAPIBase, forKey: Keys.base) }
    }

    @Published var autoRefresh: Bool {
        didSet { UserDefaults.standard.set(autoRefresh, forKey: Keys.autoRefresh) }
    }

    private enum Keys {
        static let apiKey = "tsmate.apiKey"
        static let base = "tsmate.localAPIBase"
        static let autoRefresh = "tsmate.autoRefresh"
    }

    private init() {
        apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""
        localAPIBase = UserDefaults.standard.string(forKey: Keys.base) ?? "http://127.0.0.1:41112"
        autoRefresh = UserDefaults.standard.bool(forKey: Keys.autoRefresh)
    }
}
