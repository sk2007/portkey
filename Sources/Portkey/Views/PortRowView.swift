import SwiftUI

public struct PortRowView: View {
    public let item: PortItem
    public let onKill: () -> Void
    public let onToggleFavorite: () -> Void
    
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false
    @State private var isKilling: Bool = false
    @State private var showCopiedAlert: Bool = false
    
    public init(
        item: PortItem,
        onKill: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.item = item
        self.onKill = onKill
        self.onToggleFavorite = onToggleFavorite
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Favorite Star
                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundColor(item.isFavorite ? .yellow : (isHovering ? .secondary : .clear))
                }
                .buttonStyle(.plain)
                .help(item.isFavorite ? "Remove from favorites" : "Add to favorites")
                
                // Category Icon
                Image(systemName: item.category.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(categoryColor(item.category))
                    .frame(width: 22, height: 22)
                    .background(categoryColor(item.category).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                // Port Number
                Text(":\(item.port)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minWidth: 55, alignment: .leading)
                
                // Process Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(item.processName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("PID \(item.pid)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        ProtocolBadge(protocolType: item.protocolType)
                        AddressBadge(
                            address: item.bindAddress,
                            isLocalhost: item.isLocalhostOnly,
                            isWildcard: item.isWildcard
                        )
                    }
                }
                
                Spacer()
                
                // Quick Action Buttons
                HStack(spacing: 4) {
                    // Browser Open Button (if web/dev server or general port)
                    if let browserURL = item.browserURL {
                        Button(action: {
                            ProcessManager.shared.openURL(browserURL)
                        }) {
                            Image(systemName: "safari")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Open in Browser (\(browserURL.absoluteString))")
                    }
                    
                    // Copy URL / Port Button
                    Menu {
                        if let browserURL = item.browserURL {
                            Button("Copy URL: \(browserURL.absoluteString)") {
                                ProcessManager.shared.copyToClipboard(browserURL.absoluteString)
                            }
                        }
                        Button("Copy Port: \(item.port)") {
                            ProcessManager.shared.copyToClipboard(String(item.port))
                        }
                        Button("Copy PID: \(item.pid)") {
                            ProcessManager.shared.copyToClipboard(String(item.pid))
                        }
                        Button("Copy Kill Command: kill -9 \(item.pid)") {
                            ProcessManager.shared.copyToClipboard("kill -9 \(item.pid)")
                        }
                        if let cmd = item.commandLine {
                            Button("Copy Full Command") {
                                ProcessManager.shared.copyToClipboard(cmd)
                            }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 24, height: 24)
                    .help("Copy details")
                    
                    // Expand/Details toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(isExpanded ? .accentColor : .secondary)
                            .frame(width: 24, height: 24)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle details")
                    
                    // Kill Process Button
                    Button(action: {
                        isKilling = true
                        onKill()
                    }) {
                        if isKilling {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                                .frame(width: 24, height: 24)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(5)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Kill Process (PID \(item.pid)) and Free Port \(item.port)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovering ? Color(nsColor: .selectedControlColor).opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovering = hovering
            }
            
            // Expanded Inspector Details Panel
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        if let path = item.processPath {
                            HStack(alignment: .top) {
                                Text("Executable:")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .leading)
                                
                                Text(path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                Button("Reveal") {
                                    ProcessManager.shared.revealInFinder(path: path)
                                }
                                .font(.system(size: 9))
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        
                        if let cmd = item.commandLine, !cmd.isEmpty {
                            HStack(alignment: .top) {
                                Text("Command:")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .leading)
                                
                                Text(cmd)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                            }
                        }
                        
                        HStack {
                            Text("Binding:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)
                            
                            Text("\(item.protocolType.rawValue) \(item.ipVersion.rawValue) on \(item.bindAddress):\(item.port)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            Spacer()
                            
                            Button(action: {
                                ProcessManager.shared.copyToClipboard("kill -9 \(item.pid)")
                            }) {
                                Label("Copy kill -9", systemImage: "terminal")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button(action: {
                                isKilling = true
                                onKill()
                            }) {
                                Label("Force Terminate", systemImage: "bolt.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)
            }
        }
    }
    
    private func categoryColor(_ cat: ProcessCategory) -> Color {
        switch cat {
        case .webDev: return .blue
        case .database: return .purple
        case .container: return .cyan
        case .system: return .gray
        case .other: return .teal
        }
    }
}
