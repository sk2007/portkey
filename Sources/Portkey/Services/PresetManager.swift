import Foundation

public struct DormantPortStatus: Identifiable, Hashable, Sendable {
    public var id: String { "\(preset.id)-\(isActive)" }
    public let preset: PortPreset
    public let isActive: Bool
    public let activePortItem: PortItem?
    
    public init(preset: PortPreset, isActive: Bool, activePortItem: PortItem?) {
        self.preset = preset
        self.isActive = isActive
        self.activePortItem = activePortItem
    }
}

@MainActor
public final class PresetManager: ObservableObject {
    public static let shared = PresetManager()
    
    @Published public private(set) var presets: [PortPreset] = []
    
    private let userDefaultsKey = "portkey_user_presets"
    
    public init() {
        loadPresets()
    }
    
    public func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([PortPreset].self, from: data) {
            self.presets = decoded
        } else {
            self.presets = PortPreset.defaultPresets
            savePresets()
        }
    }
    
    public func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    public func addPreset(name: String, port: Int, protocolType: TransportProtocol = .tcp, expectedProcess: String? = nil, description: String? = nil) {
        let newPreset = PortPreset(
            name: name,
            port: port,
            protocolType: protocolType,
            expectedProcess: expectedProcess,
            description: description,
            isCustom: true
        )
        presets.append(newPreset)
        savePresets()
    }
    
    public func removePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        savePresets()
    }
    
    public func resetToDefaults() {
        self.presets = PortPreset.defaultPresets
        savePresets()
    }
    
    /// Evaluates preset status against current active listening ports
    public func evaluateDormantStatus(activePorts: [PortItem]) -> [DormantPortStatus] {
        let activeMap = Dictionary(grouping: activePorts, by: { $0.port })
        
        return presets.map { preset in
            if let matchedItems = activeMap[preset.port], let firstMatch = matchedItems.first {
                return DormantPortStatus(preset: preset, isActive: true, activePortItem: firstMatch)
            } else {
                return DormantPortStatus(preset: preset, isActive: false, activePortItem: nil)
            }
        }.sorted { (a, b) -> Bool in
            // Active first, then by port number
            if a.isActive != b.isActive {
                return a.isActive && !b.isActive
            }
            return a.preset.port < b.preset.port
        }
    }
}
