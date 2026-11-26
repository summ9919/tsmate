import SwiftUI

/// 设置页：填入 Tailscale Admin API Key 与 tailnet，配置策略阈值与刷新间隔
struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var testResult = ""
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tailscale 接入")) {
                    SecureField("API Key（tskey-…）", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("tailnet（user@example.com）", text: $settings.tailnet)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Button {
                            runTest()
                        } label: {
                            if isTesting {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("测试连接")
                            }
                        }
                        .disabled(isTesting || !settings.hasAPIConfig)
                        if settings.hasAPIConfig {
                            Text("已配置")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.okGreen)
                        }
                    }
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.subText)
                    }
                    Link("如何获取 API Key？", destination: URL(string: "https://login.tailscale.com/admin/settings/keys")!)
                        .font(.system(size: 12))
                }

                Section(header: Text("策略")) {
                    HStack {
                        Text("直连时延阈值")
                        Spacer()
                        Text("\(settings.latencyThreshold) ms")
                            .foregroundColor(Theme.subText)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.latencyThreshold) },
                        set: { settings.latencyThreshold = Int($0.rounded()) }
                    ), in: 10...200, step: 5)
                    Text("实测时延超过该值时，App 会立即断开重连并强制改走国内直连")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.subText)
                }

                Section(header: Text("刷新")) {
                    Toggle("自动刷新", isOn: $settings.autoRefresh)
                    HStack {
                        Text("刷新间隔")
                        Spacer()
                        Text("\(settings.refreshInterval) 秒")
                            .foregroundColor(Theme.subText)
                    }
                    Stepper(value: $settings.refreshInterval, in: 3...120, step: 1) {
                        Text("每 \(settings.refreshInterval) 秒重新探测一次")
                    }
                }

                Section(header: Text("说明")) {
                    Text("iOS 上 Tailscale 隧道由官方 App 建立，本 App 负责：真实网络探测（网卡 / 时延 / 丢包）、真实设备列表、待授权设备自动入网、模式偏好写回。")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.subText)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func runTest() {
        isTesting = true
        testResult = ""
        Task {
            let token = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let tailnet = settings.tailnet.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                let list = try await TailscaleAPIClient.shared.devices(tailnet: tailnet, token: token)
                testResult = "连接成功，共 \(list.count) 台设备"
            } catch {
                testResult = "连接失败：\(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
