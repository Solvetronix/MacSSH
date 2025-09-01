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
    // Cached summary of remote machine environment (OS, arch, package manager, etc.)
    private var remoteDeviceContext: String = ""
    
    // Build cache key for remote environment context
    private func remoteEnvCacheKey(for profile: Profile) -> String {
        return "remote_env::\(profile.username)@\(profile.host):\(profile.port)"
    }
    
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
                        // Remote env context: use cache if available, otherwise collect once
                        let key = self.remoteEnvCacheKey(for: profile)
                        if let cached = UserDefaults.standard.string(forKey: key), !cached.isEmpty {
                            self.remoteDeviceContext = cached
                            LoggingService.shared.info("🔎 Using cached remote env context", source: "SwiftTermService")
                        } else {
                            self.remoteDeviceContext = ""
                            Task { await self.collectRemoteEnvironmentInfo() }
                        }
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

    // MARK: - Remote environment discovery
    /// Collect a concise summary of the remote system to help GPT reason about environment.
    /// Runs lightweight, safe commands, coalesces output, and caches a single-line summary.
    private func collectRemoteEnvironmentInfo() async {
        guard sshProcess != nil, let profile = currentProfile, (profile.isLocal ?? false) == false else { return }
        LoggingService.shared.info("🔎 Collecting remote environment info...", source: "SwiftTermService")
        let probe = [
            // Try standard identifiers first
            "echo OS=$(uname -s) KERNEL=$(uname -r) ARCH=$(uname -m)",
            // Linux distro info (gracefully degrade)
            "if command -v lsb_release >/dev/null 2>&1; then echo DISTRO=$(lsb_release -ds); fi",
            "if [ -f /etc/os-release ]; then . /etc/os-release; echo DISTRO=\"${PRETTY_NAME}\"; fi",
            // macOS fallback (in case SSH to macOS)
            "if [ \"$(uname -s)\" = \"Darwin\" ]; then echo MACOS=$(sw_vers -productVersion); fi",
            // Package manager hints
            "for pm in apt yum dnf pacman zypper apk brew port; do command -v $pm >/dev/null 2>&1 && echo PM=$pm; done",
            // Shell and user
            "echo USER=$USER SHELL=$SHELL",
            // CPU count (safe, common)
            "if command -v nproc >/dev/null 2>&1; then echo CPU=$(nproc); elif [ -f /proc/cpuinfo ]; then echo CPU=$(grep -c '^processor' /proc/cpuinfo); fi",
        ].joined(separator: "; ")

        await MainActor.run { self.sendCommand(probe) }
        // Wait briefly and use our reliable completion to settle output
        let reliable = ReliableCommandCompletion(terminalService: self)
        _ = await reliable.waitForCommandCompletion(command: "__probe_remote_env__")

        // Snapshot current output and extract only the tail we just produced
        let full = await getCurrentOutput() ?? ""
        // Extract last ~2k chars for parsing
        let tail = String(full.suffix(2000))
        // Parse key=value pairs
        var os: String = ""
        var kernel: String = ""
        var arch: String = ""
        var distro: String = ""
        var macos: String = ""
        var pm: String = ""
        var user: String = ""
        var shell: String = ""
        var cpu: String = ""

        func capture(_ key: String, from text: String) -> String? {
            // Simple regex-like scan without regex dependency
            // Looks for lines containing KEY=VALUE and returns VALUE
            for line in text.split(separator: "\n").map(String.init).reversed() {
                if line.hasPrefix(key + "=") {
                    return String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
            return nil
        }

        os = capture("OS", from: tail) ?? ""
        kernel = capture("KERNEL", from: tail) ?? ""
        arch = capture("ARCH", from: tail) ?? ""
        distro = capture("DISTRO", from: tail) ?? ""
        macos = capture("MACOS", from: tail) ?? ""
        pm = capture("PM", from: tail) ?? ""
        user = capture("USER", from: tail) ?? ""
        shell = capture("SHELL", from: tail) ?? ""
        cpu = capture("CPU", from: tail) ?? ""

        var parts: [String] = []
        parts.append("Host: \(profile.username)@\(profile.host)")
        if !distro.isEmpty { parts.append("Distro: \(distro)") }
        if !macos.isEmpty { parts.append("macOS: \(macos)") }
        if !os.isEmpty { parts.append("OS: \(os)") }
        if !kernel.isEmpty { parts.append("Kernel: \(kernel)") }
        if !arch.isEmpty { parts.append("Arch: \(arch)") }
        if !pm.isEmpty { parts.append("PM: \(pm)") }
        if !user.isEmpty { parts.append("User: \(user)") }
        if !shell.isEmpty { parts.append("Shell: \(shell)") }
        if !cpu.isEmpty { parts.append("CPU: \(cpu)") }

        let summary = parts.joined(separator: " | ")
        LoggingService.shared.info("🔎 Remote env: \(summary)", source: "SwiftTermService")
        self.remoteDeviceContext = summary
        if let profile = self.currentProfile {
            let key = self.remoteEnvCacheKey(for: profile)
            UserDefaults.standard.set(summary, forKey: key)
        }
    }
    
    func getTerminalView() -> TerminalView? {
        return terminalView
    }
    
    // Expose current profile for context-aware features
    func getCurrentProfile() -> Profile? {
        return currentProfile
    }
    
    // Expose remote device context summary for GPT prompts
    func getRemoteDeviceContext() -> String {
        return remoteDeviceContext
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
