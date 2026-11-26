import SwiftUI

struct PolicyCard: View {
    let latencyMs: Int = 5
    let thresholdMs: Int = 40

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundColor(Theme.okGreen)

            VStack(alignment: .leading, spacing: 3) {
                Text("直连达标（\(latencyMs)ms ≤ \(thresholdMs)ms）")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(Theme.ink)
                Text("超过 \(thresholdMs)ms 立即断开重连，强制改走国内直连")
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
}
