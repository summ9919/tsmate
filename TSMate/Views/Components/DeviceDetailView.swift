import SwiftUI

/// 单台设备详情：真实地址、实测时延、授权状态、子网路由开关
struct DeviceDetailView: View {
    @ObservedObject var model: AppModel
    @Environment(.dismiss) private var dismiss
    let device: Device

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("设备")) {
                    LabeledRow(title: "名称", value: device.name)
                    LabeledRow(title: "状态", value: device.statusText)
                    LabeledRow(title: "系统", value: device.osName.isEmpty ? "未知" : device.osName)
                    LabeledRow(title: "客户端版本", value: device.clientVersion.isEmpty ? "—" : device.clientVersion)
                    LabeledRow(title: "Node ID", value: device.nodeId.isEmpty ? "—" : device.nodeId)
                }

                Section(header: Text("网络")) {
                    LabeledRow(title: "Tailscale IP", value: device.fullIP.isEmpty ? "—" : device.fullIP)
                    if !device.addresses.isEmpty {
                        LabeledRow(title: "全部地址", value: device.addresses.joined(separator: "\n"))
                    }
                    LabeledRow(title: "管理端口", value: "\(device.port)")
                    LabeledRow(title: "实测时延", value: device.latencyMs > 0 ? "\(device.latencyMs) ms" : "未测得")
                    LabeledRow(title: "直连路径", value: device.hasDirectPath ? "有（UDP 打洞成功）" : "无（走中继）")
                    if !device.lastSeen.isEmpty {
                        LabeledRow(title: "最近活跃", value: device.lastSeen)
                    }
                }

                Section(header: Text("子网路由")) {
                    if device.advertisedRoutes.isEmpty {
                        Text("该设备没有发布子网路由")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.subText)
                    } else {
                        LabeledRow(title: "已发布", value: device.advertisedRoutes.joined(separator: ", "))
                        LabeledRow(title: "已启用", value: device.enabledRoutes.isEmpty ? "未启用" : device.enabledRoutes.joined(separator: ", "))
                        Button {
                            model.toggleSubnetRoutes(for: device)
                        } label: {
                            Label(device.enabledRoutes.isEmpty ? "启用这些子网路由" : "停用这些子网路由",
                                  systemImage: device.enabledRoutes.isEmpty ? "arrow.turn.up.right" : "xmark.circle")
                        }
                    }
                }

                Section(header: Text("授权")) {
                    LabeledRow(title: "入网状态", value: device.isAuthorized ? "已授权" : "待授权")
                    LabeledRow(title: "设备来源", value: device.isExternal ? "外部共享" : "本 tailnet")
                    if !device.isAuthorized {
                        Button {
                            model.authorizeDevice(device)
                            dismiss()
                        } label: {
                            Label("授权该设备加入 Tailnet", systemImage: "checkmark.shield.fill")
                        }
                    }
                }

                Section {
                    Button {
                        model.probeDevice(device)
                    } label: {
                        HStack {
                            Label("重新探测时延", systemImage: "speedometer")
                            Spacer()
                            if model.probingDeviceID == device.id {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                }

                Section {
                    Text("时延为对 \(device.fullIP.isEmpty ? "—" : device.fullIP):\(device.port) 的真实 TCP 握手耗时；未测得表示当前不可达。在线状态由 Tailscale 上报的 lastSeen（\(device.lastSeen.isEmpty ? "未知" : device.lastSeen)）推断。")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.subText)
                }
            }
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct LabeledRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Theme.subText)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
