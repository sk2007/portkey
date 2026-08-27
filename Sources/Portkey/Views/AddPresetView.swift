import SwiftUI

public struct AddPresetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var portString: String = ""
    @State private var expectedProcess: String = ""
    @State private var description: String = ""
    @State private var protocolType: TransportProtocol = .tcp
    @State private var errorMessage: String? = nil
    
    public let onAdd: (String, Int, TransportProtocol, String?, String?) -> Void
    
    public init(onAdd: @escaping (String, Int, TransportProtocol, String?, String?) -> Void) {
        self.onAdd = onAdd
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Add Port Preset")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preset Name (e.g. FastAPI Backend)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Next.js Server, Postgres DB, etc.", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Port Number")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("3000", text: $portString)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Protocol")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $protocolType) {
                            Text("TCP").tag(TransportProtocol.tcp)
                            Text("UDP").tag(TransportProtocol.udp)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Expected Process Name (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("node, python, postgres, redis-server...", text: $expectedProcess)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Description / Notes (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Main API gateway server", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save Preset") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .padding(16)
        .frame(width: 360)
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
        dismiss()
    }
}
