import SwiftUI

struct ModeSelector: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(ConnectionMode.allCases) { mode in
                    let selected = mode == model.mode
                    Button {
                        model.select(mode: mode)
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selected ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? Theme.brand : Theme.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selected ? Color.clear : Theme.line, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                if model.applyingMode != nil {
                    ProgressView().controlSize(.mini)
                }
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundColor(statusColor)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
        }
    }

    private var statusLine: String {
        if model.applyingMode != nil {
            return "正在写回 " + model.applyingMode!.rawValue + " 到 Tailscale…"
        }
        if !model.modeResultText.isEmpty {
            return model.modeResultText
        }
        return model.mode.explain
    }

    private var statusColor: Color {
        if model.applyingMode != nil { return Theme.subText }
        if model.modeResultText.hasPrefix("写回失败") { return Theme.coral }
        if model.modeResultText.hasSuffix("已生效") { return Theme.okGreen }
        return Theme.subText
    }
}
