import SwiftUI

public struct AddPresetView: View {
    @Environment(\.dismiss) private var dismiss
    public var onDismiss: (() -> Void)? = nil
    
    @State private var name: String = ""
    @State private var portString: String = ""
    @State private var expectedProcess: String = ""
    @State private var description: String = ""
    @State private var protocolType: TransportProtocol = .tcp
    @State private var errorMessage: String? = nil
    
    public let onAdd: (String, Int, TransportProtocol, String?, String?) -> Void
    
    public init(
        onDismiss: (() -> Void)? = nil,
        onAdd: @escaping (String, Int, TransportProtocol, String?, String?) -> Void
    ) {
        self.onDismiss = onDismiss
        self.onAdd = onAdd
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
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                
                Text("Add Port Preset")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                Button("Cancel") {
                    close()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preset Name")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("e.g. FastAPI Backend, Next.js Server", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Port Number")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                TextField("3000", text: $portString)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Protocol")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $protocolType) {
                                    Text("TCP").tag(TransportProtocol.tcp)
                                    Text("UDP").tag(TransportProtocol.udp)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expected Process Name (Optional)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("e.g. node, python, redis-server", text: $expectedProcess)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description / Notes (Optional)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("e.g. Main API gateway server", text: $description)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                    
                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(error)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                    }
                }
                .padding(12)
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("Cancel") {
                    close()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Save Preset") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        }
        .frame(width: 440, height: 530)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a name for the preset."
            return
        }
        
        guard let port = Int(portString.trimmingCharacters(in: .whitespaces)), port > 0 && port <= 65535 else {
            errorMessage = "Please enter a valid port number (1-65535)."
            return
        }
        
        let proc = expectedProcess.trimmingCharacters(in: .whitespaces).isEmpty ? nil : expectedProcess.trimmingCharacters(in: .whitespaces)
        let desc = description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces)
        
        onAdd(name.trimmingCharacters(in: .whitespaces), port, protocolType, proc, desc)
        close()
    }
}
