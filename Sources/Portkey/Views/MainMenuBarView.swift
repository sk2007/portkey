import SwiftUI
import AppKit

public struct MainMenuBarView: View {
    @ObservedObject private var scanner = PortScanner.shared
    @ObservedObject private var presetManager = PresetManager.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    
    @AppStorage("portkey_hide_system_processes") private var hideSystemProcesses: Bool = false
    @AppStorage("portkey_confirm_kill") private var confirmKill: Bool = false
    
    @State private var searchText: String = ""
    @State private var selectedTab: PortCategoryFilter = .all
    @State private var onlyDeveloperProcesses: Bool = false
    @State private var sortOption: PortSortOption = .portAscending
    @State private var currentScreen: ActiveNavigationScreen = .main
    @State private var processToKill: PortItem? = nil
    @State private var showKillAllConfirmation: Bool = false
    @State private var toastMessage: String? = nil
    @State private var selectedPage: MainPage = .ports

    private enum MainPage: String, CaseIterable {
        case ports = "Ports"
        case monitor = "Monitor"
    }
    
    public enum ActiveNavigationScreen {
        case main
        case settings
        case addPreset
    }
    
    public init() {}
    
    // Filtered active ports
    private var filteredPorts: [PortItem] {
        var items = scanner.activePorts
        
        // Hide system processes if user setting is on and not on System tab
        if hideSystemProcesses && selectedTab != .system {
            items = items.filter { !$0.isSystemProcess }
        }
        
        // Filter by dev-instantiated toggle button
        if onlyDeveloperProcesses {
            items = items.filter { $0.isDeveloperInstantiated }
        }
        
        // Category filtering
        switch selectedTab {
        case .all:
            break
        case .devProcesses:
            items = items.filter { $0.isDeveloperInstantiated }
        case .devServers:
            items = items.filter { $0.category == .webDev || $0.category == .container }
        case .databases:
            items = items.filter { $0.category == .database }
        case .system:
            items = items.filter { $0.isSystemProcess }
        case .favorites:
            items = items.filter { $0.isFavorite }
        case .dormant:
            break // handled separately
        }
        
        // Search text filtering
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
            items = items.filter { item in
                String(item.port).contains(query) ||
                item.processName.lowercased().contains(query) ||
                (item.commandLine ?? "").lowercased().contains(query) ||
                item.bindAddress.lowercased().contains(query) ||
                String(item.pid).contains(query)
            }
        }
        
        // Sorting
        switch sortOption {
        case .portAscending:
            items.sort { $0.port < $1.port }
        case .portDescending:
            items.sort { $0.port > $1.port }
        case .processName:
            items.sort { $0.processName.lowercased() < $1.processName.lowercased() }
        case .pid:
            items.sort { $0.pid < $1.pid }
        }
        
        return items
    }
    
    private var dormantStatuses: [DormantPortStatus] {
        var statuses = presetManager.evaluateDormantStatus(activePorts: scanner.activePorts)
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
            statuses = statuses.filter { status in
                String(status.preset.port).contains(query) ||
                status.preset.name.lowercased().contains(query) ||
                (status.preset.description ?? "").lowercased().contains(query) ||
                (status.preset.expectedProcess ?? "").lowercased().contains(query)
            }
        }
        return statuses
    }
    
    public var body: some View {
        ZStack {
            switch currentScreen {
            case .main:
                mainView
                    .transition(.opacity)
            case .settings:
                SettingsView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentScreen = .main
                    }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            case .addPreset:
                AddPresetView(
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            currentScreen = .main
                        }
                    },
                    onAdd: { name, port, proto, proc, desc in
                        presetManager.addPreset(name: name, port: port, protocolType: proto, expectedProcess: proc, description: desc)
                        withAnimation(.easeInOut(duration: 0.15)) {
                            currentScreen = .main
                        }
                        showToast("Preset added for :\(port)")
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
        .frame(width: 440, height: 570)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Kill Process?", isPresented: Binding(
            get: { processToKill != nil },
            set: { if !$0 { processToKill = nil } }
        )) {
            if let item = processToKill {
                Button("Kill Process (PID \(item.pid))", role: .destructive) {
                    executeKill(item: item)
                }
                Button("Cancel", role: .cancel) {
                    processToKill = nil
                }
            }
        } message: {
            if let item = processToKill {
                Text(verbatim: "Are you sure you want to terminate \(item.processName) (PID \(item.pid)) on port \(item.port)?")
            }
        }
        .alert("Kill All Dev Servers?", isPresented: $showKillAllConfirmation) {
            Button("Kill All", role: .destructive) {
                killAllDevServers()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will send termination signals to all running development and container servers shown in the list.")
        }
        .overlay(alignment: .top) {
            if let toast = toastMessage {
                Text(toast)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.85)))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            pagePicker
            Divider()

            if selectedPage == .ports {
                searchAndFilterBar
                Divider()
                mainContentList
                Divider()
                footerView
            } else {
                monitorView
            }
        }
    }

    private var pagePicker: some View {
        HStack(spacing: 4) {
            ForEach(MainPage.allCases, id: \.self) { page in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { selectedPage = page }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: page == .ports ? "point.3.filled.connected.trianglepath.dotted" : "gauge.with.dots.needle.67percent")
                        Text(page.rawValue)
                    }
                    .font(.system(size: 11, weight: selectedPage == page ? .semibold : .medium))
                    .foregroundColor(selectedPage == page ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(selectedPage == page ? Color(nsColor: .windowBackgroundColor) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))
    }

    private var monitorView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("System monitor")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Live resource and connection activity")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 2)

                HStack(spacing: 9) {
                    monitorMetric(title: "MEMORY", value: byteCount(monitor.usedMemoryBytes), detail: "of \(byteCount(monitor.totalMemoryBytes))", icon: "memorychip", tint: .purple, progress: memoryProgress)
                    monitorMetric(title: "CPU", value: "\(Int(monitor.cpuUsage * 100))%", detail: monitor.thermalDescription + " thermal", icon: "cpu", tint: .blue, progress: monitor.cpuUsage)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Connection speed", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("All active interfaces")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 0) {
                        networkRate(title: "DOWNLOAD", speed: monitor.downloadBytesPerSecond, icon: "arrow.down.circle.fill", tint: .cyan)
                        Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1, height: 34)
                        networkRate(title: "UPLOAD", speed: monitor.uploadBytesPerSecond, icon: "arrow.up.circle.fill", tint: .orange)
                    }
                    Text("Rates are sampled once per second from macOS interface counters.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Cooling", systemImage: "fanblades.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("NOT AVAILABLE")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.14))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    Text("macOS doesn’t provide a public fan control API. Portkey can’t safely read or change fan speeds on this Mac.")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var memoryProgress: Double {
        guard monitor.totalMemoryBytes > 0 else { return 0 }
        return min(1, Double(monitor.usedMemoryBytes) / Double(monitor.totalMemoryBytes))
    }

    private func monitorMetric(title: String, value: String, detail: String, icon: String, tint: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon).foregroundColor(tint)
                Spacer()
                Text(title).font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundColor(.secondary)
            }
            Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).contentTransition(.numericText())
            Text(detail).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
            ProgressView(value: progress).tint(tint).controlSize(.small)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func networkRate(title: String, speed: UInt64, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 17)).foregroundColor(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 8, weight: .bold)).tracking(0.55).foregroundColor(.secondary)
                Text("\(byteCount(speed))/s")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
        .padding(.trailing, 10)
        .padding(.leading, 4)
    }

    private func byteCount(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentColor)
            
            Text("Portkey")
                .font(.system(size: 14, weight: .bold))
            
            // Active ports count badge
            Text(verbatim: "\(scanner.activePorts.count) active")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .clipShape(Capsule())
            
            Spacer()
            
            // Manual Refresh
            Button(action: {
                Task {
                    await scanner.scan()
                    showToast("Ports refreshed")
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(scanner.isScanning ? .degrees(360) : .degrees(0))
                    .animation(scanner.isScanning ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: scanner.isScanning)
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Refresh Ports (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
            
            // Add Preset
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentScreen = .addPreset
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Add Port Preset")
            
            // Settings
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentScreen = (currentScreen == .settings ? .main : .settings)
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Preferences (⌘,)")
            .keyboardShortcut(",", modifiers: .command)
            
            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Quit Portkey (⌘Q)")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                SearchField(text: $searchText)
                
                // Dev-instantiated quick filter button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        onlyDeveloperProcesses.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 10))
                        Text("Dev Only")
                            .font(.system(size: 11, weight: onlyDeveloperProcesses ? .semibold : .regular))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .foregroundColor(onlyDeveloperProcesses ? .white : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(onlyDeveloperProcesses ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(onlyDeveloperProcesses ? Color.clear : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.8)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help(onlyDeveloperProcesses ? "Showing only dev-instantiated processes (Click to show all)" : "Filter to show only developer-instantiated processes (npm run dev, python app.py, vite, etc.)")
            }
            
            // Segmented Filter Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(PortCategoryFilter.allCases) { filter in
                        Button(action: { selectedTab = filter }) {
                            HStack(spacing: 4) {
                                Image(systemName: filter.iconName)
                                    .font(.system(size: 10))
                                Text(filter.rawValue)
                                    .font(.system(size: 11, weight: selectedTab == filter ? .semibold : .regular))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundColor(selectedTab == filter ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(selectedTab == filter ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Main Content List
    private var mainContentList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if selectedTab == .dormant {
                    // Presets / Dormant View
                    if dormantStatuses.isEmpty {
                        emptyStateView(text: "No presets found matching search.")
                    } else {
                        ForEach(dormantStatuses) { status in
                            DormantPortRowView(
                                status: status,
                                onKillActive: {
                                    if let item = status.activePortItem {
                                        handleKillRequest(for: item)
                                    }
                                },
                                onDeletePreset: {
                                    presetManager.removePreset(id: status.preset.id)
                                    showToast("Preset removed")
                                }
                            )
                        }
                    }
                } else {
                    // Active Ports View
                    if filteredPorts.isEmpty {
                        emptyStateView(text: searchText.isEmpty ? "No active listening ports found." : "No ports match '\(searchText)'.")
                    } else {
                        ForEach(filteredPorts) { item in
                            PortRowView(
                                item: item,
                                onKill: {
                                    handleKillRequest(for: item)
                                },
                                onToggleFavorite: {
                                    scanner.toggleFavorite(port: item.port)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
    
    private func emptyStateView(text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 30)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            if selectedTab == .dormant {
                Button("Add New Preset") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentScreen = .addPreset
                    }
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            // Auto refresh indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(scanner.autoRefreshEnabled ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                
                Text(verbatim: scanner.autoRefreshEnabled ? "Live (\(Int(scanner.refreshInterval))s)" : "Manual")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Bulk action: Kill All Dev Servers
            let devServers = filteredPorts.filter { $0.category == .webDev || $0.category == .container }
            if !devServers.isEmpty && selectedTab != .dormant {
                Button(action: { showKillAllConfirmation = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text(verbatim: "Kill Dev Servers (\(devServers.count))")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Actions
    private func handleKillRequest(for item: PortItem) {
        if confirmKill {
            processToKill = item
        } else {
            executeKill(item: item)
        }
    }
    
    private func executeKill(item: PortItem) {
        Task {
            let result = await ProcessManager.shared.killProcess(pid: item.pid)
            switch result {
            case .success:
                showToast("Freed port :\(item.port) (PID \(item.pid))")
                await scanner.scan()
            case .failure(let error):
                showToast("Error: \(error.localizedDescription)")
            }
            processToKill = nil
        }
    }
    
    private func killAllDevServers() {
        Task {
            let devServers = filteredPorts.filter { $0.category == .webDev || $0.category == .container }
            var killedCount = 0
            for item in devServers {
                let res = await ProcessManager.shared.killProcess(pid: item.pid)
                if case .success = res {
                    killedCount += 1
                }
            }
            showToast("Freed \(killedCount) dev server ports")
            await scanner.scan()
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }
}
