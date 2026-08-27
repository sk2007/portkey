import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var scanner = PortScanner.shared
    @ObservedObject private var presetManager = PresetManager.shared
    
    @AppStorage("portkey_hide_system_processes") private var hideSystemProcesses: Bool = false
    @AppStorage("portkey_confirm_kill") private var confirmKill: Bool = false
    @State private var launchAtLogin: Bool = ProcessManager.shared.isLaunchAtLoginEnabled
    @State private var showResetAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Portkey Preferences")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                // Auto Refresh
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Auto-refresh active ports", isOn: $scanner.autoRefreshEnabled)
                        .toggleStyle(.switch)
                    
                    if scanner.autoRefreshEnabled {
                        HStack {
                            Text("Refresh Interval:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $scanner.refreshInterval) {
                                Text("1 second").tag(1.0)
                                Text("2 seconds").tag(2.0)
                                Text("5 seconds").tag(5.0)
                                Text("10 seconds").tag(10.0)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 130)
                        }
                        .padding(.leading, 20)
                    }
                }
                
                Divider()
                
                // Display preferences
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide macOS System Daemons (rapportd etc.) by default", isOn: $hideSystemProcesses)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                    
                    Toggle("Prompt before killing processes", isOn: $confirmKill)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                    
                    Toggle("Launch Portkey at Login", isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            _ = ProcessManager.shared.setLaunchAtLogin(enabled: newValue)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                }
                
                Divider()
                
                // Preset Management
                HStack {
                    Text("Presets Configuration:")
                        .font(.system(size: 12, weight: .medium))
                    
                    Spacer()
                    
                    Button("Reset Default Presets") {
                        showResetAlert = true
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Spacer()
            
            HStack {
                Text("Portkey v1.0.0 • Made for Mac Developers")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 380, height: 360)
        .alert("Reset Presets?", isPresented: $showResetAlert) {
            Button("Reset to Defaults", role: .destructive) {
                presetManager.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore the standard developer port presets (Next.js Postgres Redis etc.) and remove any custom additions.")
        }
    }
}
