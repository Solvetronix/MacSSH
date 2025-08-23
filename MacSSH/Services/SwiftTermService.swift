import Foundation
import AppKit
import SwiftUI
import SwiftTerm

class SwiftTermService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var connectionStatus: String = ""
    
    private var terminalView: TerminalView?
    private var sshProcess: Process?
    private var currentProfile: Profile?
    private var isDisconnecting = false
    
    @MainActor
    func connectToSSH(profile: Profile) async throws {
        LoggingService.shared.debug("Starting SwiftTerm SSH connection to \(profile.host)", source: "SwiftTermService")
        
        self.isLoading = true
        self.isConnected = false
        self.connectionStatus = "Подключение..."
        
        // Проверяем разрешения (убираем строгую проверку для SwiftTerm)
        // if !PermissionsService.forceCheckPermissions() {
        //     throw SSHConnectionError.permissionDenied("Full Disk Access не предоставлен")
        // }
        
        // Строим SSH команду
        let sshCommand = try buildSSHCommand(for: profile)
        LoggingService.shared.debug("SSH command built: \(sshCommand)", source: "SwiftTermService")
        
        // Создаем терминал
        let terminal = TerminalView()
        terminal.configureNativeColors()
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        // Создаем процесс SSH
        let process = Process()
        
        // Запускаем SSH процесс
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Разделяем команду на компоненты
                    let components = self.parseCommand(sshCommand)
                    let executable = components.0
                    let arguments = components.1
                    
                    // Настраиваем процесс
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    process.environment = [
                        "TERM": "xterm-256color",
                        "COLUMNS": "80",
                        "LINES": "24"
                    ]
                    
                    // Создаем pipes для ввода/вывода
                    let inputPipe = Pipe()
                    let outputPipe = Pipe()
                    process.standardInput = inputPipe
                    process.standardOutput = outputPipe
                    process.standardError = outputPipe
                    
                    // Настраиваем переменные окружения для терминала
                    var environment = ProcessInfo.processInfo.environment
                    environment["TERM"] = "xterm-256color"
                    environment["COLUMNS"] = "80"
                    environment["LINES"] = "24"
                    process.environment = environment
                    
                    // Обработка вывода процесса
                    outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            DispatchQueue.main.async {
                                let bytes = Array(data)
                                terminal.feed(byteArray: bytes[...])
                                
                                // Логируем весь вывод для отладки
                                if let output = String(data: data, encoding: .utf8) {
                                    LoggingService.shared.info("📥 SSH Output: '\(output.replacingOccurrences(of: "\n", with: "\\n"))'", source: "SwiftTermService")
                                    
                                    // Проверяем, нужно ли отправить пароль
                                    if output.contains("password:") || output.contains("Password:") {
                                        LoggingService.shared.warning("🔐 Password prompt detected!", source: "SwiftTermService")
                                        
                                        // Отправляем пароль если запрашивается
                                        if let profile = self?.currentProfile,
                                           profile.keyType == .password,
                                           let password = profile.password,
                                           !password.isEmpty {
                                            LoggingService.shared.info("🔑 Sending password automatically...", source: "SwiftTermService")
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                let passwordData = (password + "\n").data(using: .utf8) ?? Data()
                                                if let inputPipe = process.standardInput as? Pipe {
                                                    inputPipe.fileHandleForWriting.write(passwordData)
                                                    LoggingService.shared.success("✅ Password sent to SSH process", source: "SwiftTermService")
                                                } else {
                                                    LoggingService.shared.error("❌ Failed to get input pipe for password", source: "SwiftTermService")
                                                }
                                            }
                                        } else {
                                            LoggingService.shared.error("❌ No password available in profile", source: "SwiftTermService")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Запускаем процесс
                    try process.run()
                    LoggingService.shared.success("🚀 SSH process started successfully", source: "SwiftTermService")
                    
                    // Если используется парольная аутентификация, отправляем пароль сразу
                    if profile.keyType == .password, let password = profile.password, !password.isEmpty {
                        LoggingService.shared.info("🔑 Sending password immediately after connection...", source: "SwiftTermService")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let passwordData = (password + "\n").data(using: .utf8) ?? Data()
                            if let inputPipe = process.standardInput as? Pipe {
                                inputPipe.fileHandleForWriting.write(passwordData)
                                LoggingService.shared.success("✅ Password sent to SSH process immediately", source: "SwiftTermService")
                            } else {
                                LoggingService.shared.error("❌ Failed to get input pipe for immediate password", source: "SwiftTermService")
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.terminalView = terminal
                        self.sshProcess = process
                        self.currentProfile = profile
                        self.isConnected = true
                        self.isLoading = false
                        self.connectionStatus = "Подключен к \(profile.host)"
                        
                        LoggingService.shared.debug("SwiftTerm SSH connection established", source: "SwiftTermService")
                        continuation.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.connectionStatus = "Ошибка подключения: \(error.localizedDescription)"
                        LoggingService.shared.debug("SwiftTerm SSH connection failed: \(error)", source: "SwiftTermService")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    @MainActor
    func sendCommand(_ command: String) {
        guard let process = sshProcess, isConnected else { return }
        
        let commandData = (command + "\n").data(using: .utf8) ?? Data()
        if let inputPipe = process.standardInput as? Pipe {
            inputPipe.fileHandleForWriting.write(commandData)
        }
    }
    
    func sendData(_ data: [UInt8]) {
        guard let process = sshProcess, isConnected else { 
            LoggingService.shared.error("❌ Cannot send data - process not available or not connected", source: "SwiftTermService")
            return 
        }
        
        let data = Data(data)
        if let inputPipe = process.standardInput as? Pipe {
            inputPipe.fileHandleForWriting.write(data)
            
            // Логируем для отладки
            if let text = String(data: data, encoding: .utf8) {
                LoggingService.shared.info("📤 Sending to SSH: '\(text.replacingOccurrences(of: "\n", with: "\\n"))'", source: "SwiftTermService")
            }
        } else {
            LoggingService.shared.error("❌ Failed to get input pipe for sending data", source: "SwiftTermService")
        }
    }
    
    func disconnect() {
        guard isConnected && !isDisconnecting else { return }
        
        isDisconnecting = true
        LoggingService.shared.debug("Disconnecting SwiftTerm SSH session", source: "SwiftTermService")
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Отключено"
            
            // Завершаем SSH процесс
            if let process = self.sshProcess, process.isRunning {
                process.terminate()
            }
            
            // Очищаем ссылки
            self.terminalView = nil
            self.sshProcess = nil
            self.currentProfile = nil
            
            LoggingService.shared.debug("SwiftTerm SSH session disconnected", source: "SwiftTermService")
        }
    }
    
    func getTerminalView() -> TerminalView? {
        return terminalView
    }
    
    private func buildSSHCommand(for profile: Profile) throws -> String {
        var command = "/usr/bin/ssh"
        
        // Добавляем опции для принудительного создания псевдо-терминала и интерактивности
        command += " -t -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        
        // Принудительно включаем парольную аутентификацию
        if profile.keyType == .password {
            command += " -o PreferredAuthentications=password,keyboard-interactive"
            command += " -o PubkeyAuthentication=no"
            
            // Используем sshpass для неинтерактивной отправки пароля
            if let password = profile.password, !password.isEmpty {
                command = "/opt/homebrew/bin/sshpass -p '\(password)' " + command
            }
        }
        
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
    
    private func parseCommand(_ command: String) -> (String, [String]) {
        let components = command.components(separatedBy: " ").filter { !$0.isEmpty }
        guard !components.isEmpty else { return ("", []) }
        
        let executable = components[0]
        let arguments = Array(components.dropFirst())
        
        return (executable, arguments)
    }
    
    deinit {
        LoggingService.shared.debug("SwiftTermService deinit", source: "SwiftTermService")
        disconnect()
    }
}
