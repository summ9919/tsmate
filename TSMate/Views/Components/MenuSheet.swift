import SwiftUI

/// 左上角汉堡按钮弹出的侧栏菜单（真实可用）
struct MenuSheet: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("组网助手")
                    .font(.headline)
                Spacer()
                Button {
                    model.sheet = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.subText)
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            VStack(spacing: 4) {
                Button {
                    model.openSettings()
                } label: {
                    row("gearshape", "设置")
                }

                Button {
                    model.sheet = nil
                    Task { await model.refresh() }
                } label: {
                    row("arrow.clockwise", "立即刷新")
                }

                Button {
                    model.sheet = nil
                    Task {
                        await model.refresh()
                        model.appendLog("已打开运行日志（见下方黑色面板）")
                    }
                } label: {
                    row("doc.text", "运行日志")
                }

                Button {
                    model.sheet = nil
                    model.logout()
                } label: {
                    row("rectangle.portrait.and.arrow.right", "退出")
                }
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .background(Theme.card.ignoresSafeArea())
        .presentationDetents([.height(260)])
    }

    private func row(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundColor(Theme.brand)
            Text(title)
                .foregroundColor(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
