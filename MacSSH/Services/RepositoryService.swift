import Foundation
import Network

enum SSHConnectionError: Error {
    case connectionFailed(String)
    case authenticationFailed(String)
    case invalidCredentials(String)
    case terminalError(String)
    case processError(String)
    case sshpassNotInstalled(String)
    case sftpError(String)
    case permissionDenied(String)
    case externalCommandNotFound(String)
}

// Структура для представления удаленного файла/папки
struct RemoteFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let permissions: String?
    let modifiedDate: Date?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: RemoteFile, rhs: RemoteFile) -> Bool {
        return lhs.path == rhs.path
    }
}

// Результат SFTP операции
struct SFTPResult {
    let success: Bool
    let files: [RemoteFile]
    let logs: [String]
    let error: String?
}

class SSHService {
    private static func checkSSHPassAvailability() -> Bool {
        // Проверяем напрямую в известных местах установки
        let possiblePaths = [
            "/usr/bin/sshpass",
            "/usr/local/bin/sshpass", 
            "/opt/homebrew/bin/sshpass"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Если не нашли в известных местах, пробуем через which
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
    
    static func checkSSHKeyscanAvailability() -> Bool {
        // Сначала проверяем, существует ли файл
        if !FileManager.default.fileExists(atPath: "/usr/bin/ssh-keyscan") {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ssh-keyscan"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            
            // Используем таймаут вместо waitUntilExit() для предотвращения краха
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global().async {
                process.waitUntilExit()
                group.leave()
            }
            
            // Ждем максимум 3 секунды
            let result = group.wait(timeout: .now() + 3)
            
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
    
    static func checkSSHAvailability() -> Bool {
        // Сначала проверяем, существует ли файл
        if !FileManager.default.fileExists(atPath: "/usr/bin/ssh") {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ssh"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            
            // Используем таймаут вместо waitUntilExit() для предотвращения краха
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global().async {
                process.waitUntilExit()
                group.leave()
            }
            
            // Ждем максимум 3 секунды
            let result = group.wait(timeout: .now() + 3)
            
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
    
    private static func checkSFTPAvailability() -> Bool {
        // Сначала проверяем, существует ли файл
        if !FileManager.default.fileExists(atPath: "/usr/bin/sftp") {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["sftp"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            
            // Используем таймаут вместо waitUntilExit() для предотвращения краха
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global().async {
                process.waitUntilExit()
                group.leave()
            }
            
            // Ждем максимум 3 секунды
            let result = group.wait(timeout: .now() + 3)
            
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
    
    private static func checkSCPAvailability() -> Bool {
        // Сначала проверяем, существует ли файл
        if !FileManager.default.fileExists(atPath: "/usr/bin/scp") {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["scp"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            
            // Используем таймаут вместо waitUntilExit() для предотвращения краха
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global().async {
                process.waitUntilExit()
                group.leave()
            }
            
            // Ждем максимум 3 секунды
            let result = group.wait(timeout: .now() + 3)
            
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
    

    
    private static func getSSHPassPath() -> String? {
        // Проверяем напрямую в известных местах установки
        let possiblePaths = [
            "/opt/homebrew/bin/sshpass",
            "/usr/local/bin/sshpass",
            "/usr/bin/sshpass"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
        private static func checkSSHFSAvailability() -> Bool {
        // Проверяем напрямую в известных местах установки
        let possiblePaths = [
            "/usr/bin/sshfs",
            "/usr/local/bin/sshfs", 
            "/opt/homebrew/bin/sshfs"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Если не нашли в известных местах, пробуем через which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["sshfs"]
        
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
    
    /// Проверить доступность всех необходимых инструментов
    static func checkToolsAvailability() -> (sshpass: Bool, sshfs: Bool) {
        return (
            sshpass: checkSSHPassAvailability(),
            sshfs: checkSSHFSAvailability()
        )
    }
    
    /// Проверить все необходимые разрешения и команды
        static func checkAllPermissions() -> [String] {
        var results: [String] = []

        // Проверяем системные разрешения
        let systemPermissions = PermissionsService.checkAllPermissions()
        results.append(contentsOf: systemPermissions)
        
        results.append("")
        
        // Проверяем доступность команд
        results.append("=== Required SSH Tools ===")
        results.append(checkSSHKeyscanAvailability() ? "✅ ssh-keyscan: Available" : "❌ ssh-keyscan: Not found")
        results.append(checkSSHAvailability() ? "✅ ssh: Available" : "❌ ssh: Not found")
        results.append(checkSFTPAvailability() ? "✅ sftp: Available" : "❌ sftp: Not found")
        results.append(checkSCPAvailability() ? "✅ scp: Available" : "❌ scp: Not found")
        results.append(checkSSHPassAvailability() ? "✅ sshpass: Available" : "❌ sshpass: Not found")
        

        
        // Рекомендации
        results.append("\n=== Actions Needed ===")
        if !PermissionsService.forceCheckPermissions() {
            results.append("⚠️ Grant Full Disk Access: Required for SSH operations")
        }
        if !checkSSHPassAvailability() {
            results.append("⚠️ Install sshpass: brew install sshpass")
        }
        
        return results
    }
    

    
    static func connectToServer(_ profile: Profile) async throws -> [String] {
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]Testing connection to \(profile.host):\(profile.port)...")
        
        // Проверяем Full Disk Access
        if !PermissionsService.forceCheckPermissions() {
            debugLogs.append("[red]❌ Full Disk Access not granted")
            throw SSHConnectionError.permissionDenied("Full Disk Access не предоставлен. Это разрешение необходимо для выполнения SSH команд.")
        }
        
        // Проверяем доступность ssh-keyscan
        if !checkSSHKeyscanAvailability() {
            debugLogs.append("[red]❌ ssh-keyscan not available")
            throw SSHConnectionError.externalCommandNotFound("ssh-keyscan не найден. Убедитесь, что OpenSSH установлен и приложение имеет разрешения на выполнение внешних команд.")
        }
        
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
            if error.localizedDescription.contains("permission") || error.localizedDescription.contains("denied") {
                throw SSHConnectionError.permissionDenied("Нет разрешений на выполнение ssh-keyscan. Проверьте настройки безопасности приложения.")
            } else {
                throw SSHConnectionError.connectionFailed("Failed to test connection: \(error.localizedDescription)")
            }
        }
        
        return debugLogs
    }
    
    static func openTerminal(for profile: Profile) async throws -> [String] {
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]Starting terminal opening process...")
        
        // Проверяем Full Disk Access
        if !PermissionsService.forceCheckPermissions() {
            debugLogs.append("[red]❌ Full Disk Access not granted")
            throw SSHConnectionError.permissionDenied("Full Disk Access не предоставлен. Это разрешение необходимо для выполнения SSH команд.")
        }
        
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
    
    // MARK: - SFTP Operations
    
    /// Получить список файлов и папок в указанной директории
    static func listDirectory(_ profile: Profile, path: String = ".") async throws -> SFTPResult {
        print("=== REPOSITORYSERVICE: listDirectory STARTED ===")
        print("=== REPOSITORYSERVICE: Function called successfully ===")
        print("=== REPOSITORYSERVICE: About to print profile details ===")
        print("Profile: \(profile.name), Host: \(profile.host)")
        print("Path: \(path)")
        print("Profile keyType: \(profile.keyType)")
        print("Profile has password: \(profile.password != nil && !profile.password!.isEmpty)")
        print("Profile username: \(profile.username)")
        print("Profile port: \(profile.port)")
        print("Profile id: \(profile.id)")
        print("=== REPOSITORYSERVICE: About to create debugLogs array ===")
        
        var debugLogs: [String] = []
        var files: [RemoteFile] = []
        print("=== REPOSITORYSERVICE: Created variables ===")
        
        debugLogs.append("[blue]Listing directory: \(path)")
        print("=== REPOSITORYSERVICE: Added directory log ===")
        
        print("=== REPOSITORYSERVICE: About to call buildSFTPCommand ===")
        let sftpCommand = try buildSFTPCommand(for: profile)
        print("=== REPOSITORYSERVICE: buildSFTPCommand completed ===")
        debugLogs.append("[blue]SFTP command: \(sftpCommand)")
        
        // Создаем временный скрипт для SFTP
        let tempScript = try createTempSFTPListScript(for: profile, path: path)
        debugLogs.append("[blue]Created SFTP script: \(tempScript.path)")
        
        print("=== REPOSITORYSERVICE: About to create Process ===")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [tempScript.path]
        print("=== REPOSITORYSERVICE: Process created with bash and script ===")
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        debugLogs.append("[blue]Executing SFTP list command...")
        print("=== REPOSITORYSERVICE: About to execute SFTP process ===")
        
        do {
            debugLogs.append("[blue]Starting SFTP process...")
            print("=== REPOSITORYSERVICE: Starting SFTP process ===")
            try process.run()
            print("=== REPOSITORYSERVICE: SFTP process started ===")
            debugLogs.append("[blue]SFTP process started, waiting for completion...")
            print("=== REPOSITORYSERVICE: About to wait for SFTP process ===")
            process.waitUntilExit()
            print("=== REPOSITORYSERVICE: SFTP process completed ===")
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            debugLogs.append("[blue]SFTP exit code: \(process.terminationStatus)")
            debugLogs.append("[blue]SFTP output length: \(output.count) characters")
            if !output.isEmpty {
                debugLogs.append("[blue]SFTP output: \(output)")
            }
            
            if process.terminationStatus == 0 {
                files = parseSFTPListOutput(output, basePath: path)
                debugLogs.append("[green]✅ Successfully listed \(files.count) items")
            } else {
                debugLogs.append("[red]❌ SFTP command failed with exit code \(process.terminationStatus)")
                debugLogs.append("[red]❌ SFTP error output: \(output)")
                throw SSHConnectionError.sftpError("Failed to list directory (exit code \(process.terminationStatus)): \(output)")
            }
            
        } catch {
            print("=== REPOSITORYSERVICE: SFTP process ERROR ===")
            print("Error type: \(type(of: error))")
            print("Error description: \(error.localizedDescription)")
            print("Error: \(error)")
            debugLogs.append("[red]❌ SFTP process error: \(error.localizedDescription)")
            debugLogs.append("[red]❌ Error type: \(type(of: error))")
            throw SSHConnectionError.sftpError("SFTP error: \(error.localizedDescription)")
        }
        
        // Удаляем временный скрипт
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            try? FileManager.default.removeItem(at: tempScript)
        }
        
        return SFTPResult(success: true, files: files, logs: debugLogs, error: nil)
    }
    
    /// Открыть файл в Finder (скачать и открыть локально)
    static func openFileInFinder(_ profile: Profile, remotePath: String) async throws -> [String] {
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]Opening file in Finder: \(remotePath)")
        
        // Создаем временную директорию для скачивания
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacSSH_\(profile.id.uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let localPath = tempDir.appendingPathComponent(URL(fileURLWithPath: remotePath).lastPathComponent)
        
        debugLogs.append("[blue]Downloading to: \(localPath.path)")
        
        // Скачиваем файл
        let scpCommand = try buildSCPCommand(for: profile, remotePath: remotePath, localPath: localPath.path)
        debugLogs.append("[blue]SCP command: \(scpCommand)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", scpCommand]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        debugLogs.append("[blue]Executing SCP download...")
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            debugLogs.append("[blue]SCP exit code: \(process.terminationStatus)")
            if !output.isEmpty {
                debugLogs.append("[blue]SCP output: \(output)")
            }
            
            if process.terminationStatus == 0 {
                debugLogs.append("[green]✅ File downloaded successfully")
                
                // Открываем файл в Finder
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                openProcess.arguments = ["-R", localPath.path]
                
                try openProcess.run()
                openProcess.waitUntilExit()
                
                debugLogs.append("[green]✅ File opened in Finder")
            } else {
                debugLogs.append("[red]❌ SCP download failed")
                throw SSHConnectionError.sftpError("Failed to download file: \(output)")
            }
            
        } catch {
            debugLogs.append("[red]❌ SCP error: \(error.localizedDescription)")
            throw SSHConnectionError.sftpError("SCP error: \(error.localizedDescription)")
        }
        
        return debugLogs
    }
    
    /// Монтировать удаленную директорию в Finder
    static func mountDirectoryInFinder(_ profile: Profile, remotePath: String) async throws -> [String] {
        print("=== ENTERING mountDirectoryInFinder FUNCTION ===")
        print("Profile: \(profile.name), Host: \(profile.host)")
        print("Remote path: \(remotePath)")
        
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]=== STARTING MOUNT PROCESS ===")
        print("=== STARTING MOUNT PROCESS ===")
        
        // Очищаем путь от лишних символов
        let cleanPath = remotePath.replacingOccurrences(of: "/\\.$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\./", with: "", options: .regularExpression)
        
        debugLogs.append("[blue]Original path: \(remotePath)")
        debugLogs.append("[blue]Cleaned path: \(cleanPath)")
        debugLogs.append("[blue]Mounting directory in Finder: \(cleanPath)")
        
        // Проверяем доступность SSHFS
        debugLogs.append("[blue]Checking SSHFS availability...")
        print("Checking SSHFS availability...")
        let sshfsAvailable = checkSSHFSAvailability()
        debugLogs.append("[blue]SSHFS available: \(sshfsAvailable)")
        print("SSHFS available: \(sshfsAvailable)")
        
        if !sshfsAvailable {
            debugLogs.append("[yellow]⚠️ SSHFS не установлен")
            debugLogs.append("[yellow]Для монтирования директорий установите SSHFS:")
            debugLogs.append("[yellow]1. Установите MacFUSE: https://osxfuse.github.io/")
            debugLogs.append("[yellow]2. Установите SSHFS: brew install --cask macfuse && brew install sshfs")
            debugLogs.append("[blue]Вместо монтирования, откроем директорию через SFTP...")
            
            // Альтернатива: открываем через SFTP в Finder
                    debugLogs.append("[blue]Calling openDirectoryViaSFTP...")
        print("Calling openDirectoryViaSFTP with path: \(cleanPath)")
        return try await openDirectoryViaSFTP(profile, remotePath: cleanPath)
        }
        
        // Создаем точку монтирования
        let mountPoint = "/Volumes/MacSSH_\(profile.host)_\(profile.username)"
        
        // Создаем команду для sshfs
        let sshfsCommand = try buildSSHFSCommand(for: profile, remotePath: cleanPath, mountPoint: mountPoint)
        debugLogs.append("[blue]SSHFS command: \(sshfsCommand)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/sshfs")
        process.arguments = sshfsCommand.components(separatedBy: " ")
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        debugLogs.append("[blue]Executing SSHFS mount...")
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            debugLogs.append("[blue]SSHFS exit code: \(process.terminationStatus)")
            if !output.isEmpty {
                debugLogs.append("[blue]SSHFS output: \(output)")
            }
            
            if process.terminationStatus == 0 {
                debugLogs.append("[green]✅ Directory mounted successfully")
                
                // Открываем в Finder
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                openProcess.arguments = [mountPoint]
                
                try openProcess.run()
                openProcess.waitUntilExit()
                
                debugLogs.append("[green]✅ Directory opened in Finder")
            } else {
                debugLogs.append("[red]❌ SSHFS mount failed")
                debugLogs.append("[blue]Попробуем альтернативный способ...")
                return try await openDirectoryViaSFTP(profile, remotePath: remotePath)
            }
            
        } catch {
            debugLogs.append("[red]❌ SSHFS error: \(error.localizedDescription)")
            debugLogs.append("[blue]Попробуем альтернативный способ...")
            return try await openDirectoryViaSFTP(profile, remotePath: remotePath)
        }
        
        return debugLogs
    }
    
    /// Альтернативный способ открытия директории через SFTP
    private static func openDirectoryViaSFTP(_ profile: Profile, remotePath: String) async throws -> [String] {
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]=== STARTING SFTP FALLBACK ===")
        debugLogs.append("[blue]Opening directory via SFTP: \(remotePath)")
        print("=== STARTING SFTP FALLBACK ===")
        print("Opening directory via SFTP: \(remotePath)")
        
        // Создаем временную директорию для монтирования
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacSSH_Mount_\(profile.id.uuidString)")
        
        // Удаляем старую точку монтирования, если она существует
        if FileManager.default.fileExists(atPath: mountPoint.path) {
            try FileManager.default.removeItem(at: mountPoint)
        }
        
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        
        debugLogs.append("[blue]Created mount point: \(mountPoint.path)")
        print("Created mount point: \(mountPoint.path)")
        
        // Пытаемся использовать SSHFS, если доступен
        if checkSSHFSAvailability() {
            debugLogs.append("[blue]SSHFS available, attempting to mount...")
            print("SSHFS available, attempting to mount...")
            
            let sshfsCommand = try buildSSHFSCommand(for: profile, remotePath: remotePath, mountPoint: mountPoint.path)
            debugLogs.append("[blue]SSHFS command: \(sshfsCommand)")
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", sshfsCommand]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                debugLogs.append("[blue]SSHFS exit code: \(process.terminationStatus)")
                if !output.isEmpty {
                    debugLogs.append("[blue]SSHFS output: \(output)")
                }
                
                if process.terminationStatus == 0 {
                    debugLogs.append("[green]✅ Directory mounted successfully")
                    
                    // Открываем в Finder
                    let openProcess = Process()
                    openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    openProcess.arguments = [mountPoint.path]
                    
                    try openProcess.run()
                    openProcess.waitUntilExit()
                    
                    debugLogs.append("[green]✅ Directory opened in Finder")
                    debugLogs.append("[yellow]⚠️ Директория смонтирована. Для размонтирования используйте: umount \(mountPoint.path)")
                } else {
                    debugLogs.append("[red]❌ SSHFS mount failed")
                    throw SSHConnectionError.sftpError("SSHFS mount failed: \(output)")
                }
            } catch {
                debugLogs.append("[red]❌ SSHFS error: \(error.localizedDescription)")
                throw SSHConnectionError.sftpError("SSHFS error: \(error.localizedDescription)")
            }
        } else {
            // Fallback: создаем временную копию директории
            debugLogs.append("[blue]SSHFS not available, creating temporary copy...")
            print("SSHFS not available, creating temporary copy...")
            
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("MacSSH_Temp_\(profile.id.uuidString)")
            
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            debugLogs.append("[blue]Created temp directory: \(tempDir.path)")
            
            // Скачиваем содержимое директории
            let scpCommand = try buildSCPDirectoryCommand(for: profile, remotePath: remotePath, localPath: tempDir.path)
            debugLogs.append("[blue]SCP command: \(scpCommand)")
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", scpCommand]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            debugLogs.append("[blue]Downloading directory contents...")
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                debugLogs.append("[blue]SCP exit code: \(process.terminationStatus)")
                if !output.isEmpty {
                    debugLogs.append("[blue]SCP output: \(output)")
                }
                
                if process.terminationStatus == 0 {
                    debugLogs.append("[green]✅ Directory contents downloaded")
                    
                    // Открываем в Finder
                    let openProcess = Process()
                    openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    openProcess.arguments = [tempDir.path]
                    
                    try openProcess.run()
                    openProcess.waitUntilExit()
                    
                    debugLogs.append("[green]✅ Directory opened in Finder")
                    debugLogs.append("[yellow]⚠️ Это временная копия. Изменения не будут синхронизированы с сервером.")
                } else {
                    debugLogs.append("[red]❌ Failed to download directory")
                    throw SSHConnectionError.sftpError("Failed to download directory: \(output)")
                }
            } catch {
                debugLogs.append("[red]❌ SCP error: \(error.localizedDescription)")
                throw SSHConnectionError.sftpError("SCP error: \(error.localizedDescription)")
            }
        }
        
        return debugLogs
    }
    
    // MARK: - Private Helper Methods
    
    private static func buildSFTPCommand(for profile: Profile) throws -> String {
        print("=== REPOSITORYSERVICE: buildSFTPCommand STARTED ===")
        print("Profile name: \(profile.name)")
        print("Profile host: \(profile.host)")
        print("Profile keyType: \(profile.keyType)")
        print("Profile has password: \(profile.password != nil && !profile.password!.isEmpty)")
        print("SSHPass available: \(checkSSHPassAvailability())")
        
        var command = ""
        
        print("=== BUILDING SFTP COMMAND ===")
        print("Profile keyType: \(profile.keyType)")
        print("Profile has password: \(profile.password != nil && !profile.password!.isEmpty)")
        print("SSHPass available: \(checkSSHPassAvailability())")
        
        print("=== REPOSITORYSERVICE: Checking keyType ===")
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            print("=== REPOSITORYSERVICE: Password authentication detected ===")
            if !checkSSHPassAvailability() {
                print("❌ SSHPass not available, throwing error")
                throw SSHConnectionError.sshpassNotInstalled("sshpass не установлен. Для автоматической передачи пароля установите sshpass: brew install sshpass")
            }
            command = "sshpass -p '\(password)' sftp"
            print("✅ Using sshpass with password")
        } else {
            print("=== REPOSITORYSERVICE: Non-password authentication detected ===")
            command = "sftp"
            print("✅ Using sftp without password")
        }
        
        command += " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        
        if profile.port != 22 {
            command += " -P \(profile.port)"
        }
        
        command += " \(profile.username)@\(profile.host)"
        
        print("Final SFTP command: \(command)")
        return command
    }
    
    private static func buildSCPCommand(for profile: Profile, remotePath: String, localPath: String) throws -> String {
        var command = ""
        
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            if !checkSSHPassAvailability() {
                throw SSHConnectionError.sshpassNotInstalled("sshpass не установлен")
            }
            command = "sshpass -p '\(password)' scp"
        } else {
            command = "scp"
        }
        
        command += " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        
        if profile.port != 22 {
            command += " -P \(profile.port)"
        }
        
        if profile.keyType == .privateKey, let keyPath = profile.privateKeyPath {
            command += " -i \(keyPath)"
        }
        
        command += " \(profile.username)@\(profile.host):\(remotePath) \(localPath)"
        
        return command
    }
    
    private static func buildSCPDirectoryCommand(for profile: Profile, remotePath: String, localPath: String) throws -> String {
        var command = ""
        
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            if !checkSSHPassAvailability() {
                throw SSHConnectionError.sshpassNotInstalled("sshpass не установлен")
            }
            command = "sshpass -p '\(password)' scp"
        } else {
            command = "scp"
        }
        
        command += " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r"
        
        if profile.port != 22 {
            command += " -P \(profile.port)"
        }
        
        if profile.keyType == .privateKey, let keyPath = profile.privateKeyPath {
            command += " -i \(keyPath)"
        }
        
        command += " \(profile.username)@\(profile.host):\(remotePath)/* \(localPath)/"
        
        return command
    }
    
    private static func buildSSHFSCommand(for profile: Profile, remotePath: String, mountPoint: String) throws -> String {
        var command = "sshfs"
        
        // Добавляем опции SSHFS
        command += " -o StrictHostKeyChecking=no"
        command += " -o UserKnownHostsFile=/dev/null"
        command += " -o allow_other"
        command += " -o auto_cache"
        command += " -o reconnect"
        
        if profile.port != 22 {
            command += " -p \(profile.port)"
        }
        
        if profile.keyType == .privateKey, let keyPath = profile.privateKeyPath {
            command += " -o IdentityFile=\(keyPath)"
        }
        
        // Формируем строку подключения
        let connectionString: String
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            if !checkSSHPassAvailability() {
                throw SSHConnectionError.sshpassNotInstalled("sshpass не установлен для SSHFS")
            }
            connectionString = "sshpass -p '\(password)' sshfs \(profile.username)@\(profile.host):\(remotePath) \(mountPoint)"
        } else {
            connectionString = "\(profile.username)@\(profile.host):\(remotePath) \(mountPoint)"
        }
        
        command += " \(connectionString)"
        
        return command
    }
    

    
    private static func createTempSFTPListScript(for profile: Profile, path: String) throws -> URL {
        print("=== REPOSITORYSERVICE: createTempSFTPListScript STARTED ===")
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("sftp_list_\(profile.id.uuidString).sh")
        
        print("=== Creating SFTP script ===")
        print("Temp directory: \(tempDir.path)")
        print("Script URL: \(scriptURL.path)")
        print("Profile: \(profile.name), Host: \(profile.host)")
        print("Path: \(path)")
        print("=== REPOSITORYSERVICE: About to create script content ===")
        
        var scriptContent = "#!/bin/bash\n"
        print("=== REPOSITORYSERVICE: Created scriptContent variable ===")
        scriptContent += "set -e\n"
        scriptContent += "echo 'Listing directory: \(path)'\n"
        
        // Добавляем пути к Homebrew в PATH
        scriptContent += "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:$PATH\"\n"
        
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            scriptContent += "export SSHPASS='\(password)'\n"
            // Используем полный путь к sshpass
            if let sshpassPath = getSSHPassPath() {
                scriptContent += "\(sshpassPath) -e sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
            } else {
                scriptContent += "sshpass -e sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
            }
            if profile.port != 22 {
                scriptContent += " -P \(profile.port)"
            }
            scriptContent += " \(profile.username)@\(profile.host) << EOF\n"
        } else {
            scriptContent += "sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
            if profile.port != 22 {
                scriptContent += " -P \(profile.port)"
            }
            if profile.keyType == .privateKey, let keyPath = profile.privateKeyPath {
                scriptContent += " -i \(keyPath)"
            }
            scriptContent += " \(profile.username)@\(profile.host) << EOF\n"
        }
        
        scriptContent += "ls -la \(path)\n"
        scriptContent += "quit\n"
        scriptContent += "EOF\n"
        
        print("=== REPOSITORYSERVICE: About to write script to file ===")
        do {
            print("=== REPOSITORYSERVICE: Writing script content to file ===")
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            print("=== REPOSITORYSERVICE: Script written successfully ===")
            print("=== REPOSITORYSERVICE: Setting file permissions ===")
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            print("=== REPOSITORYSERVICE: File permissions set successfully ===")
        } catch {
            print("=== REPOSITORYSERVICE: ERROR writing script file ===")
            print("Error type: \(type(of: error))")
            print("Error description: \(error.localizedDescription)")
            print("Error: \(error)")
            throw SSHConnectionError.processError("Failed to create SFTP script: \(error.localizedDescription)")
        }
        
        return scriptURL
    }
    
    private static func parseSFTPListOutput(_ output: String, basePath: String) -> [RemoteFile] {
        var files: [RemoteFile] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Пропускаем служебные строки
            if trimmed.isEmpty || 
               trimmed.hasPrefix("sftp>") || 
               trimmed.hasPrefix("Connected to") ||
               trimmed.hasPrefix("Warning:") ||
               trimmed.hasPrefix("Listing directory:") ||
               trimmed.contains("of known hosts") {
                continue
            }
            
            // Парсим строку ls -la (формат: drwxr-x--- ? xioneer xioneer 4096 Jun 24 17:06 ./.)
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 9 {
                let permissions = components[0]
                
                // Проверяем, что это действительно файл/папка (начинается с d или -)
                guard permissions.hasPrefix("d") || permissions.hasPrefix("-") else {
                    continue
                }
                
                let size = Int64(components[4]) ?? 0
                let month = components[5]
                let day = components[6]
                let timeOrYear = components[7]
                let name = components[8...].joined(separator: " ")
                
                let isDirectory = permissions.hasPrefix("d")
                
                // Очищаем имя файла от лишних символов
                var cleanName = name
                    .replacingOccurrences(of: "^\\./", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "/\\.$", with: "", options: .regularExpression)
                
                // Убираем базовый путь из имени, если он там есть
                let cleanBasePath = basePath.replacingOccurrences(of: "^\\./", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "/\\.$", with: "", options: .regularExpression)
                
                if cleanName.hasPrefix("\(cleanBasePath)/") {
                    cleanName = String(cleanName.dropFirst(cleanBasePath.count + 1))
                }
                
                // Пропускаем записи . и .. если они не нужны
                if cleanName == "." || cleanName == ".." || name == "." || name == ".." || 
                   cleanName.hasSuffix("/.") || cleanName.hasSuffix("/..") ||
                   name.hasSuffix("/.") || name.hasSuffix("/..") {
                    continue
                }
                
                // Формируем правильный путь
                let fullPath: String
                if basePath == "." || cleanBasePath.isEmpty {
                    fullPath = cleanName
                } else {
                    // Убираем дублирующиеся слеши
                    let normalizedBasePath = cleanBasePath.replacingOccurrences(of: "//+", with: "/", options: .regularExpression)
                    let normalizedName = cleanName.replacingOccurrences(of: "//+", with: "/", options: .regularExpression)
                    
                    let tempPath: String
                    if normalizedBasePath.hasSuffix("/") {
                        tempPath = "\(normalizedBasePath)\(normalizedName)"
                    } else {
                        tempPath = "\(normalizedBasePath)/\(normalizedName)"
                    }
                    
                    // Убираем множественные слеши в начале
                    fullPath = tempPath.replacingOccurrences(of: "^//+", with: "/", options: .regularExpression)
                }
                
                // Парсим дату
                var modifiedDate: Date? = nil
                if let date = parseDate(month: month, day: day, timeOrYear: timeOrYear) {
                    modifiedDate = date
                }
                
                let file = RemoteFile(
                    name: cleanName,
                    path: fullPath,
                    isDirectory: isDirectory,
                    size: isDirectory ? nil : size,
                    permissions: permissions,
                    modifiedDate: modifiedDate
                )
                
                // Отладочная информация для путей
                print("DEBUG: File path creation - basePath: '\(basePath)', cleanName: '\(cleanName)', fullPath: '\(fullPath)'")
                
                files.append(file)
            }
        }
        
        return files
    }
    
    private static func parseDate(month: String, day: String, timeOrYear: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Пробуем разные форматы даты
        let formats = [
            "MMM dd HH:mm yyyy",
            "MMM dd yyyy",
            "MMM dd HH:mm"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            let dateString = "\(month) \(day) \(timeOrYear)"
            
            // Если год не указан, добавляем текущий год
            if format == "MMM dd HH:mm" {
                let currentYear = Calendar.current.component(.year, from: Date())
                let dateStringWithYear = "\(month) \(day) \(timeOrYear) \(currentYear)"
                formatter.dateFormat = "MMM dd HH:mm yyyy"
                if let date = formatter.date(from: dateStringWithYear) {
                    return date
                }
            } else {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        return nil
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
                case .sftpError(let message):
                    errorLogs.append("[red]❌ SFTP error: \(message)")
                case .permissionDenied(let message):
                    errorLogs.append("[red]❌ Permission denied: \(message)")
                case .externalCommandNotFound(let message):
                    errorLogs.append("[red]❌ External command not found: \(message)")
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