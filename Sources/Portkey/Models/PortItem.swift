import Foundation
import AppKit

public enum TransportProtocol: String, Codable, CaseIterable, Sendable {
    case tcp = "TCP"
    case udp = "UDP"
}

public enum IPVersion: String, Codable, CaseIterable, Sendable {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
}

public enum ProcessCategory: String, Codable, CaseIterable, Sendable {
    case webDev = "Web & Dev Server"
    case database = "Database"
    case container = "Container / Proxy"
    case system = "macOS System"
    case other = "Other"
    
    public var iconName: String {
        switch self {
        case .webDev: return "chevron.left.forwardslash.chevron.right"
        case .database: return "cylinder.split.1x2"
        case .container: return "shippingbox"
        case .system: return "apple.logo"
        case .other: return "network"
        }
    }
}

public struct PortItem: Identifiable, Hashable, Sendable {
    public var id: String {
        "\(pid)-\(port)-\(protocolType.rawValue)-\(bindAddress)"
    }
    
    public let port: Int
    public let protocolType: TransportProtocol
    public let ipVersion: IPVersion
    public let bindAddress: String
    public let pid: pid_t
    public let processName: String
    public let processPath: String?
    public let commandLine: String?
    public let user: String?
    public let isSystemProcess: Bool
    public let workingDirectory: String?
    public let discoveredAt: Date
    public var isFavorite: Bool
    
    public init(
        port: Int,
        protocolType: TransportProtocol = .tcp,
        ipVersion: IPVersion = .ipv4,
        bindAddress: String,
        pid: pid_t,
        processName: String,
        processPath: String? = nil,
        commandLine: String? = nil,
        user: String? = nil,
        isSystemProcess: Bool = false,
        workingDirectory: String? = nil,
        discoveredAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.port = port
        self.protocolType = protocolType
        self.ipVersion = ipVersion
        self.bindAddress = bindAddress
        self.pid = pid
        self.processName = processName
        self.processPath = processPath
        self.commandLine = commandLine
        self.user = user
        self.isSystemProcess = isSystemProcess
        self.workingDirectory = workingDirectory
        self.discoveredAt = discoveredAt
        self.isFavorite = isFavorite
    }
    
    public var isLocalhostOnly: Bool {
        bindAddress == "127.0.0.1" || bindAddress == "::1" || bindAddress.lowercased() == "localhost"
    }
    
    public var isWildcard: Bool {
        bindAddress == "*" || bindAddress == "0.0.0.0" || bindAddress == "::"
    }
    
    public var displayAddress: String {
        if isLocalhostOnly {
            return "localhost"
        } else if isWildcard {
            return "0.0.0.0 (All Interfaces)"
        } else {
            return bindAddress
        }
    }
    
    public var formattedPort: String {
        ":\(port)"
    }
    
    public var browserURL: URL? {
        if isLocalhostOnly || isWildcard {
            return URL(string: "http://localhost:\(port)")
        } else {
            return URL(string: "http://\(bindAddress):\(port)")
        }
    }
    
    public var httpsBrowserURL: URL? {
        if isLocalhostOnly || isWildcard {
            return URL(string: "https://localhost:\(port)")
        } else {
            return URL(string: "https://\(bindAddress):\(port)")
        }
    }
    
    /// Determines whether the process was instantiated by a developer (CLI, scripts, npm, python, etc.)
    public var isDeveloperInstantiated: Bool {
        if isSystemProcess {
            return false
        }
        
        let lowerName = processName.lowercased()
        let lowerCmd = (commandLine ?? "").lowercased()
        let lowerPath = (processPath ?? "").lowercased()
        let fullCheck = "\(lowerName) \(lowerCmd)"
        
        // 1. Known developer runtimes, interpreters, and package managers
        let devRuntimes = [
            "node", "npm", "npx", "pnpm", "yarn", "bun", "deno",
            "vite", "next", "next-server", "turbo", "webpack", "rollup", "esbuild", "nodemon", "ts-node", "tsx",
            "python", "python3", "python3.10", "python3.11", "python3.12", "python3.13", "python3.9", "python3.8",
            "uvicorn", "gunicorn", "flask", "fastapi", "django", "celery", "jupyter", "streamlit", "gradio", "hypercorn",
            "ruby", "rails", "puma", "sidekiq", "unicorn", "rackup", "falcon",
            "go", "air", "gin", "fiber",
            "cargo", "cargo-watch", "rustc",
            "php", "artisan", "symfony",
            "java", "gradle", "mvn", "sbt", "quarkus",
            "mix", "elixir", "phoenix", "iex",
            "dotnet", "csharp",
            "agy", "antigravity"
        ]
        
        for runtime in devRuntimes {
            if lowerName == runtime || lowerName.hasPrefix("\(runtime)-") || lowerName.hasPrefix("\(runtime).") {
                return true
            }
        }
        
        // 2. Dev command line patterns (e.g. "npm run dev", "python3 app.py", "uvicorn main:app", etc.)
        let devCmdKeywords = [
            "run dev", "npm run", "pnpm run", "yarn dev", "bun run", "bun dev", "npx ",
            "app.py", "main.py", "server.py", "manage.py", "uvicorn", "gunicorn", "flask run",
            "next dev", "vite", "ts-node", "nodemon", "cargo run", "go run",
            "http.server", "manage.py runserver", "start:dev", "start:debug",
            ".js", ".ts", ".py", ".rb", ".go", ".rs", ".php", ".mjs", ".cjs"
        ]
        
        for kw in devCmdKeywords {
            if fullCheck.contains(kw) {
                return true
            }
        }
        
        // 3. User directory execution environments (e.g. ~/.nvm, ~/.pyenv, ~/.cargo, virtualenvs, local node_modules)
        if lowerPath.hasPrefix("/users/") {
            let isUserDevEnv = lowerPath.contains("/.nvm/") ||
                               lowerPath.contains("/.pyenv/") ||
                               lowerPath.contains("/.cargo/") ||
                               lowerPath.contains("/.bun/") ||
                               lowerPath.contains("/.asdf/") ||
                               lowerPath.contains("/.local/") ||
                               lowerPath.contains("/venv/") ||
                               lowerPath.contains("/.venv/") ||
                               lowerPath.contains("/env/") ||
                               lowerPath.contains("/node_modules/") ||
                               lowerPath.contains("/target/") ||
                               lowerPath.contains("/build/") ||
                               lowerPath.contains("/dist/")
            if isUserDevEnv {
                return true
            }
        }
        
        return false
    }

    public var category: ProcessCategory {
        if isSystemProcess {
            return .system
        }
        
        let lowerName = processName.lowercased()
        let lowerCmd = (commandLine ?? "").lowercased()
        let fullCheck = "\(lowerName) \(lowerCmd)"
        
        // Databases
        if fullCheck.contains("postgres") || fullCheck.contains("psql") ||
           fullCheck.contains("mysqld") || fullCheck.contains("mariadb") ||
           fullCheck.contains("redis") || fullCheck.contains("mongo") ||
           fullCheck.contains("clickhouse") || fullCheck.contains("cassandra") ||
           fullCheck.contains("elastic") || fullCheck.contains("kafka") ||
           [5432, 3306, 6379, 27017, 9200, 9092].contains(port) {
            return .database
        }
        
        // Containers / Proxies
        if fullCheck.contains("docker") || fullCheck.contains("colima") ||
           fullCheck.contains("podman") || fullCheck.contains("containerd") ||
           fullCheck.contains("traefik") || fullCheck.contains("caddy") ||
           fullCheck.contains("nginx") || fullCheck.contains("envoy") {
            return .container
        }
        
        // Web / Dev servers
        if isDeveloperInstantiated ||
           fullCheck.contains("node") || fullCheck.contains("bun") ||
           fullCheck.contains("deno") || fullCheck.contains("next") ||
           fullCheck.contains("vite") || fullCheck.contains("react") ||
           fullCheck.contains("vue") || fullCheck.contains("nuxt") ||
           fullCheck.contains("python") || fullCheck.contains("uvicorn") ||
           fullCheck.contains("gunicorn") || fullCheck.contains("flask") ||
           fullCheck.contains("fastapi") || fullCheck.contains("django") ||
           fullCheck.contains("ruby") || fullCheck.contains("rails") ||
           fullCheck.contains("go") || fullCheck.contains("rust") ||
           fullCheck.contains("cargo") || fullCheck.contains("spring") ||
           fullCheck.contains("java") || fullCheck.contains("php") ||
           fullCheck.contains("artisan") || fullCheck.contains("agy") {
            return .webDev
        }
        
        // Check system process names
        let systemNames = ["rapportd", "controlcenter", "commcenter", "launchd", "mdnsresponder", "cupsd", "sharingd", "airportd"]
        if systemNames.contains(lowerName) {
            return .system
        }
        
        return .other
    }
}
