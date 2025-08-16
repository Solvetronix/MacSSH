import Foundation
import Network

enum SSHConnectionError: Error {
    case connectionFailed(String)
    case authenticationFailed(String)
    case invalidCredentials(String)
    case terminalError(String)
    case processError(String)
    case sshpassNotInstalled(String)
}

class SSHService {
    private static func checkSSHPassAvailability() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["sshpass"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
        try process.run()
        process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    static func connectToServer(_ profile: Profile) async throws -> [String] {
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]Testing connection to \(profile.host):\(profile.port)...")
        
        // Проверяем доступность хоста с помощью ssh-keyscan
        let testProcess = Process()
        let testPipe = Pipe()
        testProcess.standardOutput = testPipe
        testProcess.standardError = testPipe
        testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keyscan")
        testProcess.arguments = ["-p", "\(profile.port)", profile.host]
        
        debugLogs.append("[blue]Running ssh-keyscan...")
        
        do {
            try testProcess.run()
            testProcess.waitUntilExit()
            
            let data = testPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            debugLogs.append("[blue]ssh-keyscan exit code: \(testProcess.terminationStatus)")
            if !output.isEmpty {
                debugLogs.append("[blue]ssh-keyscan output: \(output)")
            }
            
            if testProcess.terminationStatus != 0 {
                debugLogs.append("[red]❌ Cannot reach host \(profile.host):\(profile.port)")
                throw SSHConnectionError.connectionFailed("Cannot reach host \(profile.host):\(profile.port)")
            }
            
            debugLogs.append("[green]✅ Host is reachable")
        } catch {
            debugLogs.append("[red]❌ Failed to test connection: \(error.localizedDescription)")
            throw SSHConnectionError.connectionFailed("Failed to test connection: \(error.localizedDescription)")
        }
        
        return debugLogs
    }
    
    static func openTerminal(for profile: Profile) async throws -> [String] {
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]Starting terminal opening process...")
        
        let sshCommand: String
        do {
            sshCommand = try buildSSHCommand(for: profile)
        } catch let SSHConnectionError.sshpassNotInstalled(message) {
            debugLogs.append("[red]❌ \(message)")
            throw SSHConnectionError.sshpassNotInstalled(message)
        } catch {
            debugLogs.append("[red]❌ Failed to build SSH command: \(error.localizedDescription)")
            throw error
        }
        
        debugLogs.append("[blue]SSH command: \(sshCommand)")
        
        // Создаем временный скрипт для запуска SSH
        let tempScript: URL
        do {
            tempScript = try createTempSSHScript(for: profile, command: sshCommand)
        } catch {
            debugLogs.append("[red]❌ Failed to create temporary script: \(error.localizedDescription)")
            throw error
        }
        debugLogs.append("[blue]Created temporary script: \(tempScript.path)")
        
        // Запускаем скрипт в новом окне Terminal
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", tempScript.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        debugLogs.append("[blue]Opening Terminal with script...")
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        debugLogs.append("[blue]Open command exit code: \(process.terminationStatus)")
        if !output.isEmpty {
            debugLogs.append("[blue]Open command output: \(output)")
        }

        if process.terminationStatus != 0 {
            debugLogs.append("[red]❌ Failed to open Terminal")
            throw SSHConnectionError.terminalError("Failed to open Terminal: \(output)")
        }
        
        // Удаляем временный скрипт через некоторое время
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            try? FileManager.default.removeItem(at: tempScript)
        }
        
        debugLogs.append("[green]✅ Terminal opened successfully with SSH command")
        return debugLogs
    }
    
    private static func buildSSHCommand(for profile: Profile) throws -> String {
        var command = ""
        
        // Если используется пароль, проверяем наличие sshpass
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            if !checkSSHPassAvailability() {
                throw SSHConnectionError.sshpassNotInstalled("sshpass не установлен. Для автоматической передачи пароля установите sshpass: brew install sshpass")
            }
            command = "sshpass -p '\(password)' ssh"
        } else {
            command = "ssh"
        }
        
        // Добавляем опции для автоматического принятия fingerprint'а
        command += " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        
        // Добавляем порт если не стандартный
        if profile.port != 22 {
            command += " -p \(profile.port)"
        }
        
        // Добавляем путь к приватному ключу если используется
        if profile.keyType == .privateKey, let keyPath = profile.privateKeyPath {
            command += " -i \(keyPath)"
        }
        
        // Добавляем пользователя и хост
        command += " \(profile.username)@\(profile.host)"
        
        return command
    }
    
    private static func createTempSSHScript(for profile: Profile, command: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("ssh_\(profile.id.uuidString).command")
        
        var scriptContent = "#!/bin/bash\n"
        scriptContent += "echo 'Connecting to \(profile.host)...'\n"
        scriptContent += "echo 'Command: \(command.replacingOccurrences(of: profile.password ?? "", with: "***"))'\n"
        scriptContent += "echo 'Press Ctrl+C to exit'\n"
        scriptContent += "echo ''\n"
        
        // Если используется sshpass, добавляем обработку ошибок
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            scriptContent += "export SSHPASS='\(password)'\n"
            scriptContent += "sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
            if profile.port != 22 {
                scriptContent += " -p \(profile.port)"
            }
            scriptContent += " \(profile.username)@\(profile.host)\n"
        } else {
            scriptContent += "\(command)\n"
        }
        
        scriptContent += "echo 'Connection closed.'\n"
        scriptContent += "echo 'Press Enter to close terminal...'\n"
        scriptContent += "read\n"
        
        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            print("Failed to create script: \(error)")
        }
        
        return scriptURL
    }
    

    

    
    static func testConnection(_ profile: Profile) async throws -> (success: Bool, logs: [String]) {
        // Тестирование SSH подключения без открытия терминала
        do {
            let logs = try await connectToServer(profile)
            return (true, logs)
        } catch {
            var errorLogs = ["[red]❌ Connection test failed"]
            if let sshError = error as? SSHConnectionError {
                switch sshError {
                case .connectionFailed(let message):
                    errorLogs.append("[red]❌ Connection failed: \(message)")
                case .authenticationFailed(let message):
                    errorLogs.append("[red]❌ Authentication failed: \(message)")
                case .invalidCredentials(let message):
                    errorLogs.append("[red]❌ Invalid credentials: \(message)")
                case .terminalError(let message):
                    errorLogs.append("[red]❌ Terminal error: \(message)")
                case .processError(let message):
                    errorLogs.append("[red]❌ Process error: \(message)")
                case .sshpassNotInstalled(let message):
                    errorLogs.append("[red]❌ \(message)")
                }
            } else {
                errorLogs.append("[red]❌ Error: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    static func getSSHKeyInfo(path: String) -> (type: String, fingerprint: String)? {
                let process = Process()
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = ["-lf", path]
        
        do {
                try process.run()
                process.waitUntilExit()
            
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                let lines = output.components(separatedBy: .newlines)
                if let firstLine = lines.first, !firstLine.isEmpty {
                    let parts = firstLine.components(separatedBy: " ")
                    if parts.count >= 4 {
                        let type = parts[1]
                        let fingerprint = parts[2]
                        return (type: type, fingerprint: fingerprint)
                    }
                }
            }
        } catch {
            print("Failed to get SSH key info: \(error)")
        }
        
        return nil
    }
} 