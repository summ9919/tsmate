import SwiftUI

struct DeviceListCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("我的设备")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { model.autoJoinNewDevice },
                    set: { _ in model.toggleAutoJoin() }
                )) {
                    Text("新设备自动入网")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.ink)
                }
                .tint(Theme.brand)

                Toggle(isOn: Binding(
                    get: { model.hideIP },
                    set: { _ in model.toggleHideIP() }
                )) {
                    Text("IP 隐藏")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.ink)
                }
                .tint(Theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider().overlay(Theme.line)

            HStack(spacing: 0) {
                Text("设备")
                    .frame(width: 118, alignment: .leading)
                Text("IP")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("状态")
                    .frame(width: 52, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Theme.subText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().overlay(Theme.line)

            VStack(spacing: 0) {
                ForEach(Array(model.devices.enumerated()), id: \.element.id) { index, device in
                    deviceRow(device)
                    if index < model.devices.count - 1 {
                        Divider().overlay(Theme.line.opacity(0.7))
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.card)
        )
    }

    private func deviceRow(_ device: Device) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                Text(device.subtitle)
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.subText)
                    .lineLimit(1)
            }
            .frame(width: 118, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.ipText(for: device))
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.ink)
                Text("端口 \(device.port)")
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.subText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(device.statusText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(device.isOnline ? .white : Theme.subText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(device.isOnline ? Theme.okGreen : Theme.bg)
                )
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
