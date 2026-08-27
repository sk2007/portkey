import XCTest
@testable import Portkey

final class PortkeyTests: XCTestCase {
    
    func testPortItemCategorization() {
        // Web / Dev Server
        let nodeItem = PortItem(
            port: 3000,
            bindAddress: "127.0.0.1",
            pid: 1234,
            processName: "node",
            commandLine: "node /app/server.js"
        )
        XCTAssertEqual(nodeItem.category, .webDev)
        XCTAssertTrue(nodeItem.isDeveloperInstantiated)
        XCTAssertTrue(nodeItem.isLocalhostOnly)
        XCTAssertFalse(nodeItem.isWildcard)
        XCTAssertEqual(nodeItem.browserURL?.absoluteString, "http://localhost:3000")
        
        let pythonItem = PortItem(
            port: 8000,
            bindAddress: "0.0.0.0",
            pid: 4567,
            processName: "python",
            commandLine: "python3 app.py"
        )
        XCTAssertEqual(pythonItem.category, .webDev)
        XCTAssertTrue(pythonItem.isDeveloperInstantiated)
        XCTAssertTrue(pythonItem.isWildcard)
        
        let npmItem = PortItem(
            port: 5173,
            bindAddress: "127.0.0.1",
            pid: 7890,
            processName: "node",
            commandLine: "npm run dev"
        )
        XCTAssertTrue(npmItem.isDeveloperInstantiated)
        
        // Database
        let postgresItem = PortItem(
            port: 5432,
            bindAddress: "0.0.0.0",
            pid: 5678,
            processName: "postgres",
            commandLine: "/usr/local/bin/postgres -D /data"
        )
        XCTAssertEqual(postgresItem.category, .database)
        XCTAssertTrue(postgresItem.isWildcard)
        
        let redisItem = PortItem(
            port: 6379,
            bindAddress: "127.0.0.1",
            pid: 9999,
            processName: "redis-server"
        )
        XCTAssertEqual(redisItem.category, .database)
        
        // Container
        let dockerItem = PortItem(
            port: 8080,
            bindAddress: "*",
            pid: 9101,
            processName: "docker-proxy",
            commandLine: "docker-proxy -proto tcp -host-ip 0.0.0.0"
        )
        XCTAssertEqual(dockerItem.category, .container)
        XCTAssertTrue(dockerItem.isWildcard)
        
        // System
        let systemItem = PortItem(
            port: 61472,
            bindAddress: "*",
            pid: 1353,
            processName: "rapportd",
            isSystemProcess: true
        )
        XCTAssertEqual(systemItem.category, .system)
        XCTAssertFalse(systemItem.isDeveloperInstantiated)
    }
    
    @MainActor
    func testDormantPortEvaluation() {
        let presetManager = PresetManager()
        
        // When port 3000 is active
        let active3000 = PortItem(
            port: 3000,
            bindAddress: "127.0.0.1",
            pid: 4321,
            processName: "node"
        )
        
        let statuses = presetManager.evaluateDormantStatus(activePorts: [active3000])
        
        // Find 3000 preset (should be active)
        let preset3000 = statuses.first { $0.preset.port == 3000 }
        XCTAssertNotNil(preset3000)
        XCTAssertTrue(preset3000?.isActive == true)
        XCTAssertEqual(preset3000?.activePortItem?.pid, 4321)
        
        // Find 5432 preset (should be dormant / inactive)
        let preset5432 = statuses.first { $0.preset.port == 5432 }
        XCTAssertNotNil(preset5432)
        XCTAssertTrue(preset5432?.isActive == false)
        XCTAssertNil(preset5432?.activePortItem)
    }
    
    @MainActor
    func testPresetManagement() {
        let presetManager = PresetManager()
        let initialCount = presetManager.presets.count
        
        presetManager.addPreset(
            name: "Phoenix LiveView",
            port: 4000,
            protocolType: .tcp,
            expectedProcess: "beam.smp",
            description: "Elixir Phoenix framework"
        )
        
        XCTAssertEqual(presetManager.presets.count, initialCount + 1)
        let added = presetManager.presets.first { $0.port == 4000 }
        XCTAssertNotNil(added)
        XCTAssertEqual(added?.name, "Phoenix LiveView")
        XCTAssertTrue(added?.isCustom == true)
        
        if let id = added?.id {
            presetManager.removePreset(id: id)
            XCTAssertEqual(presetManager.presets.count, initialCount)
        }
    }
}
