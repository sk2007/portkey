import Foundation
import AppKit
import Darwin

@MainActor
public final class PortScanner: ObservableObject {
    public static let shared = PortScanner()
    
    @Published public private(set) var activePorts: [PortItem] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var lastScanTime: Date? = nil
    @Published public private(set) var errorMessage: String? = nil
    
    @Published public var autoRefreshEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(autoRefreshEnabled, forKey: "portkey_auto_refresh_enabled")
            restartTimer()
        }
    }
    
    @Published public var refreshInterval: TimeInterval = 2.0 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "portkey_refresh_interval")
            restartTimer()
        }
    }
    
    private var scanTask: Task<Void, Never>? = nil
    private var previousPortKeys: Set<String> = []
    private var favoritePorts: Set<Int> = []
    
    public init() {
        self.autoRefreshEnabled = UserDefaults.standard.object(forKey: "portkey_auto_refresh_enabled") as? Bool ?? true
        let savedInterval = UserDefaults.standard.double(forKey: "portkey_refresh_interval")
        self.refreshInterval = savedInterval > 0 ? savedInterval : 2.0
        
        loadFavorites()
        startPeriodicScan()
    }
    
    deinit {
        scanTask?.cancel()
    }
    
    public func loadFavorites() {
        if let savedFavs = UserDefaults.standard.array(forKey: "portkey_favorite_ports") as? [Int] {
            self.favoritePorts = Set(savedFavs)
        }
    }
    
    public func toggleFavorite(port: Int) {
        if favoritePorts.contains(port) {
            favoritePorts.remove(port)
        } else {
            favoritePorts.insert(port)
        }
        UserDefaults.standard.set(Array(favoritePorts), forKey: "portkey_favorite_ports")
        
        // Update current items
        activePorts = activePorts.map { item in
            var copy = item
            copy.isFavorite = favoritePorts.contains(item.port)
            return copy
        }
    }
    
    public func isFavorite(port: Int) -> Bool {
        favoritePorts.contains(port)
    }
    
    public func startPeriodicScan() {
        restartTimer()
    }
    
    public func stopPeriodicScan() {
        scanTask?.cancel()
        scanTask = nil
    }
    
    private func restartTimer() {
        scanTask?.cancel()
        guard autoRefreshEnabled else { return }
        
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scan()
                guard let self = self else { break }
                let interval = self.refreshInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    public func scan() async {
        guard !isScanning else { return }
        isScanning = true
        
        let favs = self.favoritePorts
        let result = await Task.detached(priority: .userInitiated) { () -> [PortItem] in
            return Self.performSystemPortScan(favorites: favs)
        }.value
        
        self.activePorts = result
        self.lastScanTime = Date()
        self.isScanning = false
        
        // Diffing detection
        let currentKeys = Set(result.map { "\($0.port)-\($0.processName)" })
        self.previousPortKeys = currentKeys
    }
    
    // MARK: - Core System Scanning (Runs in background)
    
    private nonisolated static func performSystemPortScan(favorites: Set<Int>) -> [PortItem] {
        // 1. Fetch full command line args for all processes
        let commandMap = fetchProcessCommands()
        
        // 2. Run lsof for TCP LISTEN sockets
        let tcpOutput = runLsof(arguments: ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-F", "pcuftn"])
        var items = parseLsofOutput(rawOutput: tcpOutput, defaultProtocol: .tcp, commandMap: commandMap, favorites: favorites)
        
        // 3. Run lsof for UDP sockets
        let udpOutput = runLsof(arguments: ["-iUDP", "-P", "-n", "-F", "pcuftn"])
        let udpItems = parseLsofOutput(rawOutput: udpOutput, defaultProtocol: .udp, commandMap: commandMap, favorites: favorites)
        
        items.append(contentsOf: udpItems)
        
        // 4. Deduplicate entries: if same PID and same Port and same Protocol, combine (e.g. IPv4 and IPv6)
        var uniqueItemsMap: [String: PortItem] = [:]
        for item in items {
            let key = "\(item.pid):\(item.port):\(item.protocolType.rawValue)"
            if let existing = uniqueItemsMap[key] {
                // If existing is IPv6 and new is IPv4 (or vice versa), prioritize standard 127.0.0.1/0.0.0.0 presentation
                if existing.bindAddress.contains("::") && !item.bindAddress.contains("::") {
                    uniqueItemsMap[key] = item
                }
            } else {
                uniqueItemsMap[key] = item
            }
        }
        
        // 5. Sort by Port number ascending by default
        return uniqueItemsMap.values.sorted { $0.port < $1.port }
    }
    
    private nonisolated static func runLsof(arguments: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Silence stderr
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        } catch {
            return ""
        }
    }
    
    private nonisolated static func fetchProcessCommands() -> [pid_t: String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-A", "-o", "pid=,args="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        var map: [pid_t: String] = [:]
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
            for line in output.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let firstSpace = trimmed.firstIndex(of: " ") {
                    let pidStr = String(trimmed[..<firstSpace])
                    let args = String(trimmed[trimmed.index(after: firstSpace)...])
                    if let pid = pid_t(pidStr) {
                        map[pid] = args
                    }
                }
            }
        } catch {
            // Ignore error
        }
        return map
    }
    
    private nonisolated static func parseLsofOutput(
        rawOutput: String,
        defaultProtocol: TransportProtocol,
        commandMap: [pid_t: String],
        favorites: Set<Int>
    ) -> [PortItem] {
        var items: [PortItem] = []
        
        var currentPid: pid_t?
        var currentCommand: String = ""
        var currentUser: String = ""
        var currentType: IPVersion = .ipv4
        
        let lines = rawOutput.split(separator: "\n", omittingEmptySubsequences: true)
        
        for line in lines {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            
            switch prefix {
            case "p":
                currentPid = pid_t(value)
            case "c":
                currentCommand = value
            case "u":
                currentUser = value
            case "t":
                if value.lowercased().contains("ipv6") {
                    currentType = .ipv6
                } else {
                    currentType = .ipv4
                }
            case "n":
                guard let pid = currentPid else { continue }
                
                // Example names:
                // *:3000
                // 127.0.0.1:5432
                // [::1]:6379
                // [2607:fb90:...]:5060
                // *:61472
                // 192.168.1.10:8080
                
                if let (address, port) = parseAddressAndPort(name: value) {
                    // Skip invalid ports
                    guard port > 0 && port <= 65535 else { continue }
                    
                    // Resolve process path via Darwin proc_pidpath
                    let procPath = getProcessPath(pid: pid)
                    let isSystem = isSystemPath(procPath) || isSystemCommand(currentCommand)
                    let fullCmd = commandMap[pid] ?? currentCommand
                    
                    let item = PortItem(
                        port: port,
                        protocolType: defaultProtocol,
                        ipVersion: currentType,
                        bindAddress: address,
                        pid: pid,
                        processName: currentCommand.isEmpty ? "PID \(pid)" : currentCommand,
                        processPath: procPath,
                        commandLine: fullCmd,
                        user: currentUser,
                        isSystemProcess: isSystem,
                        workingDirectory: nil,
                        discoveredAt: Date(),
                        isFavorite: favorites.contains(port)
                    )
                    items.append(item)
                }
            default:
                break
            }
        }
        
        return items
    }
    
    private nonisolated static func parseAddressAndPort(name: String) -> (String, Int)? {
        // Strip any connection arrow (e.g. host:port->remote:port)
        let localPart = name.components(separatedBy: "->").first ?? name
        
        // Check for IPv6 bracket format: [::1]:8080 or [fe80::...]:80
        if localPart.hasPrefix("[") {
            if let closingBracket = localPart.firstIndex(of: "]") {
                let addr = String(localPart[localPart.index(after: localPart.startIndex)..<closingBracket])
                let remaining = localPart[closingBracket...]
                if let colon = remaining.firstIndex(of: ":") {
                    let portStr = String(remaining[remaining.index(after: colon)...])
                    if let port = Int(portStr) {
                        return (addr, port)
                    }
                }
            }
        }
        
        // Standard IPv4 or wildcard: *:3000 or 127.0.0.1:8080
        if let lastColon = localPart.lastIndex(of: ":") {
            let addr = String(localPart[..<lastColon])
            let portStr = String(localPart[localPart.index(after: lastColon)...])
            if let port = Int(portStr) {
                return (addr.isEmpty ? "*" : addr, port)
            }
        }
        
        return nil
    }
    
    private nonisolated static func getProcessPath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let len = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        if len > 0 {
            return String(cString: buffer)
        }
        return nil
    }
    
    private nonisolated static func isSystemPath(_ path: String?) -> Bool {
        guard let path = path else { return false }
        return path.hasPrefix("/System/") ||
               path.hasPrefix("/usr/libexec/") ||
               path.hasPrefix("/usr/sbin/") ||
               path.hasPrefix("/System/Library/") ||
               path.hasPrefix("/Library/Apple/")
    }
    
    private nonisolated static func isSystemCommand(_ cmd: String) -> Bool {
        let systemCommands = ["rapportd", "controlcenter", "commcenter", "launchd", "mdnsresponder", "cupsd", "sharingd", "airportd", "identityservicesd", "bluetoothd"]
        return systemCommands.contains(cmd.lowercased())
    }
}
