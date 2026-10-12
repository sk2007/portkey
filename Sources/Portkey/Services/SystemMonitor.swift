import Foundation
import Darwin

@MainActor
final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    @Published private(set) var usedMemoryBytes: UInt64 = 0
    @Published private(set) var totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    @Published private(set) var downloadBytesPerSecond: UInt64 = 0
    @Published private(set) var uploadBytesPerSecond: UInt64 = 0
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var thermalState = ProcessInfo.processInfo.thermalState

    private var timer: Timer?
    private var lastNetworkTotals: (received: UInt64, sent: UInt64)?
    private var lastCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    private init() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        sampleMemory()
        sampleNetwork()
        sampleCPU()
        thermalState = ProcessInfo.processInfo.thermalState
    }

    private func sampleMemory() {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(statistics.active_count)
        let wired = UInt64(statistics.wire_count)
        let compressed = UInt64(statistics.compressor_page_count)
        usedMemoryBytes = (active + wired + compressed) * pageSize
    }

    private func sampleNetwork() {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let first = addressList else { return }
        defer { freeifaddrs(addressList) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var current = first
        repeat {
            let interface = current.pointee
            if let address = interface.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee,
               (Int32(interface.ifa_flags) & (IFF_LOOPBACK | IFF_UP)) == IFF_UP {
                received += UInt64(data.ifi_ibytes)
                sent += UInt64(data.ifi_obytes)
            }
            guard let next = interface.ifa_next else { break }
            current = next
        } while true

        if let previous = lastNetworkTotals {
            downloadBytesPerSecond = received >= previous.received ? received - previous.received : 0
            uploadBytesPerSecond = sent >= previous.sent ? sent - previous.sent : 0
        }
        lastNetworkTotals = (received, sent)
    }

    private func sampleCPU() {
        var cpuInfo: processor_info_array_t?
        var processorCount = natural_t()
        var infoCount = mach_msg_type_number_t()
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &cpuInfo, &infoCount)
        guard result == KERN_SUCCESS, let cpuInfo else { return }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)) }

        let ticks = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(processorCount)) { pointer in
            (0..<Int(processorCount)).reduce(into: (user: UInt64(0), system: UInt64(0), idle: UInt64(0), nice: UInt64(0))) { totals, index in
                let load = pointer[index].cpu_ticks
                totals.user += UInt64(load.0)
                totals.system += UInt64(load.1)
                totals.idle += UInt64(load.2)
                totals.nice += UInt64(load.3)
            }
        }

        if let previous = lastCPUTicks {
            let user = ticks.user - previous.user
            let system = ticks.system - previous.system
            let idle = ticks.idle - previous.idle
            let nice = ticks.nice - previous.nice
            let total = user + system + idle + nice
            cpuUsage = total > 0 ? Double(user + system + nice) / Double(total) : 0
        }
        lastCPUTicks = ticks
    }
}

extension SystemMonitor {
    var thermalDescription: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
