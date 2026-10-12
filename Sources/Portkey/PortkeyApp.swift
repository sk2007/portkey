import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory so the app runs purely in the menu bar without a Dock icon
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct PortkeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var scanner = PortScanner.shared
    
    var body: some Scene {
        WindowGroup("Portkey", id: "dashboard") {
            MainMenuBarView()
        }
        .defaultSize(width: 440, height: 570)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MainMenuBarView()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                if scanner.activePorts.count > 0 {
                    Text(verbatim: "\(scanner.activePorts.count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
