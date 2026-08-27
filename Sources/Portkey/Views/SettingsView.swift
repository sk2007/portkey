import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    public var onDismiss: (() -> Void)? = nil
    
    @ObservedObject private var scanner = PortScanner.shared
    @ObservedObject private var presetManager = PresetManager.shared
    
    @AppStorage("portkey_hide_system_processes") private var hideSystemProcesses: Bool = false
    @AppStorage("portkey_confirm_kill") private var confirmKill: Bool = false
    @State private var launchAtLogin: Bool = ProcessManager.shared.isLaunchAtLoginEnabled
    @State private var showResetConfirmation: Bool = false
    @State private var resetToast: Bool = false
    
    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    private func close() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                Button(action: { close() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Back to Ports List (Esc)")
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                
                Text("Preferences")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                Button("Done") {
                    close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Section 1: Monitoring & Refresh
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PORT MONITORING")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-refresh active ports")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Continuously poll socket state in the background")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $scanner.autoRefreshEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                            
                            if scanner.autoRefreshEnabled {
                                Divider()
                                
                                HStack {
                                    Text("Refresh Interval:")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $scanner.refreshInterval) {
                                        Text("1s").tag(1.0)
                                        Text("2s").tag(2.0)
                                        Text("5s").tag(5.0)
                                        Text("10s").tag(10.0)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 180)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                    }
                    
                    // Section 2: Display & Safety
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BEHAVIOR & SAFETY")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Hide macOS system daemons (rapportd, etc.) by default", isOn: $hideSystemProcesses)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                            
                            Divider()
                            
                            Toggle("Prompt confirmation before killing processes", isOn: $confirmKill)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                            
                            Divider()
                            
                            Toggle("Launch Portkey automatically at Login", isOn: Binding(
                                get: { launchAtLogin },
                                set: { newValue in
                                    launchAtLogin = newValue
                                    _ = ProcessManager.shared.setLaunchAtLogin(enabled: newValue)
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                    }
                    
                    // Section 3: Presets Management
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PORT PRESETS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reset Built-in Presets")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Restore standard presets (Next.js, Postgres, Redis, etc.)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Reset Defaults") {
                                    showResetConfirmation = true
                                }
                                .font(.system(size: 11))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            if showResetConfirmation {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("⚠️ This will restore standard presets and remove any custom ones.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                    
                                    HStack(spacing: 8) {
                                        Button("Confirm Reset", role: .destructive) {
                                            presetManager.resetToDefaults()
                                            showResetConfirmation = false
                                            resetToast = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                resetToast = false
                                            }
                                        }
                                        .font(.system(size: 10))
                                        .buttonStyle(.borderedProminent)
                                        .tint(.red)
                                        .controlSize(.small)
                                        
                                        Button("Cancel") {
                                            showResetConfirmation = false
                                        }
                                        .font(.system(size: 10))
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                            }
                            
                            if resetToast {
                                Text("✅ Presets restored to defaults!")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Portkey v1.0.0 • Made for Mac Developers")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Done") {
                    close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        }
        .frame(width: 440, height: 530)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
