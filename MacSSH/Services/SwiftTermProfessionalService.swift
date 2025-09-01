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
    private var localProcess: LocalProcess?
    
    // Coalesce high-frequency buffer change notifications to avoid UI thrash
    private let bufferDebounceQueue = DispatchQueue(label: "macssh.terminal.buffer.debounce")
    private var bufferDebounceWorkItem: DispatchWorkItem?
    private let bufferDebounceInterval: TimeInterval = 0.08
    private var bufferCoalescedCount: Int = 0
    
    @MainActor
    func connectToSSH(profile: Profile) async throws {
        // Local profile: start local shell instead of SSH
        if (profile.isLocal ?? false) {
            try await connectToLocalShell()
            return
        }
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
                                    
                                    // No automatic password submission
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
    private func connectToLocalShell() async throws {
        LoggingService.shared.debug("Starting SwiftTerm local shell session", source: "SwiftTermService")
        self.isLoading = true
        self.isConnected = false
        self.connectionStatus = "Starting local shell..."

        // Prepare terminal view (white background, black text)
        let terminal = TerminalView()
        terminal.configureNativeColors()
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminal.nativeBackgroundColor = .white
        terminal.nativeForegroundColor = .black
        self.terminalView = terminal

        // Create LocalProcess with PTY
        let lp = LocalProcess(delegate: self)
        self.localProcess = lp
        self.currentProfile = Profile(
            id: UUID(),
            name: "This Mac",
            host: "localhost",
            port: 22,
            username: NSUserName(),
            password: nil,
            privateKeyPath: nil,
            keyType: .none,
            lastConnectionDate: nil,
            description: "Local machine access",
            isLocal: true
        )

        // Determine shell
        let userShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        // Start local process with pseudo-terminal
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        // Ensure a reasonable PATH (Homebrew + system)
        env.append("PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH")
        lp.startProcess(
            executable: userShell,
            args: ["-l"],
            environment: env,
            execName: nil,
            currentDirectory: NSHomeDirectory()
        )

        LoggingService.shared.success("🚀 Local shell process started (PTY)", source: "SwiftTermService")
        self.isConnected = true
        self.isLoading = false
        self.connectionStatus = "Local shell"

        // Do not auto-send Enter; rely on shell prompt
    }
    
    @MainActor
    func sendCommand(_ command: String) {
        // Prefer local PTY when available
        if let lp = localProcess, isConnected {
            let data = Array((command + "\n").utf8)
            lp.send(data: ArraySlice(data))
            notifyBufferChanged()
            return
        }
        // Fallback to SSH process
        guard let process = sshProcess, isConnected else { return }
        let commandData = (command + "\n").data(using: .utf8) ?? Data()
        if let inputPipe = process.standardInput as? Pipe {
            inputPipe.fileHandleForWriting.write(commandData)
            notifyBufferChanged()
        }
    }
    
    func sendData(_ data: [UInt8]) {
        if let lp = localProcess, isConnected {
            lp.send(data: ArraySlice(data))
            if let text = String(data: Data(data), encoding: .utf8) {
                LoggingService.shared.info("📤 Sending to Local Shell: '\(text.replacingOccurrences(of: "\n", with: "\\n"))'", source: "SwiftTermService")
            }
            return
        }
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
    
    // Update PTY size for local process when terminal resizes
    func updateLocalPTYSize(cols: Int, rows: Int) {
        guard let lp = localProcess, lp.running else { return }
        // Ensure positive sizes; fallback to current terminal cols/rows
        var safeCols = cols
        var safeRows = rows
        if safeCols <= 0 || safeRows <= 0 {
            if let term = terminalView?.terminal {
                safeCols = max(1, term.cols)
                safeRows = max(1, term.rows)
            } else {
                return
            }
        }
        var size = winsize()
        size.ws_row = UInt16(clamping: safeRows)
        size.ws_col = UInt16(clamping: safeCols)
        size.ws_xpixel = 0
        size.ws_ypixel = 0
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: lp.childfd, windowSize: &size)
    }
    
    // MARK: - Terminal output access
    func getCurrentOutput() async -> String? {
        return currentOutput
    }
    
    func clearOutput() {
        currentOutput = ""
    }
    
    func disconnect() {
        guard !isDisconnecting else { return }
        isDisconnecting = true
        LoggingService.shared.debug("Disconnecting terminal session", source: "SwiftTermService")
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Отключено"
            // Terminate SSH process if present
            if let process = self.sshProcess, process.isRunning {
                process.terminate()
            }
            // Terminate local process if present
            self.localProcess?.terminate()
            self.localProcess = nil
            // Cleanup
            self.terminalView = nil
            self.sshProcess = nil
            self.currentProfile = nil
            LoggingService.shared.debug("Terminal session disconnected", source: "SwiftTermService")
        }
    }
    
    func getTerminalView() -> TerminalView? {
        return terminalView
    }
    
    // Expose current profile for context-aware features
    func getCurrentProfile() -> Profile? {
        return currentProfile
    }

    // Indicates if a local PTY session is active
    func isLocalSessionActive() -> Bool {
        return localProcess != nil && isConnected
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

// MARK: - LocalProcessDelegate
extension SwiftTermProfessionalService: LocalProcessDelegate {
    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Local shell terminated"
        }
    }
    
    func dataReceived(slice: ArraySlice<UInt8>) {
        let bytes = Array(slice)
        DispatchQueue.main.async {
            if let terminal = self.terminalView {
                terminal.feed(byteArray: bytes[...])
            }
            if let text = String(data: Data(bytes), encoding: .utf8) {
                self.currentOutput += text
                let maxChars = 200_000
                if self.currentOutput.count > maxChars {
                    self.currentOutput = String(self.currentOutput.suffix(maxChars))
                }
                self.notifyBufferChanged()
            }
        }
    }
    
    func getWindowSize() -> winsize {
        if let tv = terminalView, let term = tv.terminal {
            var size = winsize()
            size.ws_row = UInt16(term.rows)
            size.ws_col = UInt16(term.cols)
            size.ws_xpixel = 0
            size.ws_ypixel = 0
            return size
        }
        return winsize()
    }
}
