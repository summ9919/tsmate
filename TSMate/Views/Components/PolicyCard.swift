import SwiftUI

struct PolicyCard: View {
    @ObservedObject var model: AppModel

    private var isProbing: Bool { model.latencyMs == 0 }
    private var isOver: Bool { model.latencyMs > model.thresholdMs }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(Theme.ink)
                Text("超过 \(model.thresholdMs)ms 立即断开重连，强制改走国内直连")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.subText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.card)
        )
    }

    private var iconName: String {
        if isProbing { return "ellipsis.circle.fill" }
        return isOver ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
    }

    private var iconColor: Color {
        if isProbing { return Theme.subText }
        return isOver ? Theme.coral : Theme.okGreen
    }

    private var headline: String {
        if isProbing { return "正在探测直连时延…" }
        return "直连达标（\(model.latencyMs)ms ≤ \(model.thresholdMs)ms）"
    }
}
