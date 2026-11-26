import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

enum Theme {
    /// 主蓝 #1B6EF3
    static let brand = Color(hex: 0x1B6EF3)
    static let brandDark = Color(hex: 0x1456C4)
    static let brandSoft = Color(hex: 0xEAF2FE)
    /// 强调青 #00C2A8
    static let accent = Color(hex: 0x00C2A8)
    /// 墨黑 #0B0B0C
    static let ink = Color(hex: 0x0B0B0C)
    static let bg = Color(hex: 0xF1F4F9)
    static let card = Color.white
    static let line = Color(hex: 0xE4E9F2)
    static let subText = Color(hex: 0x8A94A6)
    static let yellow = Color(hex: 0xFFD60A)
    static let coral = Color(hex: 0xFF6B6B)
    static let sky = Color(hex: 0x8FD8FF)
    static let okGreen = Color(hex: 0x22C55E)
    static let logText = Color(hex: 0xD7DEE9)
    static let logDim = Color(hex: 0x6B7688)
}
