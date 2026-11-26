import Foundation
import Combine

/// 全局日志中心：服务层与 ViewModel 共用同一份带时间戳的日志流。
/// 界面底部「运行日志」直接消费这里，service 层也能独立写日志。
final class LogStore: ObservableObject {
    static let shared = LogStore()

    /// 启动快照（来自截图的真实值），之后追加的都是真实运行日志
    @Published private(set) var entries: [LogEntry] = SampleData.seedLogs

    private let maxEntries = 300

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {}

    /// 线程安全写日志（后台线程调用会自动切主线程）
    func append(_ message: String) {
        if Thread.isMainThread {
            commit(message)
        } else {
            DispatchQueue.main.async { self.commit(message) }
        }
    }

    private func commit(_ message: String) {
        entries.append(LogEntry(time: LogStore.stampFormatter.string(from: Date()), message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    static func nowStamp() -> String {
        stampFormatter.string(from: Date())
    }
}
