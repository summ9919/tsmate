import Foundation
import SwiftUI

enum CardIcon: String {
    case bolt
    case rocket
    case globe
    case network

    var symbol: String {
        switch self {
        case .bolt: return "bolt.fill"
        case .rocket: return "rocket.fill"
        case .globe: return "globe.asia.australia.fill"
        case .network: return "network"
        }
    }

    var tint: Color {
        switch self {
        case .bolt: return Theme.yellow
        case .rocket: return Theme.coral
        case .globe: return Theme.sky
        case .network: return Theme.sky
        }
    }
}

struct StatusCard: Identifiable, Hashable {
    let id: String
    let icon: CardIcon
    let title: String
    let detail: String
}
