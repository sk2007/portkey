import SwiftUI

public struct DormantPortRowView: View {
    public let status: DormantPortStatus
    public let onKillActive: () -> Void
    public let onDeletePreset: () -> Void
    
    @State private var isHovering: Bool = false
    
    public init(
        status: DormantPortStatus,
        onKillActive: @escaping () -> Void,
        onDeletePreset: @escaping () -> Void
    ) {
        self.status = status
        self.onKillActive = onKillActive
        self.onDeletePreset = onDeletePreset
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Status Circle Indicator
            Circle()
                .fill(status.isActive ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(status.isActive ? Color.green.opacity(0.4) : Color.clear, lineWidth: 3)
                        .scaleEffect(status.isActive ? 1.4 : 1.0)
                )
            
            // Port Number
            Text(verbatim: ":\(status.preset.port)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(minWidth: 55, alignment: .leading)
            
            // Preset Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(status.preset.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let desc = status.preset.description, !desc.isEmpty {
                        Text("• \(desc)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 6) {
                    if status.isActive, let activeItem = status.activePortItem {
                        StatusBadge(
                            text: "RUNNING (\(activeItem.processName) - PID \(activeItem.pid))",
                            systemImage: "bolt.fill",
                            foregroundColor: .green,
                            backgroundColor: Color.green.opacity(0.12)
                        )
                    } else {
                        StatusBadge(
                            text: "AVAILABLE / DORMANT",
                            systemImage: "checkmark.circle",
                            foregroundColor: .secondary,
                            backgroundColor: Color(nsColor: .quaternaryLabelColor)
                        )
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 4) {
                if status.isActive {
                    Button(action: {
                        if let url = URL(string: "http://localhost:\(status.preset.port)") {
                            ProcessManager.shared.openURL(url)
                        }
                    }) {
                        Image(systemName: "safari")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Open http://localhost:\(status.preset.port)")
                    
                    Button(action: onKillActive) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Free port (Kill running process)")
                }
                
                if status.preset.isCustom {
                    Button(action: onDeletePreset) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Delete preset")
                }
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
    }
}
