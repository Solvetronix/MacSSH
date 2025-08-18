import Foundation
import SwiftUI
import AppKit

class ProfileViewModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var connectionLog: [String] = []
    @Published var showingPermissionsWarning = false
    @Published var showingPermissionsManager = false
    
    // SFTP properties
    @Published var currentDirectory: String = "/"
    @Published var remoteFiles: [RemoteFile] = []
    
    /// Сортирует файлы в стандартном порядке: сначала папки, потом файлы, все по алфавиту
    private func sortFiles(_ files: [RemoteFile]) -> [RemoteFile] {
        return files.sorted { first, second in
            // Сначала сортируем по типу: папки перед файлами
            if first.isDirectory != second.isDirectory {
                return first.isDirectory && !second.isDirectory
            }
            
            // Затем сортируем по имени (без учета регистра)
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }
    @Published var isBrowsingFiles: Bool = false
    @Published var fileBrowserError: String?
    @Published var showingFileBrowserWindow: Bool = false
    @Published var fileBrowserProfile: Profile?
    @Published var selectedFileID: RemoteFile.ID?
    
    private let userDefaults = UserDefaults.standard
    private let profilesKey = "savedSSHProfiles"
    
    init() {
        loadProfiles()
        checkPermissionsOnStartup()
    }
    
    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
    }
    
    func updateProfile(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
        }
    }
    
    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
    }
    
    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            userDefaults.set(encoded, forKey: profilesKey)
        }
    }
    
    private func loadProfiles() {
        if let data = userDefaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = decoded
        }
    }
    
    private func checkPermissionsOnStartup() {
        // Проверяем разрешения только при первом запуске или если пользователь не отклонил предупреждение
        let hasShownWarning = userDefaults.bool(forKey: "hasShownPermissionsWarning")
        let hasDeclinedWarning = userDefaults.bool(forKey: "hasDeclinedPermissionsWarning")
        
        if !hasShownWarning && !hasDeclinedWarning {
            // Проверяем Full Disk Access и доступность основных команд
            let fullDiskAccess = PermissionsService.forceCheckPermissions()
            let sshKeyscanAvailable = SSHService.checkSSHKeyscanAvailability()
            let sshAvailable = SSHService.checkSSHAvailability()
            
            if !fullDiskAccess || !sshKeyscanAvailable || !sshAvailable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showingPermissionsWarning = true
                    self.userDefaults.set(true, forKey: "hasShownPermissionsWarning")
                }
            }
        }
    }
    
    private func checkForPermissionError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        print("=== CHECKING PERMISSION ERROR ===")
        print("Error description: \(error.localizedDescription)")
        print("Error description (lowercase): \(errorDescription)")
        print("Contains 'error 5': \(errorDescription.contains("error 5"))")
        print("Contains 'permission': \(errorDescription.contains("permission"))")
        print("Contains 'denied': \(errorDescription.contains("denied"))")
        print("Contains 'external command not found': \(errorDescription.contains("external command not found"))")
        
        let isPermissionError = errorDescription.contains("error 5") || 
                               errorDescription.contains("permission") || 
                               errorDescription.contains("denied") ||
                               errorDescription.contains("external command not found")
        
        print("Is permission error: \(isPermissionError)")
        return isPermissionError
    }
    
    func connectToServer(_ profile: Profile) async {
        await MainActor.run {
            self.isConnecting = true
            self.connectionError = nil
            self.connectionLog.removeAll()
            self.connectionLog.append("[blue]Connecting to \(profile.host)...")
        }
        
        do {
            let debugLogs = try await SSHService.connectToServer(profile)
            await MainActor.run {
                // Добавляем все отладочные логи
                for log in debugLogs {
                    self.connectionLog.append(log)
                }
                // Обновляем дату последнего подключения
                if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                    self.profiles[index].lastConnectionDate = Date()
                    self.saveProfiles()
                }
            }
        } catch let SSHConnectionError.connectionFailed(message) {
            await MainActor.run {
                self.connectionError = message
                self.connectionLog.append("❌ Connection failed: \(message)")
            }
        } catch let SSHConnectionError.authenticationFailed(message) {
            await MainActor.run {
                self.connectionError = message
                self.connectionLog.append("❌ Authentication failed: \(message)")
            }
        } catch let SSHConnectionError.invalidCredentials(message) {
            await MainActor.run {
                self.connectionError = message
                self.connectionLog.append("❌ Invalid credentials: \(message)")
            }
        } catch let SSHConnectionError.permissionDenied(message) {
            await MainActor.run {
                self.connectionError = message
                self.connectionLog.append("❌ Permission denied: \(message)")
                self.showingPermissionsManager = true
            }
        } catch let SSHConnectionError.externalCommandNotFound(message) {
            await MainActor.run {
                self.connectionError = message
                self.connectionLog.append("❌ External command not found: \(message)")
                self.showingPermissionsManager = true
            }
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
                self.connectionLog.append("❌ Connection error: \(error.localizedDescription)")
                if self.checkForPermissionError(error) {
                    self.showingPermissionsManager = true
                }
            }
        }
        
        await MainActor.run {
            self.isConnecting = false
        }
    }
    
    func openTerminal(for profile: Profile) async {
        await MainActor.run {
            self.isConnecting = true
            self.connectionError = nil
            self.connectionLog.removeAll()
            self.connectionLog.append("[blue]Opening terminal for \(profile.host)...")
        }
        
        do {
            let debugLogs = try await SSHService.openTerminal(for: profile)
            await MainActor.run {
                // Добавляем все отладочные логи
                for log in debugLogs {
                    self.connectionLog.append(log)
                }
                // Обновляем дату последнего подключения
                if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                    self.profiles[index].lastConnectionDate = Date()
                    self.saveProfiles()
                }
            }
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
                self.connectionLog.append("❌ Failed to open terminal: \(error.localizedDescription)")
                if self.checkForPermissionError(error) {
                    self.showingPermissionsManager = true
                }
            }
        }
        
        await MainActor.run {
            self.isConnecting = false
        }
    }
    

    
    func testConnection(_ profile: Profile) async {
        await MainActor.run {
            self.isConnecting = true
            self.connectionError = nil
            self.connectionLog.removeAll()
            self.connectionLog.append("[blue]Testing connection to \(profile.host)...")
        }
        
        do {
            let result = try await SSHService.testConnection(profile)
            await MainActor.run {
                // Добавляем все отладочные логи
                for log in result.logs {
                    self.connectionLog.append(log)
                }
                if result.success {
                    self.connectionLog.append("[green]✅ Connection test successful for \(profile.host)")
                    self.connectionLog.append("[blue]Automatically opening terminal...")
                }
            }
            
            // Если тест прошел успешно, автоматически открываем терминал
            if result.success {
                try await Task.sleep(nanoseconds: 1_000_000_000) // Ждем 1 секунду
                let terminalLogs = try await SSHService.openTerminal(for: profile)
                await MainActor.run {
                    // Добавляем логи открытия терминала
                    for log in terminalLogs {
                        self.connectionLog.append(log)
                    }
                    // Обновляем дату последнего подключения
                    if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                        self.profiles[index].lastConnectionDate = Date()
                        self.saveProfiles()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
                self.connectionLog.append("❌ Connection test error: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isConnecting = false
        }
    }
    
    // MARK: - SFTP Operations
    
    /// Открыть файловый менеджер в отдельном окне
    func openFileBrowserWindow(for profile: Profile) {
        self.fileBrowserProfile = profile
        self.showingFileBrowserWindow = true
    }
    
    /// Открыть файловый браузер для профиля
    func openFileBrowser(for profile: Profile) async {
        print("=== PROFILEVIEWMODEL: openFileBrowser STARTED ===")
        print("Profile: \(profile.name), Host: \(profile.host)")
        print("Current thread: \(Thread.isMainThread ? "Main" : "Background")")
        print("Profile keyType: \(profile.keyType)")
        print("Profile has password: \(profile.password != nil && !profile.password!.isEmpty)")
        print("Profile username: \(profile.username)")
        print("Profile port: \(profile.port)")
        print("Current directory: \(currentDirectory)")
        print("=== PROFILEVIEWMODEL: About to set isBrowsingFiles = true ===")
        
        await MainActor.run {
            print("=== PROFILEVIEWMODEL: Setting UI state ===")
            self.isBrowsingFiles = true
            self.fileBrowserError = nil
            // По умолчанию открываем корневую директорию
            if self.currentDirectory == "." || self.currentDirectory.isEmpty {
                self.currentDirectory = "/"
            }
            self.connectionLog.removeAll()
            self.connectionLog.append("[blue]Opening file browser for \(profile.host)...")
            print("=== PROFILEVIEWMODEL: UI state set successfully ===")
        }
        
        do {
            print("=== PROFILEVIEWMODEL: About to call SSHService.listDirectory ===")
            print("Profile: \(profile.name), Host: \(profile.host)")
            print("Current directory: \(currentDirectory)")
            
            let result = try await SSHService.listDirectory(profile, path: currentDirectory)
            await MainActor.run {
                self.remoteFiles = self.sortFiles(result.files)
                for log in result.logs {
                    self.connectionLog.append(log)
                }
                self.connectionLog.append("[green]✅ File browser opened successfully")
            }
        } catch {
            print("=== PROFILEVIEWMODEL: openFileBrowser ERROR ===")
            print("Error type: \(type(of: error))")
            print("Error description: \(error.localizedDescription)")
            print("Error: \(error)")
            
            await MainActor.run {
                self.fileBrowserError = error.localizedDescription
                self.connectionLog.append("❌ Failed to open file browser: \(error.localizedDescription)")
                self.connectionLog.append("[red]Error type: \(type(of: error))")
                self.connectionLog.append("[red]Full error: \(error)")
                if self.checkForPermissionError(error) {
                    self.connectionLog.append("[yellow]⚠️ This appears to be a permission error")
                    self.showingPermissionsManager = true
                }
            }
        }
        
        await MainActor.run {
            self.isBrowsingFiles = false
        }
    }
    
    /// Перейти в директорию
    func navigateToDirectory(_ profile: Profile, path: String) async {
        print("=== PROFILEVIEWMODEL: navigateToDirectory STARTED ===")
        print("Profile: \(profile.name), Host: \(profile.host)")
        print("Path: \(path)")
        print("Current directory: \(currentDirectory)")
        
        await MainActor.run {
            self.isBrowsingFiles = true
            self.fileBrowserError = nil
            self.connectionLog.append("[blue]Navigating to: \(path)")
        }
        
        do {
            print("=== PROFILEVIEWMODEL: About to call SSHService.listDirectory ===")
            let normalized = normalizePath(path)
            let result = try await SSHService.listDirectory(profile, path: normalized)
            await MainActor.run {
                self.currentDirectory = normalized
                self.remoteFiles = self.sortFiles(result.files)
                for log in result.logs {
                    self.connectionLog.append(log)
                }
                self.connectionLog.append("[green]✅ Navigated to \(normalized)")
            }
        } catch {
            print("=== PROFILEVIEWMODEL: navigateToDirectory ERROR ===")
            print("Error type: \(type(of: error))")
            print("Error description: \(error.localizedDescription)")
            print("Error: \(error)")
            
            await MainActor.run {
                self.fileBrowserError = error.localizedDescription
                self.connectionLog.append("❌ Failed to navigate: \(error.localizedDescription)")
                if self.checkForPermissionError(error) {
                    self.showingPermissionsManager = true
                }
            }
        }
        
        await MainActor.run {
            self.isBrowsingFiles = false
        }
    }
    
    /// Открыть файл в Finder
    func openFileInFinder(_ profile: Profile, file: RemoteFile) async {
        await MainActor.run {
            self.isConnecting = true
            self.connectionError = nil
            self.connectionLog.append("[blue]Opening file in Finder: \(file.name)")
        }
        
        do {
            let logs = try await SSHService.openFileInFinder(profile, remotePath: file.path)
            await MainActor.run {
                for log in logs {
                    self.connectionLog.append(log)
                }
                self.connectionLog.append("[green]✅ File opened in Finder")
            }
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
                self.connectionLog.append("❌ Failed to open file: \(error.localizedDescription)")
                if self.checkForPermissionError(error) {
                    self.showingPermissionsManager = true
                }
            }
        }
        
        await MainActor.run {
            self.isConnecting = false
        }
    }
    
    /// Монтировать директорию в Finder
    func mountDirectoryInFinder(_ profile: Profile, directory: RemoteFile) async {
        print("=== PROFILEVIEWMODEL: mountDirectoryInFinder FUNCTION STARTED ===")
        print("Profile: \(profile.name), Host: \(profile.host)")
        print("Directory: \(directory.name), Path: \(directory.path)")
        print("Current directory: \(currentDirectory)")
        print("=== PROFILEVIEWMODEL: About to set isConnecting = true ===")
        
        await MainActor.run {
            self.isConnecting = true
            self.connectionError = nil
            self.connectionLog.append("[blue]Mounting directory in Finder: \(directory.name)")
            self.connectionLog.append("[blue]Current directory: \(currentDirectory)")
            self.connectionLog.append("[blue]Directory path: \(directory.path)")
        }
        
        do {
            print("=== PROFILEVIEWMODEL: About to call SSHService.mountDirectoryInFinder ===")
            print("Profile: \(profile.name), Host: \(profile.host)")
            print("Directory path: \(directory.path)")
            print("Directory name: \(directory.name)")
            let logs = try await SSHService.mountDirectoryInFinder(profile, remotePath: directory.path)
            print("=== PROFILEVIEWMODEL: SSHService.mountDirectoryInFinder returned successfully ===")
            print("Logs count: \(logs.count)")
            await MainActor.run {
                for log in logs {
                    self.connectionLog.append(log)
                }
                self.connectionLog.append("[green]✅ Directory mounted in Finder")
            }
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
                self.connectionLog.append("❌ Failed to mount directory: \(error.localizedDescription)")
                if self.checkForPermissionError(error) {
                    self.showingPermissionsManager = true
                }
            }
        }
        
        await MainActor.run {
            self.isConnecting = false
        }
        
        print("=== PROFILEVIEWMODEL: mountDirectoryInFinder FUNCTION COMPLETED ===")
    }
    
    /// Перейти в родительскую директорию
    func navigateToParentDirectory(_ profile: Profile) async {
        let parentPath = getParentPath(currentDirectory)
        await navigateToDirectory(profile, path: parentPath)
    }
    
    /// Получить родительский путь
    private func getParentPath(_ path: String) -> String {
        let normalized = normalizePath(path)
        if normalized == "/" { return "/" }
        // убираем завершающий слеш
        let trimmed = normalized.hasSuffix("/") && normalized.count > 1 ? String(normalized.dropLast()) : normalized
        if trimmed.hasPrefix("/") {
            let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
            if parts.isEmpty { return "/" }
            let parent = parts.dropLast()
            return parent.isEmpty ? "/" : "/" + parent.joined(separator: "/")
        } else {
            let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
            if parts.isEmpty { return "." }
            let parent = parts.dropLast()
            return parent.isEmpty ? "." : parent.joined(separator: "/")
        }
    }
    
    /// Получить отображаемое имя пути
    func getDisplayPath() -> String { currentDirectory.isEmpty ? "/" : currentDirectory }
    
    /// Проверить, можно ли перейти в родительскую директорию
    func canNavigateToParent() -> Bool {
        return currentDirectory != "/"
    }

    // Нормализуем путь: убираем множественные слеши, пустые, заменяем "." на "/", убираем завершающий слеш
    private func normalizePath(_ rawPath: String) -> String {
        var path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty || path == "." { return "/" }
        path = path.replacingOccurrences(of: "//+", with: "/", options: .regularExpression)
        if path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        if path.isEmpty { return "/" }
        return path
    }
} 