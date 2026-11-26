import Foundation

enum SampleData {
    /// 未配置 API Key 时展示的示例设备（与截图一致）
    static let devices: [Device] = [
        Device(id: "nas-1-170-qichun",
               name: "nas-1-170-qichun",
               subtitle: "私网 192.168.1.170",
               ip: "100.116.*.*",
               fullIP: "100.116.28.170",
               port: 22,
               status: .online),
        Device(id: "fnos-nas",
               name: "fnos-nas",
               subtitle: "私网 192.168.2.199",
               ip: "100.108.*.*",
               fullIP: "100.108.11.199",
               port: 22,
               status: .online),
        Device(id: "vivo-mini200pro",
               name: "vivo-mini200pro",
               subtitle: "私网 自动获取中...",
               ip: "100.123.*.*",
               fullIP: "100.123.94.77",
               port: 22,
               status: .offline),
        Device(id: "hi3798mv100",
               name: "hi3798mv100",
               subtitle: "私网 自动获取中...",
               ip: "100.93.*.*",
               fullIP: "100.93.5.213",
               port: 22,
               status: .offline),
        Device(id: "aoc-win",
               name: "aoc-win",
               subtitle: "私网 192.168.2.198",
               ip: "100.114.*.*",
               fullIP: "100.114.60.198",
               port: 445,
               status: .offline)
    ]

    static let seedLogs: [LogEntry] = [
        LogEntry(time: "21:21:27", message: "组网速率 5ms，丢包 0% (Wi-Fi · 双栈直连)"),
        LogEntry(time: "21:21:27", message: "强制直连生效："),
        LogEntry(time: "21:21:27", message: "2409:8a55:d0f4:****:****:****:****:**** 通路正常"),
        LogEntry(time: "21:21:27", message: "路由检查：走国内直连（P2P 打洞/UDP 直通），未绕国外中继")
    ]
}
