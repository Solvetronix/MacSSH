import Foundation
import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var connectionLog: [String] = []
    
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
} 