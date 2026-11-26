import Foundation
import Darwin
import Network

/// 一条本机网络接口
struct NetworkInterfaceInfo: Identifiable, Hashable {
    var id: String { name + "/" + address }
    let name: String
    let address: String
    let isIPv4: Bool

    /// Tailscale CGNAT 网段 100.64.0.0/10
    var isTailscaleIPv4: Bool {
        guard isIPv4 else { return false }
        let parts = address.split(separator: ".")
        guard parts.count == 4, let a = Int(parts[0]), let b = Int(parts[1]) else { return false }
        return a == 100 && b >= 64 && b <= 127
    }

    /// Tailscale ULA 网段 fd7a:115c:a1e0::/48
    var isTailscaleIPv6: Bool {
        guard !isIPv4 else { return false }
        return address.lowercased().hasPrefix("fd7a:115c:a1e0:")
    }
}

/// 真实网络探测：接口枚举 + TCP 握手时延 + 丢包率 + DNS 解析
enum NetworkProbe {

    // MARK: - 本机接口

    /// 枚举本机所有 IPv4 / IPv6 接口地址
    static func interfaces() -> [NetworkInterfaceInfo] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var result: [NetworkInterfaceInfo] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let node = cursor {
            let ifa = node.pointee
            let name = String(cString: ifa.ifa_name)
            if let addr = ifa.ifa_addr {
                let family = addr.pointee.sa_family
                if family == sa_family_t(AF_INET) || family == sa_family_t(AF_INET6) {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let length = socklen_t(family == sa_family_t(AF_INET)
                                           ? MemoryLayout<sockaddr_in>.size
                                           : MemoryLayout<sockaddr_in6>.size)
                    if getnameinfo(addr, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: host)
                        let isV4 = (family == sa_family_t(AF_INET))
                        result.append(NetworkInterfaceInfo(name: name, address: ip, isIPv4: isV4))
                    }
                }
            }
            cursor = ifa.ifa_next
        }
        return result
    }

    /// 局域网 IPv4（en0 = Wi-Fi，bridge/en1 = 有线）
    static func lanIPv4() -> String? {
        let all = interfaces()
        let preferred = all.filter { item in
            if !item.isIPv4 || item.isTailscaleIPv4 { return false }
            if item.name == "en0" || item.name == "en1" { return true }
            return item.name.hasPrefix("bridge")
        }
        if let hit = preferred.first { return hit.address }
        let fallback = all.filter { item in
            item.isIPv4 && !item.isTailscaleIPv4 && item.name != "lo0"
        }
        return fallback.first?.address
    }

    /// 本机 Tailscale IPv4（隧道在线时出现 100.64/10 地址）
    static func tailscaleIPv4() -> String? {
        return interfaces().first { item in item.isTailscaleIPv4 }?.address
    }

    /// 本机 Tailscale IPv6
    static func tailscaleIPv6() -> String? {
        return interfaces().first { item in item.isTailscaleIPv6 }?.address
    }

    /// 是否处于蜂窝数据（pdp_ip0 有 IPv4）
    static func isCellularActive() -> Bool {
        for item in interfaces() {
            if item.isIPv4 && item.name.hasPrefix("pdp_ip") { return true }
        }
        return false
    }

    /// 本机当前链路类型名称
    static func linkTypeName() -> String {
        if isCellularActive() { return "蜂窝数据" }
        let hasWiFi = interfaces().contains { item in
            item.isIPv4 && item.name == "en0"
        }
        if hasWiFi { return "Wi-Fi" }
        if interfaces().contains { item in item.isIPv4 && item.name.hasPrefix("bridge") } {
            return "有线"
        }
        return "未知"
    }

    /// 本机是否已连上 Tailscale（隧道拿到 100.x 地址即视为在线）
    static var isTailscaleConnected: Bool {
        return tailscaleIPv4() != nil
    }

    // MARK: - 网关

    /// 由局域网地址推断网关（192.168.1.23 -> 192.168.1.1）
    static func gatewayIPv4() -> String? {
        guard let lan = lanIPv4() else { return nil }
        let parts = lan.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2]).1"
    }

    /// 探测网关时延（真实 TCP 握手）
    static func gatewayLatency(timeout: TimeInterval = 1.2) async -> (ip: String, ms: Int)? {
        guard let ip = gatewayIPv4() else { return nil }
        let ports: [UInt16] = [80, 443, 22, 8080]
        for port in ports {
            if let ms = await tcpLatency(host: ip, port: port, timeout: timeout) {
                return (ip, ms)
            }
        }
        return nil
    }

    // MARK: - TCP 时延

    /// TCP 握手往返时延（毫秒）。连通返回 ms，不通返回 nil。
    static func tcpLatency(host: String, port: UInt16, timeout: TimeInterval = 2.0) async -> Int? {
        if host.isEmpty { return nil }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return nil }
        let start = DispatchTime.now().uptimeNanoseconds
        let queue = DispatchQueue(label: "tsmate.probe")
        let latch = ProbeLatch()

        return await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            let conn = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)

            func finish(_ value: Int?) {
                queue.async {
                    if latch.claim() {
                        conn.cancel()
                        continuation.resume(returning: value)
                    }
                }
            }

            conn.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    let ms = Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                    finish(ms)
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    /// 多次探测：返回中位时延与丢包率
    static func probe(host: String, port: UInt16, attempts: Int = 3, timeout: TimeInterval = 2.0) async -> (ms: Int?, loss: Double) {
        guard !host.isEmpty else { return (nil, 1.0) }
        var samples: [Int] = []
        var failures = 0
        for _ in 0..<attempts {
            if let value = await tcpLatency(host: host, port: port, timeout: timeout) {
                samples.append(value)
            } else {
                failures += 1
            }
        }
        if samples.isEmpty { return (nil, 1.0) }
        samples.sort()
        let median = samples[samples.count / 2]
        return (median, Double(failures) / Double(attempts))
    }

    // MARK: - DNS

    /// 解析 MagicDNS 名称（官方 Tailscale App 在后台时 *.ts.net 可解析）
    static func dnsResolve(_ host: String) async -> String? {
        let text = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let box = DNSBox()

        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                var hints = addrinfo()
                hints.ai_flags = AI_ADDRCONFIG
                hints.ai_family = AF_UNSPEC
                hints.ai_socktype = SOCK_STREAM
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(text, nil, &hints, &result)
                if status == 0, let first = result {
                    var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(first.pointee.ai_addr,
                                   first.pointee.ai_addrlen,
                                   &buffer,
                                   socklen_t(buffer.count),
                                   nil,
                                   0,
                                   NI_NUMERICHOST) == 0 {
                        box.value = String(cString: buffer)
                    }
                    freeaddrinfo(result)
                }
                continuation.resume(returning: box.value)
            }
        }
    }
}

/// DNS 解析结果容器（避免跨线程改写局部变量）
private final class DNSBox {
    var value: String?
}

/// 保证 continuation 只恢复一次
private final class ProbeLatch {
    private var used = false
    private let lock = NSLock()

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
