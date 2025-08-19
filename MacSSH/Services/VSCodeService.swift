import Foundation
import AppKit

enum VSCodeError: Error {
    case vscodeNotFound(String)
    case fileDownloadFailed(String)
    case fileUploadFailed(String)
    case fileWatcherError(String)
    case processError(String)
}

class VSCodeService {
    private static var fileWatchers: [String: DispatchSourceFileSystemObject] = [:]
    private static var fileMapping: [String: (profile: Profile, remotePath: String)] = [:]
    
    /// Проверяет доступность VS Code или Cursor
    static func checkVSCodeAvailability() -> Bool {
        print("=== VSCodeService: checkVSCodeAvailability STARTED ===")
        
        let possiblePaths = [
            "/usr/local/bin/code",
            "/opt/homebrew/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            "/Applications/Cursor.app/Contents/Resources/app/bin/code"
        ]
        
        print("=== VSCodeService: Checking possible paths ===")
        for path in possiblePaths {
            let exists = FileManager.default.fileExists(atPath: path)
            print("Path: \(path) - Exists: \(exists)")
            if exists {
                print("=== VSCodeService: Found VS Code/Cursor at \(path) ===")
                return true
            }
        }
        
        print("=== VSCodeService: No VS Code found in paths, checking with which ===")
        // Проверяем через which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["code"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let result = process.terminationStatus == 0
            print("=== VSCodeService: which command result: \(result) ===")
            return result
        } catch {
            print("=== VSCodeService: which command failed: \(error.localizedDescription) ===")
            return false
        }
    }
    
    /// Получает путь к VS Code или Cursor
    private static func getVSCodePath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/code",
            "/opt/homebrew/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            "/Applications/Cursor.app/Contents/Resources/app/bin/code"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("=== VSCodeService: Found editor at \(path) ===")
                return path
            }
        }
        
        print("=== VSCodeService: No editor found in paths ===")
        return nil
    }
    
    /// Открывает файл в VS Code и настраивает отслеживание изменений
    static func openFileInVSCode(_ profile: Profile, remotePath: String) async throws -> [String] {
        var debugLogs: [String] = []
        
        let timestamp = Date().timeIntervalSince1970
        debugLogs.append("[blue][\(timestamp)] VSCodeService: openFileInVSCode STARTED")
        debugLogs.append("[blue][\(timestamp)] Opening file in VS Code/Cursor: \(remotePath)")
        
        // Добавляем логирование в основной поток
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] VSCodeService: openFileInVSCode STARTED")
            print("🕐 [\(timestamp)] Opening file in VS Code/Cursor: \(remotePath)")
        }
        
        // Проверяем доступность VS Code или Cursor
        debugLogs.append("[blue][\(timestamp)] Checking VS Code/Cursor availability...")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] Checking VS Code/Cursor availability...")
        }
        if !checkVSCodeAvailability() {
            debugLogs.append("[red][\(timestamp)] ❌ VS Code/Cursor not found")
            DispatchQueue.main.async {
                print("🕐 [\(timestamp)] ❌ VS Code/Cursor not found")
            }
            throw VSCodeError.vscodeNotFound("VS Code или Cursor не найден. Убедитесь, что VS Code или Cursor установлен и команда 'code' доступна в PATH.")
        }
        debugLogs.append("[green][\(timestamp)] ✅ VS Code/Cursor availability check passed")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] ✅ VS Code/Cursor availability check passed")
        }
        
        // Создаем временную директорию для файла
        debugLogs.append("[blue][\(timestamp)] Creating temporary directory...")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] Creating temporary directory...")
        }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacSSH_VSCode_\(profile.id.uuidString)")
        
        debugLogs.append("[blue][\(timestamp)] Temp directory path: \(tempDir.path)")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] Temp directory path: \(tempDir.path)")
        }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        debugLogs.append("[green][\(timestamp)] ✅ Temporary directory created")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] ✅ Temporary directory created")
        }
        
        let fileName = URL(fileURLWithPath: remotePath).lastPathComponent
        let localPath = tempDir.appendingPathComponent(fileName)
        
        debugLogs.append("[blue][\(timestamp)] Local file path: \(localPath.path)")
        debugLogs.append("[blue][\(timestamp)] Downloading file to: \(localPath.path)")
        
        // Скачиваем файл
        debugLogs.append("[blue][\(timestamp)] Building SCP command...")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] Building SCP command...")
        }
        let scpCommand = try buildSCPCommand(for: profile, remotePath: remotePath, localPath: localPath.path)
        debugLogs.append("[blue][\(timestamp)] SCP command: \(scpCommand)")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] SCP command: \(scpCommand)")
        }
        
        debugLogs.append("[blue][\(timestamp)] Creating SCP process...")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] Creating SCP process...")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", scpCommand]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        debugLogs.append("[blue][\(timestamp)] Executing SCP download...")
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] Executing SCP download...")
        }
        
        do {
            debugLogs.append("[blue][\(timestamp)] Running SCP process...")
            DispatchQueue.main.async {
                print("🕐 [\(timestamp)] Running SCP process...")
            }
            try process.run()
            debugLogs.append("[blue][\(timestamp)] SCP process started, waiting for completion...")
            DispatchQueue.main.async {
                print("🕐 [\(timestamp)] SCP process started, waiting for completion...")
            }
            process.waitUntilExit()
            debugLogs.append("[blue][\(timestamp)] SCP process completed")
            DispatchQueue.main.async {
                print("🕐 [\(timestamp)] SCP process completed")
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            debugLogs.append("[blue][\(timestamp)] SCP exit code: \(process.terminationStatus)")
            DispatchQueue.main.async {
                print("🕐 [\(timestamp)] SCP exit code: \(process.terminationStatus)")
            }
            if !output.isEmpty {
                debugLogs.append("[blue][\(timestamp)] SCP output: \(output)")
                DispatchQueue.main.async {
                    print("🕐 [\(timestamp)] SCP output: \(output)")
                }
            }
            
            if process.terminationStatus == 0 {
                debugLogs.append("[green][\(timestamp)] ✅ File downloaded successfully")
                DispatchQueue.main.async {
                    print("🕐 [\(timestamp)] ✅ File downloaded successfully")
                }
                
                // Настраиваем отслеживание изменений файла
                debugLogs.append("[blue][\(timestamp)] Setting up file watcher...")
                DispatchQueue.main.async {
                    print("🕐 [\(timestamp)] Setting up file watcher...")
                }
                try setupFileWatcher(localPath: localPath.path, profile: profile, remotePath: remotePath)
                debugLogs.append("[green][\(timestamp)] ✅ File watcher set up successfully")
                DispatchQueue.main.async {
                    print("🕐 [\(timestamp)] ✅ File watcher set up successfully")
                }
                
                // Открываем файл в VS Code
                debugLogs.append("[blue][\(timestamp)] Opening file in VS Code/Cursor...")
                let vscodePath = getVSCodePath() ?? "code"
                debugLogs.append("[blue][\(timestamp)] VS Code path: \(vscodePath)")
                
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: vscodePath)
                openProcess.arguments = [localPath.path]
                
                debugLogs.append("[blue][\(timestamp)] VS Code process arguments: \(openProcess.arguments ?? [])")
                debugLogs.append("[blue][\(timestamp)] Running VS Code process...")
                
                try openProcess.run()
                debugLogs.append("[blue][\(timestamp)] VS Code process started")
                openProcess.waitUntilExit()
                debugLogs.append("[blue][\(timestamp)] VS Code process completed with exit code: \(openProcess.terminationStatus)")
                
                debugLogs.append("[green][\(timestamp)] ✅ File opened in VS Code/Cursor")
                debugLogs.append("[yellow][\(timestamp)] ⚠️ Изменения будут автоматически синхронизированы с сервером")
            } else {
                debugLogs.append("[red][\(timestamp)] ❌ SCP download failed")
                DispatchQueue.main.async {
                    print("🕐 [\(timestamp)] ❌ SCP download failed")
                    print("🕐 [\(timestamp)] SCP output: \(output)")
                }
                throw VSCodeError.fileDownloadFailed("Failed to download file: \(output)")
            }
            
        } catch {
            debugLogs.append("[red][\(timestamp)] ❌ SCP error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                print("🕐 [\(timestamp)] ❌ SCP error: \(error.localizedDescription)")
                print("🕐 [\(timestamp)] Error type: \(type(of: error))")
                print("🕐 [\(timestamp)] Error details: \(error)")
            }
            throw VSCodeError.fileDownloadFailed("SCP error: \(error.localizedDescription)")
        }
        
        return debugLogs
    }
    
    /// Настраивает отслеживание изменений файла
    private static func setupFileWatcher(localPath: String, profile: Profile, remotePath: String) throws {
        let timestamp = Date().timeIntervalSince1970
        print("[\(timestamp)] VSCodeService: setupFileWatcher STARTED")
        print("[\(timestamp)] Local path: \(localPath)")
        print("[\(timestamp)] Remote path: \(remotePath)")
        
        // Сохраняем маппинг файла
        fileMapping[localPath] = (profile: profile, remotePath: remotePath)
        print("[\(timestamp)] File mapping saved")
        
        // Создаем файловый дескриптор для отслеживания
        print("[\(timestamp)] Opening file descriptor...")
        let fileDescriptor = open(localPath, O_EVTONLY)
        if fileDescriptor == -1 {
            print("[\(timestamp)] ❌ Failed to open file descriptor")
            throw VSCodeError.fileWatcherError("Failed to open file descriptor for watching")
        }
        print("[\(timestamp)] ✅ File descriptor opened: \(fileDescriptor)")
        
        // Создаем источник событий файловой системы
        print("[\(timestamp)] Creating file system object source...")
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        print("[\(timestamp)] ✅ File system object source created")
        
        // Настраиваем обработчик событий
        print("[\(timestamp)] Setting up event handler...")
        source.setEventHandler {
            print("[\(timestamp)] File change detected, scheduling upload...")
            // Добавляем небольшую задержку, чтобы файл успел сохраниться
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                Task {
                    await uploadFileToServer(localPath: localPath, profile: profile, remotePath: remotePath)
                }
            }
        }
        print("[\(timestamp)] ✅ Event handler set up")
        
        // Настраиваем обработчик отмены
        print("[\(timestamp)] Setting up cancel handler...")
        source.setCancelHandler {
            print("[\(timestamp)] File watcher cancelled, closing descriptor")
            close(fileDescriptor)
        }
        print("[\(timestamp)] ✅ Cancel handler set up")
        
        // Сохраняем источник событий
        fileWatchers[localPath] = source
        print("[\(timestamp)] File watcher saved to dictionary")
        
        // Запускаем отслеживание
        source.resume()
        print("[\(timestamp)] ✅ File watcher started successfully")
    }
    
    /// Загружает измененный файл на сервер
    private static func uploadFileToServer(localPath: String, profile: Profile, remotePath: String) async {
        let timestamp = Date().timeIntervalSince1970
        print("[\(timestamp)] VSCodeService: uploadFileToServer STARTED")
        print("[\(timestamp)] Local path: \(localPath)")
        print("[\(timestamp)] Remote path: \(remotePath)")
        
        var debugLogs: [String] = []
        
        debugLogs.append("[blue]Uploading file to server: \(remotePath)")
        
        // Проверяем, что файл все еще существует
        guard FileManager.default.fileExists(atPath: localPath) else {
            debugLogs.append("[red]❌ Local file no longer exists")
            print("[\(timestamp)] ❌ Local file no longer exists")
            return
        }
        
        do {
            // Создаем команду для загрузки файла
            let scpCommand = try buildSCPUploadCommand(for: profile, localPath: localPath, remotePath: remotePath)
            debugLogs.append("[blue]SCP upload command: \(scpCommand)")
            print("[\(timestamp)] SCP upload command: \(scpCommand)")
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", scpCommand]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            debugLogs.append("[blue]Executing SCP upload...")
            print("[\(timestamp)] Executing SCP upload...")
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            debugLogs.append("[blue]SCP upload exit code: \(process.terminationStatus)")
            print("[\(timestamp)] SCP upload exit code: \(process.terminationStatus)")
            
            if !output.isEmpty {
                debugLogs.append("[blue]SCP upload output: \(output)")
                print("[\(timestamp)] SCP upload output: \(output)")
            }
            
            if process.terminationStatus == 0 {
                debugLogs.append("[green]✅ File uploaded successfully")
                print("[\(timestamp)] ✅ File uploaded successfully")
            } else {
                debugLogs.append("[red]❌ File upload failed: \(output)")
                print("[\(timestamp)] ❌ File upload failed: \(output)")
            }
            
        } catch {
            debugLogs.append("[red]❌ SCP upload error: \(error.localizedDescription)")
            print("[\(timestamp)] ❌ SCP upload error: \(error.localizedDescription)")
        }
    }
    
    /// Останавливает отслеживание файла
    static func stopWatchingFile(localPath: String) {
        if let source = fileWatchers[localPath] {
            source.cancel()
            fileWatchers.removeValue(forKey: localPath)
            fileMapping.removeValue(forKey: localPath)
        }
    }
    
    /// Останавливает отслеживание всех файлов
    static func stopWatchingAllFiles() {
        for (_, source) in fileWatchers {
            source.cancel()
        }
        fileWatchers.removeAll()
        fileMapping.removeAll()
    }
    
    // MARK: - Private Helper Methods
    
    private static func buildSCPCommand(for profile: Profile, remotePath: String, localPath: String) throws -> String {
        let timestamp = Date().timeIntervalSince1970
        print("[\(timestamp)] VSCodeService: buildSCPCommand STARTED")
        print("[\(timestamp)] Profile keyType: \(profile.keyType)")
        print("[\(timestamp)] Profile has password: \(profile.password != nil && !profile.password!.isEmpty)")
        print("[\(timestamp)] Remote path: \(remotePath)")
        print("[\(timestamp)] Local path: \(localPath)")
        
        // Добавляем логирование в основной поток
        DispatchQueue.main.async {
            print("🕐 [\(timestamp)] VSCodeService: buildSCPCommand STARTED")
            print("🕐 [\(timestamp)] Profile keyType: \(profile.keyType)")
            print("🕐 [\(timestamp)] Profile has password: \(profile.password != nil && !profile.password!.isEmpty)")
            print("🕐 [\(timestamp)] Remote path: \(remotePath)")
            print("🕐 [\(timestamp)] Local path: \(localPath)")
        }
        
        var command = ""
        
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            print("[\(timestamp)] Using password authentication")
            
            // Проверяем доступность sshpass напрямую
            let possiblePaths = [
                "/usr/bin/sshpass",
                "/usr/local/bin/sshpass", 
                "/opt/homebrew/bin/sshpass"
            ]
            
            var sshpassAvailable = false
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    sshpassAvailable = true
                    print("[\(timestamp)] ✅ sshpass found at: \(path)")
                    break
                }
            }
            
            if !sshpassAvailable {
                print("[\(timestamp)] ❌ sshpass not available")
                throw VSCodeError.processError("sshpass не установлен")
            }
            
            // Используем полный путь к sshpass
            let sshpassPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/sshpass"
            command = "\(sshpassPath) -p '\(password)' scp"
        } else {
            print("[\(timestamp)] Using key-based authentication")
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
        
        print("[\(timestamp)] Final SCP command: \(command)")
        print("[\(timestamp)] VSCodeService: buildSCPCommand COMPLETED")
        
        return command
    }
    
    private static func buildSCPUploadCommand(for profile: Profile, localPath: String, remotePath: String) throws -> String {
        let timestamp = Date().timeIntervalSince1970
        print("[\(timestamp)] VSCodeService: buildSCPUploadCommand STARTED")
        print("[\(timestamp)] Profile keyType: \(profile.keyType)")
        print("[\(timestamp)] Profile has password: \(profile.password != nil && !profile.password!.isEmpty)")
        print("[\(timestamp)] Local path: \(localPath)")
        print("[\(timestamp)] Remote path: \(remotePath)")
        
        var command = ""
        
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            print("[\(timestamp)] Using password authentication")
            
            // Проверяем доступность sshpass напрямую
            let possiblePaths = [
                "/usr/bin/sshpass",
                "/usr/local/bin/sshpass", 
                "/opt/homebrew/bin/sshpass"
            ]
            
            var sshpassAvailable = false
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    sshpassAvailable = true
                    print("[\(timestamp)] ✅ sshpass found at: \(path)")
                    break
                }
            }
            
            if !sshpassAvailable {
                print("[\(timestamp)] ❌ sshpass not available")
                throw VSCodeError.processError("sshpass не установлен")
            }
            
            // Используем полный путь к sshpass
            let sshpassPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/sshpass"
            command = "\(sshpassPath) -p '\(password)' scp"
        } else {
            print("[\(timestamp)] Using key-based authentication")
            command = "scp"
        }
        
        command += " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        
        if profile.port != 22 {
            command += " -P \(profile.port)"
        }
        
        if profile.keyType == .privateKey, let keyPath = profile.privateKeyPath {
            command += " -i \(keyPath)"
        }
        
        command += " \(localPath) \(profile.username)@\(profile.host):\(remotePath)"
        
        print("[\(timestamp)] Final SCP upload command: \(command)")
        print("[\(timestamp)] VSCodeService: buildSCPUploadCommand COMPLETED")
        
        return command
    }
}
