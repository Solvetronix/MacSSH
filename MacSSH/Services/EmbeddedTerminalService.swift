import Foundation
import AppKit
import SwiftUI

// SSHConnectionError уже определен в модуле

class EmbeddedTerminalService: ObservableObject {
    @Published var output: String = ""
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var currentProfile: Profile?
    private var sshSessionReady = false
    private var isDisconnecting = false // Защита от множественных вызовов disconnect
    
    @MainActor
    func connectToSSH(profile: Profile) async throws {
        LoggingService.shared.debug("Starting SSH connection to \(profile.host)", source: "EmbeddedTerminalService")
        
        self.isLoading = true
        self.output = ""
        self.isConnected = false
        
        LoggingService.shared.debug("Service state initialized", source: "EmbeddedTerminalService")
        
        // Проверяем разрешения
        LoggingService.shared.debug("Checking permissions", source: "EmbeddedTerminalService")
        
        if !PermissionsService.forceCheckPermissions() {
            LoggingService.shared.debug("Permissions check failed", source: "EmbeddedTerminalService")
            throw SSHConnectionError.permissionDenied("Full Disk Access not granted")
        }
        
        LoggingService.shared.debug("Permissions check passed", source: "EmbeddedTerminalService")
        
        // Создаем процесс SSH
        LoggingService.shared.debug("Creating SSH process", source: "EmbeddedTerminalService")
        
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        
        // Строим SSH команду
        let sshCommand = try buildSSHCommand(for: profile)
        LoggingService.shared.debug("SSH command built: \(sshCommand)", source: "EmbeddedTerminalService")
        
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", sshCommand]
        
        // Устанавливаем переменные окружения для терминала
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLUMNS"] = "80"
        env["LINES"] = "24"
        process.environment = env
        
        // Настраиваем pipes
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // Обработка вывода - используем отдельный метод в фоновом потоке
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            // Проверяем, что self еще существует и подключен
            guard let self = self, self.isConnected else {
                LoggingService.shared.debug("ReadabilityHandler called but service is nil or disconnected", source: "EmbeddedTerminalService")
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.handleSSHOutput(handle)
            }
        }
        
        // Обработка завершения процесса - используем отдельный метод
        process.terminationHandler = { [weak self] process in
            // Проверяем, что self еще существует
            guard let self = self else {
                LoggingService.shared.debug("TerminationHandler called but service is nil", source: "EmbeddedTerminalService")
                return
            }
            
            DispatchQueue.main.async {
                self.handleProcessTermination(process)
            }
        }
        
        // Запускаем процесс в отдельном потоке для предотвращения блокировки UI
        LoggingService.shared.debug("Starting SSH process in background", source: "EmbeddedTerminalService")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try process.run()
                LoggingService.shared.debug("SSH process started successfully", source: "EmbeddedTerminalService")
                
                // Добавляем таймаут для предотвращения зависания (уменьшаем до 10 секунд)
                DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                    if let self = self, self.isConnected && !self.sshSessionReady {
                        LoggingService.shared.debug("SSH connection timeout - no prompt detected after 10 seconds", source: "EmbeddedTerminalService")
                        LoggingService.shared.debug("Current output length: \(self.output.count)", source: "EmbeddedTerminalService")
                        LoggingService.shared.debug("Last 500 chars of output: '\(self.output.suffix(500))'", source: "EmbeddedTerminalService")
                        
                        // Проверяем состояние SSH процесса
                        if let process = self.process {
                            LoggingService.shared.debug("SSH process isRunning: \(process.isRunning)", source: "EmbeddedTerminalService")
                            LoggingService.shared.debug("SSH process terminationStatus: \(process.terminationStatus)", source: "EmbeddedTerminalService")
                        } else {
                            LoggingService.shared.debug("SSH process is nil", source: "EmbeddedTerminalService")
                        }
                        
                        DispatchQueue.main.async {
                            self.sshSessionReady = true // Принудительно помечаем как готовую
                        }
                    }
                }
            } catch {
                LoggingService.shared.debug("Failed to start SSH process: \(error)", source: "EmbeddedTerminalService")
                DispatchQueue.main.async {
                    // Обрабатываем ошибку в главном потоке
                    self.isLoading = false
                    self.isConnected = false
                }
            }
        }
        
        // Сохраняем ссылки
        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.currentProfile = profile
        
        LoggingService.shared.debug("Process references saved", source: "EmbeddedTerminalService")
        
        self.isConnected = true
        self.isLoading = false
        
        LoggingService.shared.debug("SSH connection established successfully", source: "EmbeddedTerminalService")
        
        // Добавляем приветственное сообщение
        self.appendOutput("Connected to \(profile.host) as \(profile.username)\n")
        
        LoggingService.shared.debug("Welcome message added to output", source: "EmbeddedTerminalService")
        
        // Инициализируем флаг для отслеживания готовности SSH сессии
        self.sshSessionReady = false
        LoggingService.shared.debug("SSH session initialized, waiting for prompt", source: "EmbeddedTerminalService")
        
        LoggingService.shared.debug("Connection setup completed", source: "EmbeddedTerminalService")
    }
    
    @MainActor
    func sendCommand(_ command: String) {
        guard let inputPipe = inputPipe, isConnected else { return }
        
        // Команда уже отображается в TerminalCommandLineView, не дублируем
        
        // Отправляем команду в SSH процесс
        let commandData = (command + "\n").data(using: .utf8) ?? Data()
        inputPipe.fileHandleForWriting.write(commandData)
        
        // Принудительно сбрасываем буфер (убираем synchronizeFile для pipe'ов)
        // inputPipe.fileHandleForWriting.synchronizeFile() // Эта операция не поддерживается для pipe'ов
    }
    
    func disconnect() {
        // Защита от множественных вызовов
        guard isConnected && !isDisconnecting else {
            LoggingService.shared.debug("Disconnect called but already disconnected or disconnecting", source: "EmbeddedTerminalService")
            return
        }
        
        isDisconnecting = true
        
        LoggingService.shared.debug("=== DISCONNECT START ===", source: "EmbeddedTerminalService")
        
        // Сначала обновляем состояние
        self.isConnected = false
        
        // 1. БЕЗОПАСНО отключаем обработчик вывода (основная причина краша)
        if let outputPipe = outputPipe {
            // Важно: сначала отключаем обработчик, потом закрываем файл
            outputPipe.fileHandleForReading.readabilityHandler = nil
            
            // Закрываем файл безопасно
            do {
                try outputPipe.fileHandleForReading.close()
                LoggingService.shared.debug("FileHandle safely closed", source: "EmbeddedTerminalService")
            } catch {
                LoggingService.shared.debug("Error closing FileHandle: \(error)", source: "EmbeddedTerminalService")
            }
            
            LoggingService.shared.debug("Readability handler disabled and FileHandle closed", source: "EmbeddedTerminalService")
        }
        
        // 2. БЕЗОПАСНО завершаем SSH процесс
        if let process = process, process.isRunning {
            LoggingService.shared.debug("Terminating SSH process", source: "EmbeddedTerminalService")
            
            // Сначала мягкое завершение
            process.terminate()
            
            // Даем процессу время на завершение
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if process.isRunning {
                    LoggingService.shared.debug("Force killing SSH process", source: "EmbeddedTerminalService")
                    process.interrupt()
                    
                    // Если все еще работает, принудительно завершаем
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        if process.isRunning {
                            LoggingService.shared.debug("Force terminating SSH process", source: "EmbeddedTerminalService")
                            process.terminate()
                        }
                    }
                }
            }
        }
        
        // 3. Очищаем ссылки в безопасном порядке
        LoggingService.shared.debug("Clearing references", source: "EmbeddedTerminalService")
        
        let oldProcess = process
        let oldInputPipe = inputPipe
        let oldOutputPipe = outputPipe
        let oldProfile = currentProfile
        
        // Очищаем ссылки
        process = nil
        inputPipe = nil
        outputPipe = nil
        currentProfile = nil
        
        // 4. Добавляем сообщение об отключении
        DispatchQueue.main.async { [weak self] in
            self?.appendOutput("\nDisconnected from SSH session.\n")
        }
        
        // 5. Логируем очистку
        LoggingService.shared.debug("Process reference cleared: \(oldProcess != nil)", source: "EmbeddedTerminalService")
        LoggingService.shared.debug("Input pipe reference cleared: \(oldInputPipe != nil)", source: "EmbeddedTerminalService")
        LoggingService.shared.debug("Output pipe reference cleared: \(oldOutputPipe != nil)", source: "EmbeddedTerminalService")
        LoggingService.shared.debug("Profile reference cleared: \(oldProfile != nil)", source: "EmbeddedTerminalService")
        
        LoggingService.shared.debug("=== DISCONNECT COMPLETED ===", source: "EmbeddedTerminalService")
    }
    
    private func appendOutput(_ text: String) {
        // Дополнительная проверка состояния
        guard isConnected && !isDisconnecting else {
            LoggingService.shared.debug("appendOutput called but service is disconnected or disconnecting", source: "EmbeddedTerminalService")
            return
        }
        
        // Очищаем ANSI escape-коды из текста
        let cleanedText = cleanANSIEscapeCodes(text)
        output += cleanedText
        
        // Добавляем подробное логирование для отладки
        LoggingService.shared.debug("appendOutput called with text: '\(text.prefix(200))'", source: "EmbeddedTerminalService")
        LoggingService.shared.debug("sshSessionReady: \(sshSessionReady)", source: "EmbeddedTerminalService")
        LoggingService.shared.debug("text.contains('$'): \(text.contains("$"))", source: "EmbeddedTerminalService")
        
        // Проверяем, появился ли промпт (признак готовности SSH сессии)
        if !sshSessionReady && cleanedText.contains("$") {
            sshSessionReady = true
            LoggingService.shared.debug("SSH prompt detected, session is ready", source: "EmbeddedTerminalService")
            LoggingService.shared.debug("SSH session is ready for commands", source: "EmbeddedTerminalService")
        }
    }
    
    private func cleanANSIEscapeCodes(_ text: String) -> String {
        // Улучшенное регулярное выражение для удаления ANSI escape-кодов
        // Обрабатываем все основные типы ANSI кодов
        var cleanedText = text
        
        // Удаляем escape-последовательности для цветов и форматирования
        let colorPattern = #"\x1B\[[0-9;]*[mGK]|\x1B\[[?]2004[hl]|\x1B\[[?]1[hl]|\x1B\[[?]25[hl]|\x1B\[[?]1049[hl]"#
        cleanedText = cleanedText.replacingOccurrences(of: colorPattern, with: "", options: .regularExpression)
        
        // Удаляем escape-последовательности для изменения заголовка окна
        let titlePattern = #"\x1B\]0;[^\x07]*\x07"#
        cleanedText = cleanedText.replacingOccurrences(of: titlePattern, with: "", options: .regularExpression)
        
        // Удаляем другие escape-последовательности
        let otherPattern = #"\x1B\[[0-9;]*[a-zA-Z]"#
        cleanedText = cleanedText.replacingOccurrences(of: otherPattern, with: "", options: .regularExpression)
        
        return cleanedText
    }
    

    
    private func buildSSHCommand(for profile: Profile) throws -> String {
        var command = ""
        
        // Если используется пароль, проверяем наличие sshpass
        if profile.keyType == .password, let password = profile.password, !password.isEmpty {
            if !SSHService.checkSSHPassAvailability() {
                throw SSHConnectionError.sshpassNotInstalled("sshpass is required for automatic password transmission in SSH connections. Install it with: brew install sshpass")
            }
            // Используем полный путь к sshpass для надежности
            guard let sshpassPath = SSHService.getSSHPassPath() else {
                throw SSHConnectionError.sshpassNotInstalled("sshpass не найден в системе. Установите его командой: brew install sshpass")
            }
            command = "\(sshpassPath) -p '\(password)' ssh"
        } else {
            command = "ssh"
        }
        
        // Добавляем опции для автоматического принятия fingerprint'а и лучшей совместимости
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
    
    deinit {
        LoggingService.shared.debug("=== DEINIT START ===", source: "EmbeddedTerminalService")
        
        // БЕЗОПАСНАЯ очистка в deinit (критически важно!)
        
        // Устанавливаем флаг отключения
        isDisconnecting = true
        isConnected = false
        
        // 1. Отключаем обработчик вывода
        if let outputPipe = outputPipe {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            
            // Безопасно закрываем FileHandle
            do {
                try outputPipe.fileHandleForReading.close()
                LoggingService.shared.debug("FileHandle closed in deinit", source: "EmbeddedTerminalService")
            } catch {
                LoggingService.shared.debug("Error closing FileHandle in deinit: \(error)", source: "EmbeddedTerminalService")
            }
        }
        
        // 2. Завершаем процесс если он еще работает
        if let process = process, process.isRunning {
            LoggingService.shared.debug("Terminating process in deinit", source: "EmbeddedTerminalService")
            process.terminate()
        }
        
        // 3. Очищаем ссылки
        process = nil
        inputPipe = nil
        outputPipe = nil
        currentProfile = nil
        
        LoggingService.shared.debug("=== DEINIT COMPLETED ===", source: "EmbeddedTerminalService")
    }
    
    // MARK: - Private Handler Methods
    
    private func handleSSHOutput(_ handle: FileHandle) {
        // Дополнительная проверка состояния
        guard isConnected && !isDisconnecting else {
            LoggingService.shared.debug("handleSSHOutput called but service is disconnected or disconnecting", source: "EmbeddedTerminalService")
            return
        }
        
        // Проверяем, что handle еще валиден
        guard handle.fileDescriptor >= 0 else {
            LoggingService.shared.debug("FileHandle is invalid, skipping output", source: "EmbeddedTerminalService")
            return
        }
        
        let data = handle.availableData
        if data.isEmpty {
            return // Пропускаем пустые данные
        }
        
        if let output = String(data: data, encoding: .utf8) {
            LoggingService.shared.debug("Received SSH output: \(output.prefix(100))", source: "EmbeddedTerminalService")
            // Обновляем UI в главном потоке
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isConnected && !self.isDisconnecting else {
                    LoggingService.shared.debug("appendOutput called but service is nil, disconnected, or disconnecting", source: "EmbeddedTerminalService")
                    return
                }
                self.appendOutput(output)
            }
        } else {
            LoggingService.shared.debug("Failed to decode SSH output as UTF-8", source: "EmbeddedTerminalService")
        }
    }
    
    private func handleProcessTermination(_ process: Process) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                LoggingService.shared.debug("handleProcessTermination called but service is nil", source: "EmbeddedTerminalService")
                return 
            }
            
            LoggingService.shared.debug("SSH process terminated with exit code: \(process.terminationStatus)", source: "EmbeddedTerminalService")
            
            // Обновляем состояние только если еще подключены и не в процессе отключения
            if self.isConnected && !self.isDisconnecting {
                self.isConnected = false
                self.isDisconnecting = true
                self.appendOutput("\nSSH session terminated (exit code: \(process.terminationStatus))\n")
                
                // БЕЗОПАСНО очищаем ресурсы
                if let outputPipe = self.outputPipe {
                    // Отключаем обработчик и закрываем FileHandle
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    do {
                        try outputPipe.fileHandleForReading.close()
                        LoggingService.shared.debug("FileHandle closed after process termination", source: "EmbeddedTerminalService")
                    } catch {
                        LoggingService.shared.debug("Error closing FileHandle after termination: \(error)", source: "EmbeddedTerminalService")
                    }
                }
                
                // Очищаем ссылки
                self.process = nil
                self.inputPipe = nil
                self.outputPipe = nil
                self.currentProfile = nil
                LoggingService.shared.debug("Resources cleaned up after process termination", source: "EmbeddedTerminalService")
            }
        }
    }
}
