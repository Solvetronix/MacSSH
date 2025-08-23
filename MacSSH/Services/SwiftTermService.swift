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
        
        // Проверяем разрешения
        if !PermissionsService.forceCheckPermissions() {
            throw SSHConnectionError.permissionDenied("Full Disk Access не предоставлен")
        }
        
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
                    
                    // Обработка вывода процесса
                    outputPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            DispatchQueue.main.async {
                                let bytes = Array(data)
                                terminal.feed(byteArray: bytes[...])
                            }
                        }
                    }
                    
                    // Запускаем процесс
                    try process.run()
                    
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
        var command = ""
        
        // Если используется пароль, проверяем наличие sshpass
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            if !SSHService.checkSSHPassAvailability() {
                throw SSHConnectionError.sshpassNotInstalled("sshpass не установлен")
            }
            guard let sshpassPath = SSHService.getSSHPassPath() else {
                throw SSHConnectionError.sshpassNotInstalled("sshpass не найден в системе")
            }
            command = "\(sshpassPath) -p '\(password)' ssh"
        } else {
            command = "ssh"
        }
        
        // Добавляем опции для автоматического принятия fingerprint'а
        command += " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t -t"
        
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
