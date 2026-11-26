import SwiftUI

struct LogConsole: View {
    @ObservedObject private var store = LogStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(Theme.okGreen).frame(width: 7, height: 7)
                Text("运行日志")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.logDim)
                Spacer()
                Text("\(store.entries.count) 条")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.logDim)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(store.entries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.time)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundColor(Theme.logDim)
                                Text(entry.message)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundColor(Theme.logText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .id(entry.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: store.entries.count) { _ in
                    withAnimation(.linear(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.ink)
        )
    }
}
