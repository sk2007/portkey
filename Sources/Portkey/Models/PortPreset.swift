import Foundation

public struct PortPreset: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var port: Int
    public var protocolType: TransportProtocol
    public var expectedProcess: String?
    public var description: String?
    public var isCustom: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        port: Int,
        protocolType: TransportProtocol = .tcp,
        expectedProcess: String? = nil,
        description: String? = nil,
        isCustom: Bool = true
    ) {
        self.id = id
        self.name = name
        self.port = port
        self.protocolType = protocolType
        self.expectedProcess = expectedProcess
        self.description = description
        self.isCustom = isCustom
    }
    
    public static let defaultPresets: [PortPreset] = [
        PortPreset(name: "React / Next.js / Vite", port: 3000, expectedProcess: "node", description: "Standard React Next.js or Vite dev server", isCustom: false),
        PortPreset(name: "Alternative Dev Server", port: 3001, expectedProcess: "node", description: "Secondary Node/Vite port", isCustom: false),
        PortPreset(name: "Angular / Ember", port: 4200, expectedProcess: "node", description: "Angular CLI dev server", isCustom: false),
        PortPreset(name: "Vite Dev Server", port: 5173, expectedProcess: "node", description: "Default Vite dev server", isCustom: false),
        PortPreset(name: "PostgreSQL Database", port: 5432, expectedProcess: "postgres", description: "Postgres relational database", isCustom: false),
        PortPreset(name: "Redis Cache", port: 6379, expectedProcess: "redis-server", description: "In-memory data store", isCustom: false),
        PortPreset(name: "FastAPI / Django", port: 8000, expectedProcess: "python", description: "Python web application server", isCustom: false),
        PortPreset(name: "HTTP / Web Proxy / Alt", port: 8080, expectedProcess: nil, description: "Common alternative HTTP port", isCustom: false),
        PortPreset(name: "MySQL / MariaDB", port: 3306, expectedProcess: "mysqld", description: "MySQL database service", isCustom: false),
        PortPreset(name: "MongoDB Database", port: 27017, expectedProcess: "mongod", description: "NoSQL document database", isCustom: false),
        PortPreset(name: "Elasticsearch", port: 9200, expectedProcess: "java", description: "Search and analytics engine", isCustom: false)
    ]
}
