import Foundation

public enum PortCategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case devServers = "Dev Servers"
    case databases = "Databases"
    case system = "System"
    case favorites = "Favorites"
    case dormant = "Dormant / Presets"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .devServers: return "chevron.left.forwardslash.chevron.right"
        case .databases: return "cylinder.split.1x2"
        case .system: return "apple.logo"
        case .favorites: return "star.fill"
        case .dormant: return "clock.arrow.circlepath"
        }
    }
}

public enum PortSortOption: String, CaseIterable, Identifiable, Sendable {
    case portAscending = "Port (Low to High)"
    case portDescending = "Port (High to Low)"
    case processName = "Process Name"
    case pid = "Process ID (PID)"
    
    public var id: String { rawValue }
}
