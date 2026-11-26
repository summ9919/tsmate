import SwiftUI

struct TopBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.isMenuOpen.toggle()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.ink)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(ConnectionMode.allCases) { m in
                    Button {
                        model.select(mode: m)
                    } label: {
                        if m == model.mode {
                            Label(m.rawValue, systemImage: "checkmark")
                        } else {
                            Text(m.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.brand)
                    Text(model.mode.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.subText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.line, lineWidth: 1)
                        )
                )
            }

            Spacer(minLength: 4)

            Text("\(model.onlineCount)/\(model.devices.count)在线")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.subText)

            Circle()
                .fill(Theme.brand)
                .frame(width: 28, height: 28)
                .overlay(
                    Text("TS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )

            Button("退出") {
                model.logout()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Theme.ink)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Theme.bg)
    }
}
