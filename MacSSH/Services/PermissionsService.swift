import Foundation
import AppKit
import Security

class PermissionsService {
    
    /// Checks if the application has Full Disk Access permission
    static func checkFullDiskAccess() -> Bool {
        // Check ability to execute SSH commands directly
        let sshWorks = canExecuteSSHCommands()
        
        // Additional check - try to execute a simple command
        let simpleCommandWorks = canExecuteExternalCommands()
        
        // If at least one check passed successfully, consider that permissions exist
        return sshWorks || simpleCommandWorks
    }
    
    /// Checks ability to execute SSH commands
    private static func canExecuteSSHCommands() -> Bool {
        // Check ssh-keyscan - this is the main command used by the application
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keyscan")
        process.arguments = ["-v"] // Verbose mode for checking
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            // Use timeout to prevent hanging
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global().async {
                process.waitUntilExit()
                group.leave()
            }
            
            // Wait maximum 3 seconds
            let result = group.wait(timeout: .now() + 3)
            
            if result == .timedOut {
                // If process hung, kill it
                process.terminate()
                return false
            }
            
            // If command executed successfully (exit code 0 or 1 for help), then permission exists
            return process.terminationStatus == 0 || process.terminationStatus == 1
        } catch {
            // If command didn't execute due to lack of permissions, then no permissions
            return false
        }
    }
    
    /// Requests Full Disk Access permission
    static func requestFullDiskAccess() {
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "MacSSH needs Full Disk Access to execute SSH commands and access system tools. Please grant this permission in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openSystemPreferences()
        }
    }
    
    /// Открывает System Settings на странице Privacy & Security
    private static func openSystemPreferences() {
        let script = """
        tell application "System Settings"
            activate
            set current pane to pane id "com.apple.settings.PrivacySecurity"
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
        } catch {
            // Fallback для старых версий macOS
            let fallbackScript = """
            tell application "System Preferences"
                activate
                set current pane to pane id "com.apple.preference.security"
            end tell
            """
            
            let fallbackProcess = Process()
            fallbackProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            fallbackProcess.arguments = ["-e", fallbackScript]
            
            do {
                try fallbackProcess.run()
            } catch {
                print("Failed to open System Settings/Preferences: \(error)")
            }
        }
    }
    
    /// Проверяет все необходимые разрешения
    static func checkAllPermissions() -> [String] {
        var results: [String] = []
        
        results.append("=== System Permissions ===")
        
        let fullDiskAccess = checkFullDiskAccess()
        results.append(fullDiskAccess ? "✅ Full Disk Access: Granted" : "❌ Full Disk Access: Not granted")
        
        if !fullDiskAccess {
            results.append("⚠️ Full Disk Access is required for SSH operations")
        }
        
        // VS Code/Cursor проверяется в SSH Tools section
        
        return results
    }
    
    /// Принудительно проверяет и обновляет статус разрешений
    static func forceCheckPermissions() -> Bool {
        // Принудительно проверяем SSH команды
        let sshWorks = canExecuteSSHCommands()
        let simpleWorks = canExecuteExternalCommands()
        let canExecute = sshWorks || simpleWorks
        
        print("🔍 Permissions Debug:")
        print("  - SSH commands work: \(sshWorks)")
        print("  - Simple commands work: \(simpleWorks)")
        print("  - Overall result: \(canExecute)")
        
        // Если разрешения есть, но приложение все еще думает что их нет,
        // сбрасываем кэш UserDefaults
        if canExecute {
            UserDefaults.standard.removeObject(forKey: "hasShownPermissionsWarning")
            UserDefaults.standard.removeObject(forKey: "hasDeclinedPermissionsWarning")
            print("  - Cleared UserDefaults cache")
        }
        
        return canExecute
    }
    
    /// Проверяет, может ли приложение выполнять внешние команды
    static func canExecuteExternalCommands() -> Bool {
        // Проверяем возможность выполнения простой команды
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/echo")
        process.arguments = ["test"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            // Используем таймаут для предотвращения зависания
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global().async {
                process.waitUntilExit()
                group.leave()
            }
            
            // Ждем максимум 2 секунды
            let result = group.wait(timeout: .now() + 2)
            
            if result == .timedOut {
                // Если процесс завис, убиваем его
                process.terminate()
                return false
            }
            
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
