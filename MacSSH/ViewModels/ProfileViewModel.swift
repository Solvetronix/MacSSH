import Foundation
import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var connectionLog: [String] = []
    
    // SFTP properties
    @Published var currentDirectory: String = "."
    @Published var remoteFiles: [RemoteFile] = []
    @Published var isBrowsingFiles: Bool = false
    @Published var fileBrowserError: String?
    @Published var selectedFileID: RemoteFile.ID?
    
    private let userDefaults = UserDefaults.standard
    private let profilesKey = "savedSSHProfiles"
    
    init() {
        loadProfiles()
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
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
                self.connectionLog.append("❌ Connection error: \(error.localizedDescription)")
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
    
    /// Открыть файловый браузер для профиля
    func openFileBrowser(for profile: Profile) async {
        print("=== PROFILEVIEWMODEL: openFileBrowser STARTED ===")
        print("Profile: \(profile.name), Host: \(profile.host)")
        print("Current directory: \(currentDirectory)")
        
        await MainActor.run {
            self.isBrowsingFiles = true
            self.fileBrowserError = nil
            self.connectionLog.removeAll()
            self.connectionLog.append("[blue]Opening file browser for \(profile.host)...")
        }
        
        do {
            let result = try await SSHService.listDirectory(profile, path: currentDirectory)
            await MainActor.run {
                self.remoteFiles = result.files
                for log in result.logs {
                    self.connectionLog.append(log)
                }
                self.connectionLog.append("[green]✅ File browser opened successfully")
            }
        } catch {
            await MainActor.run {
                self.fileBrowserError = error.localizedDescription
                self.connectionLog.append("❌ Failed to open file browser: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isBrowsingFiles = false
        }
    }
    
    /// Перейти в директорию
    func navigateToDirectory(_ profile: Profile, path: String) async {
        await MainActor.run {
            self.isBrowsingFiles = true
            self.fileBrowserError = nil
            self.connectionLog.append("[blue]Navigating to: \(path)")
        }
        
        do {
            let result = try await SSHService.listDirectory(profile, path: path)
            await MainActor.run {
                self.currentDirectory = path
                self.remoteFiles = result.files
                for log in result.logs {
                    self.connectionLog.append(log)
                }
                self.connectionLog.append("[green]✅ Navigated to \(path)")
            }
        } catch {
            await MainActor.run {
                self.fileBrowserError = error.localizedDescription
                self.connectionLog.append("❌ Failed to navigate: \(error.localizedDescription)")
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
        if path == "." || path == "/" {
            return "."
        }
        
        let components = path.components(separatedBy: "/")
        if components.count <= 1 {
            return "."
        }
        
        let parentComponents = Array(components.dropLast())
        return parentComponents.isEmpty ? "/" : parentComponents.joined(separator: "/")
    }
    
    /// Получить отображаемое имя пути
    func getDisplayPath() -> String {
        if currentDirectory == "." {
            return "Home Directory"
        }
        return currentDirectory
    }
    
    /// Проверить, можно ли перейти в родительскую директорию
    func canNavigateToParent() -> Bool {
        return currentDirectory != "." && currentDirectory != "/"
    }
} 