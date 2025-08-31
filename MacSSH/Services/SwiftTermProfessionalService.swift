import Foundation
import AppKit
import SwiftUI
import SwiftTerm

// SSHConnectionError уже определен в модуле

class SwiftTermProfessionalService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var connectionStatus: String = ""
    @Published var currentOutput: String = ""
    
    private var terminalView: TerminalView?
    private var sshProcess: Process?
    private var currentProfile: Profile?
    private var isDisconnecting = false
    // Tracks if we just sent a command with sudo and are expecting a password prompt
    private var awaitingSudoPassword: Bool = false
    // Debounce repeated password sends while the same prompt is visible
    private var recentlySentPassword: Bool = false
    
    // Coalesce high-frequency buffer change notifications to avoid UI thrash
    private let bufferDebounceQueue = DispatchQueue(label: "macssh.terminal.buffer.debounce")
    private var bufferDebounceWorkItem: DispatchWorkItem?
    private let bufferDebounceInterval: TimeInterval = 0.08
    private var bufferCoalescedCount: Int = 0
    
    @MainActor
    func connectToSSH(profile: Profile) async throws {
        LoggingService.shared.debug("Starting SwiftTerm SSH connection to \(profile.host)", source: "SwiftTermService")
        
        self.isLoading = true
        self.isConnected = false
        self.connectionStatus = "Connecting..."
        
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
        
        // Устанавливаем SSHPASS если используется парольная аутентификация
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            environment["SSHPASS"] = password
            LoggingService.shared.info("🔧 Set SSHPASS environment variable", source: "SwiftTermService")
        }
        
        process.environment = environment
                    
                    // Обработка вывода процесса
                    outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            DispatchQueue.main.async {
                                let bytes = Array(data)
                                terminal.feed(byteArray: bytes[...])
                                
                                // Сохраняем вывод для GPT анализа
                                if let output = String(data: data, encoding: .utf8) {
                                    // Cap buffer size to avoid memory bloat and UI thrash
                                    self?.currentOutput += output
                                    let maxChars = 200_000
                                    if let co = self?.currentOutput, co.count > maxChars {
                                        self?.currentOutput = String(co.suffix(maxChars))
                                    }
                                    
                                    // Уведомляем об изменении буфера
                                    self?.notifyBufferChanged()
                                    
                                    // Проверяем, нужно ли отправить пароль (ssh/sudo). Для sudo распознаем расширенно.
                                    // Сканируем хвост всего буфера, чтобы не терять разрезанные по чанкам строки
                                    let tailLower = (self?.currentOutput.suffix(512).lowercased() ?? output.lowercased())
                                    let isSudoPrompt = tailLower.contains("[sudo]") || tailLower.contains("password for ") || tailLower.contains("sudo password") || tailLower.contains("пароль для ")
                                    let isGenericPasswordPrompt = tailLower.contains("password:") || tailLower.contains("пароль:")
                                    let shouldReplyToPrompt = isSudoPrompt || ((self?.awaitingSudoPassword ?? false) && isGenericPasswordPrompt)
                                    if shouldReplyToPrompt && !(self?.recentlySentPassword ?? false) {
                                        LoggingService.shared.warning("🔐 Password prompt detected (sudo/ssh)", source: "SwiftTermService")
                                        if let profile = self?.currentProfile, let password = profile.password, !password.isEmpty {
                                            self?.recentlySentPassword = true
                                            // auto-reset debounce to allow next prompt later
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.recentlySentPassword = false }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                let passwordData = (password + "\n").data(using: .utf8) ?? Data()
                                                if let inputPipe = process.standardInput as? Pipe {
                                                    inputPipe.fileHandleForWriting.write(passwordData)
                                                    LoggingService.shared.success("✅ Password sent automatically", source: "SwiftTermService")
                                                    // Reset sudo wait flag after send
                                                    self?.awaitingSudoPassword = false
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
                    
                    // sshpass -e автоматически обрабатывает парольную аутентификацию
                    if profile.keyType == .password, let password = profile.password, !password.isEmpty {
                        LoggingService.shared.success("✅ sshpass -e will handle password authentication automatically", source: "SwiftTermService")
                    }
                    
                    DispatchQueue.main.async {
                        self.terminalView = terminal
                        self.sshProcess = process
                        self.currentProfile = profile
                        self.isConnected = true
                        self.isLoading = false
                        self.connectionStatus = "Connected to \(profile.host)"
                        
                        LoggingService.shared.debug("SwiftTerm SSH connection established", source: "SwiftTermService")
                        continuation.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.connectionStatus = "Connection error: \(error.localizedDescription)"
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
        
        // If command involves sudo, set expectation for sudo password prompt briefly
        let lower = command.lowercased()
        if lower.contains("sudo ") || lower.hasPrefix("sudo") {
            awaitingSudoPassword = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in self?.awaitingSudoPassword = false }
        }
        
        let commandData = (command + "\n").data(using: .utf8) ?? Data()
        if let inputPipe = process.standardInput as? Pipe {
            inputPipe.fileHandleForWriting.write(commandData)
            // Триггерим возможное ожидание
            notifyBufferChanged()
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
    
    // Method to notify about buffer changes for command completion detection (throttled)
    func notifyBufferChanged() {
        // Avoid posting notifications when there is no active connection or terminal view
        guard self.isConnected, self.terminalView != nil else { return }
        bufferDebounceQueue.async {
            self.bufferCoalescedCount += 1
            self.bufferDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                let coalesced = self.bufferCoalescedCount
                self.bufferCoalescedCount = 0
                DispatchQueue.main.async {
                    LoggingService.shared.debug("📊 Buffer changed (coalesced \(coalesced))", source: "SwiftTermService")
                    NotificationCenter.default.post(name: .terminalBufferChanged, object: nil)
                }
            }
            self.bufferDebounceWorkItem = work
            self.bufferDebounceQueue.asyncAfter(deadline: .now() + self.bufferDebounceInterval, execute: work)
        }
    }
    
    // MARK: - Terminal output access
    func getCurrentOutput() async -> String? {
        return currentOutput
    }
    
    func clearOutput() {
        currentOutput = ""
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
    
    // Expose current profile for context-aware features
    func getCurrentProfile() -> Profile? {
        return currentProfile
    }
    
// MARK: - SSH Command Building
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
                // Проверяем доступность sshpass
                if !SSHService.checkSSHPassAvailability() {
                    throw SSHConnectionError.sshpassNotInstalled("sshpass is required for automatic password transmission in SSH connections. Install it with: brew install sshpass")
                }
                // Попробуем через переменную окружения (более безопасно)
                command = "/opt/homebrew/bin/sshpass -e " + command
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
