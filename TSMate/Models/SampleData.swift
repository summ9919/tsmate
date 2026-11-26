import Foundation

enum SampleData {
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

    static let simulatedLogPool: [String] = [
        "心跳检测正常，丢包 0%，RTT 5ms",
        "UDP 打洞成功，已建立 P2P 通道（对端 win-evv798d2jdd）",
        "路由检查：走国内直连，未绕国外中继",
        "IPv6 通路复检：2409:8a55:**** 延迟 5ms",
        "子网路由表刷新：192.168.1.0/24 via nas-1-170-qichun",
        "DERP 中继列表更新：hk / cn 节点可用",
        "重新协商 NAT 映射成功，端口保持稳定",
        "对端 fnos-nas 传输 4.2MB/s，P2P 直连"
    ]
}
