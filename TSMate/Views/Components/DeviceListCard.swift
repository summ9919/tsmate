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
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.brand)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if model.isUsingSampleData {
                Text("示例数据 · 点右上角设置填入 Tailscale API Key 后显示真实设备")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.brand)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

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
                    .frame(width: 112, alignment: .leading)
                Text("IP")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("状态")
                    .frame(width: 62, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Theme.subText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().overlay(Theme.line)

            VStack(spacing: 0) {
                ForEach(Array(model.devices.enumerated()), id: \.element.id) { index, device in
                    Button {
                        model.openDevice(device)
                    } label: {
                        deviceRow(device)
                    }
                    .buttonStyle(.plain)
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
            .frame(width: 112, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.ipText(for: device))
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.ink)
                Text(device.latencyMs > 0 ? "\(device.latencyMs) ms" : "端口 \(device.port)")
                    .font(.system(size: 9.5))
                    .foregroundColor(device.latencyMs > 0 ? Theme.okGreen : Theme.subText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(device.statusText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(statusTextColor(device))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(statusBackground(device))
                )
                .frame(width: 62, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func statusTextColor(_ device: Device) -> Color {
        switch device.status {
        case .online: return .white
        case .pending: return Theme.ink
        case .offline: return Theme.subText
        }
    }

    private func statusBackground(_ device: Device) -> Color {
        switch device.status {
        case .online: return Theme.okGreen
        case .pending: return Theme.yellow
        case .offline: return Theme.bg
        }
    }
}
