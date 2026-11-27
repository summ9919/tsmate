import SwiftUI

/// TS 头像弹出的账号面板：展示真实身份与隧道状态
struct AccountSheet: View {
    let model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    LabeledRow(title: "tailnet", value: SettingsStore.shared.tailnet.isEmpty ? "未配置" : SettingsStore.shared.tailnet)
                    LabeledRow(title: "API Key", value: SettingsStore.shared.hasAPIConfig ? "已配置" : "未配置")
                }

                Section("隧道") {
                    LabeledRow(title: "状态", value: model.status.backendState)
                    LabeledRow(title: "链路", value: model.status.connectionType)
                    LabeledRow(title: "时延", value: String(model.status.latencyMs) + " ms（阈值 " + String(model.thresholdMs) + " ms）")
                    LabeledRow(title: "丢包", value: String(model.lossPercent) + "%")
                    LabeledRow(title: "MagicDNS", value: model.status.magicDNS ? "开" : "关")
                    LabeledRow(title: "全局 DNS", value: model.status.nameservers.isEmpty ? "未设置" : model.status.nameservers.joined(separator: ", "))
                    LabeledRow(title: "本机 Tailscale IP", value: model.status.selfIPs.isEmpty ? "未连接" : model.status.selfIPs.joined(separator: " / "))
                    LabeledRow(title: "本机 LAN IP", value: model.status.lanIPv4.isEmpty ? "未获取" : model.status.lanIPv4)
                    LabeledRow(title: "探测目标", value: model.status.probeTarget.isEmpty ? "—" : model.status.probeTarget)
                }

                Section("说明") {
                    Text("TS 头像代表 Tailscale 账号面板：这里显示 tailnet、隧道状态、真实链路与本机地址。点击可查看；点右上角电源按钮可直接跳转 Tailscale 官方 App。")
                        .font(.footnote)
                        .foregroundColor(Theme.subText)
                }
            }
            .navigationTitle("TS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { model.sheet = nil }
                }
            }
        }
    }
}

private struct LabeledRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Theme.subText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
