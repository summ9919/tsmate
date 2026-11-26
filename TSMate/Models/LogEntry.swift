import Foundation

struct LogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let time: String
    let message: String

    init(time: String, message: String) {
        self.id = UUID()
        self.time = time
        self.message = message
    }
}
