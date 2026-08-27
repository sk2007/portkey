import Foundation
import AppKit
import ServiceManagement

public enum ProcessKillError: LocalizedError, Sendable {
    case processNotFound(pid_t)
    case permissionDenied(pid_t)
    case failed(String)
    
    public var errorDescription: String? {
        switch self {
        case .processNotFound(let pid):
            return "Process with PID \(pid) is no longer running."
        case .permissionDenied(let pid):
            return "Permission denied when attempting to kill PID \(pid). Try running with elevated privileges."
        case .failed(let msg):
            return msg
        }
    }
}

public final class ProcessManager: Sendable {
    public static let shared = ProcessManager()
    
    private init() {}
    
    /// Checks if a process with the given PID is currently active.
    public func isProcessAlive(pid: pid_t) -> Bool {
        if pid <= 0 { return false }
        return kill(pid, 0) == 0
    }
    
    /// Terminates a process, starting with SIGTERM, then escalating to SIGKILL if necessary.
    @discardableResult
    public func killProcess(pid: pid_t, force: Bool = false) async -> Result<Void, ProcessKillError> {
        guard isProcessAlive(pid: pid) else {
            return .failure(.processNotFound(pid))
        }
        
        if force {
            let result = kill(pid, SIGKILL)
            if result == 0 {
                return .success(())
            } else if errno == EPERM {
                return await killWithAdminPrivileges(pid: pid)
            } else {
                return .failure(.failed("Failed to kill process (errno: \(errno))"))
            }
        }
        
        // 1. Send SIGTERM first for graceful termination
        let termResult = kill(pid, SIGTERM)
        if termResult != 0 {
            if errno == EPERM {
                return await killWithAdminPrivileges(pid: pid)
            } else if errno == ESRCH {
                return .success(())
            }
        }
        
        // Wait up to 500ms to see if it gracefully exited
        for _ in 0..<5 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if !isProcessAlive(pid: pid) {
                return .success(())
            }
        }
        
        // 2. Escalate to SIGKILL
        let killResult = kill(pid, SIGKILL)
        if killResult == 0 {
            return .success(())
        } else if errno == EPERM {
            return await killWithAdminPrivileges(pid: pid)
        } else {
            return .failure(.failed("Failed to kill process (errno: \(errno))"))
        }
    }
    
    /// Kills a process using AppleScript with administrator privileges if the user lacks permissions.
    private func killWithAdminPrivileges(pid: pid_t) async -> Result<Void, ProcessKillError> {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let scriptSource = "do shell script \"kill -9 \(pid)\" with administrator privileges"
                var error: NSDictionary?
                if let script = NSAppleScript(source: scriptSource) {
                    script.executeAndReturnError(&error)
                    if let error = error {
                        let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                        continuation.resume(returning: .failure(.failed(errorMsg)))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                } else {
                    continuation.resume(returning: .failure(.permissionDenied(pid)))
                }
            }
        }
    }
    
    /// Opens the URL in the user's default browser.
    public func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    /// Copies the given string to the macOS clipboard.
    public func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Reveals a file or directory in Finder.
    public func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    /// Opens the target directory in Terminal.
    public func openInTerminal(directory: String) {
        let dirURL = URL(fileURLWithPath: directory)
        let config = NSWorkspace.OpenConfiguration()
        if let terminalApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.open([dirURL], withApplicationAt: terminalApp, configuration: config, completionHandler: nil)
        }
    }
    
    /// Toggles Launch at Login status via ServiceManagement.
    public func setLaunchAtLogin(enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            print("Failed to set launch at login: \(error)")
            return false
        }
    }
    
    public var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
