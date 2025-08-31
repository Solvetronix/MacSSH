import Foundation
import SwiftUI

// Типы сообщений для логирования
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
    
    var icon: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// Структура для лог-сообщения
struct LogMessage: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let source: String
    let message: String
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LogMessage, rhs: LogMessage) -> Bool {
        return lhs.id == rhs.id
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var displayMessage: String {
        return message
            .replacingOccurrences(of: "[green]", with: "")
            .replacingOccurrences(of: "[yellow]", with: "")
            .replacingOccurrences(of: "[blue]", with: "")
            .replacingOccurrences(of: "[red]", with: "")
            .replacingOccurrences(of: "✅", with: "")
            .replacingOccurrences(of: "❌", with: "")
            .replacingOccurrences(of: "⚠️", with: "")
            .replacingOccurrences(of: "ℹ️", with: "")
            .replacingOccurrences(of: "🔍", with: "")
            .replacingOccurrences(of: "🔄", with: "")
            .replacingOccurrences(of: "🚀", with: "")
            .replacingOccurrences(of: "🔧", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// Централизованный сервис логирования
class LoggingService: ObservableObject {
    static let shared = LoggingService()
    
    @Published var logs: [LogMessage] = []
    // Minimal user-facing logs for in-app log panel (no debug spam)
    @Published var uiLogs: [LogMessage] = []
    @Published var isEnabled: Bool = true
    // Gate for developer logs (debug/info). In production can be disabled via Info.plist key 'DevLoggingEnabled'.
    @Published var devLoggingEnabled: Bool
    
    // Minimum log level to record. In release builds we default to .info
    // to avoid high-frequency debug logging that can cause UI churn and
    // unnecessary energy usage while the app is idle.
    private let minLevel: LogLevel
    
    private init() {
        #if DEBUG
        self.minLevel = .debug
        let defaultDev = true
        #else
        self.minLevel = .info
        let defaultDev = false
        #endif
        if let override = Bundle.main.object(forInfoDictionaryKey: "DevLoggingEnabled") as? Bool {
            self.devLoggingEnabled = override
        } else {
            self.devLoggingEnabled = defaultDev
        }
    }
    
    // Основные методы логирования
    func log(_ message: String, level: LogLevel = .info, source: String = "System") {
        guard isEnabled else { return }
        // Drop logs below the configured minimum level
        let allowed: Bool
        switch (minLevel, level) {
        case (_, .error): allowed = true
        case (.warning, .success): allowed = false
        case (.warning, .info): allowed = false
        case (.warning, .debug): allowed = false
        case (.info, .success): allowed = true
        case (.info, .info): allowed = true
        case (.info, .debug): allowed = false
        case (.success, .success): allowed = true
        case (.success, .info): allowed = false
        case (.success, .debug): allowed = false
        case (.debug, _): allowed = true
        default: allowed = true
        }
        guard allowed else { return }
        
        // Дополнительный гейт: детальные dev-логи (debug) можно отключить
        if level == .debug, !devLoggingEnabled {
            return
        }
        // Выводим в системную консоль для отладки (только разрешенные по гейту)
        let consoleMessage = "[\(level.rawValue)] [\(source)] \(message)"
        print(consoleMessage)
        
        DispatchQueue.main.async {
            let logMessage = LogMessage(
                timestamp: Date(),
                level: level,
                source: source,
                message: message
            )
            self.logs.append(logMessage)
            
            // Ограничиваем количество логов для производительности
            if self.logs.count > 1000 {
                self.logs.removeFirst(100)
            }

            // В UI показываем только информационные логи
            if level == .info {
                let simplified = self.simplifyForUI(logMessage)
                self.appendToUILogsCoalesced(simplified)
            }
        }
    }
    
    // Удобные методы для разных уровней
    func debug(_ message: String, source: String = "System") {
        log(message, level: .debug, source: source)
    }
    
    func info(_ message: String, source: String = "System") {
        log(message, level: .info, source: source)
    }
    
    func success(_ message: String, source: String = "System") {
        log(message, level: .success, source: source)
    }
    
    func warning(_ message: String, source: String = "System") {
        log(message, level: .warning, source: source)
    }
    
    func error(_ message: String, source: String = "System") {
        log(message, level: .error, source: source)
    }

    // MARK: - UI-focused minimal logging helpers
    func ui(_ message: String, level: LogLevel = .info, source: String = "UI") {
        // Only affect UI panel; still print to console for traceability
        let consoleMessage = "[\(level.rawValue)] [\(source)] \(message)"
        print(consoleMessage)
        DispatchQueue.main.async {
            let logMessage = LogMessage(
                timestamp: Date(),
                level: level,
                source: source,
                message: message
            )
            let simplified = self.simplifyForUI(logMessage)
            self.appendToUILogsCoalesced(simplified)
        }
    }
    func uiInfo(_ message: String, source: String = "UI") { ui(message, level: .info, source: source) }
    func uiSuccess(_ message: String, source: String = "UI") { ui(message, level: .success, source: source) }
    func uiWarning(_ message: String, source: String = "UI") { ui(message, level: .warning, source: source) }
    func uiError(_ message: String, source: String = "UI") { ui(message, level: .error, source: source) }
    
    // Очистка логов
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
    
    // Получение логов в текстовом формате для копирования
    func getLogsAsText() -> String {
        return logs.map { log in
            "[\(log.formattedTimestamp)] [\(log.level.rawValue)] [\(log.source)] \(log.message)"
        }.joined(separator: "\n")
    }
    
    // Новый метод для получения сокращенных логов
    func getCompactLogsAsText() -> String {
        let importantLogs = logs.filter { log in
            // Сохраняем все ошибки и предупреждения
            if log.level == .error || log.level == .warning {
                return true
            }
            
            // Сохраняем успешные операции
            if log.level == .success {
                return true
            }
            
            // Для info и debug - сохраняем только ключевые сообщения
            let keyWords = ["error", "failed", "success", "connected", "disconnected", "started", "stopped", "updated", "created", "deleted", "permission", "access", "security", "update", "install", "download", "gpt", "openai", "api", "command", "terminal", "ssh", "executed", "planned", "step", "task", "complete"]
            
            return keyWords.contains { keyword in
                log.message.lowercased().contains(keyword)
            }
        }
        
        // Если важных логов мало, добавляем последние 20 логов
        if importantLogs.count < 10 {
            let recentLogs = Array(logs.suffix(20))
            let combinedLogs = Array(Set(importantLogs + recentLogs)).sorted { $0.timestamp < $1.timestamp }
            return combinedLogs.map { log in
                "[\(log.formattedTimestamp)] [\(log.level.rawValue)] \(log.message)"
            }.joined(separator: "\n")
        }
        
        return importantLogs.map { log in
            "[\(log.formattedTimestamp)] [\(log.level.rawValue)] \(log.message)"
        }.joined(separator: "\n")
    }
    
    // Метод для получения только GPT-связанных логов
    func getGPTLogsAsText() -> String {
        let gptLogs = logs.filter { log in
            let gptKeywords = ["gpt", "openai", "api", "command", "executed", "planned", "step", "task", "complete", "terminal", "ssh"]
            return gptKeywords.contains { keyword in
                log.message.lowercased().contains(keyword) || log.source.lowercased().contains("gpt")
            }
        }
        
        return gptLogs.map { log in
            "[\(log.formattedTimestamp)] [\(log.level.rawValue)] \(log.message)"
        }.joined(separator: "\n")
    }
    
    // Метод для получения кратких логов для отладки
    func getShortLogsAsText() -> String {
        // Берем только последние 30 логов и фильтруем по важности
        let recentLogs = Array(logs.suffix(30))
        let importantLogs = recentLogs.filter { log in
            // Всегда включаем ошибки и предупреждения
            if log.level == .error || log.level == .warning {
                return true
            }
            
            // Включаем успешные операции
            if log.level == .success {
                return true
            }
            
            // Для info - только важные сообщения
            if log.level == .info {
                let importantKeywords = ["gpt", "openai", "api", "command", "executed", "planned", "step", "task", "complete", "terminal", "ssh", "connected", "error", "failed", "success"]
                return importantKeywords.contains { keyword in
                    log.message.lowercased().contains(keyword)
                }
            }
            
            // Исключаем debug логи
            return false
        }
        
        return importantLogs.map { log in
            "[\(log.formattedTimestamp)] \(log.level.icon) \(log.message)"
        }.joined(separator: "\n")
    }

    // MARK: - UI simplification & coalescing
    private func simplifyForUI(_ log: LogMessage) -> LogMessage {
        // Remove technical noise and clamp long messages
        let raw = log.displayMessage
        let maxLen = 180
        var text = raw
            .replacingOccurrences(of: "[TRACE", with: "")
            .replacingOccurrences(of: "]", with: "]")
            .replacingOccurrences(of: "BEGIN", with: "")
            .replacingOccurrences(of: "END", with: "")
            .replacingOccurrences(of: "attempt=", with: "")
            .replacingOccurrences(of: "status=200", with: "")
            .replacingOccurrences(of: "duration_s=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > maxLen {
            let endIndex = text.index(text.startIndex, offsetBy: maxLen)
            text = String(text[..<endIndex]) + "…"
        }
        return LogMessage(timestamp: log.timestamp, level: compressLevel(log.level), source: compressSource(log.source), message: text)
    }
    private func compressLevel(_ level: LogLevel) -> LogLevel {
        // Map debug->info for UI
        if level == .debug { return .info }
        return level
    }
    private func compressSource(_ source: String) -> String {
        // Shorten common sources
        switch source.lowercased() {
        case "gptterminalservice": return "GPT"
        case "swifttermservice": return "SSH"
        case "loggingservice": return "LOG"
        default: return source
        }
    }
    private func appendToUILogsCoalesced(_ log: LogMessage) {
        // Merge with previous if same level+source+message within 1.5s
        if let last = uiLogs.last {
            let sameText = last.message == log.message && last.level == log.level && last.source == log.source
            let interval = log.timestamp.timeIntervalSince(last.timestamp)
            if sameText && interval <= 1.5 {
                // Replace timestamp to latest, drop duplicates
                uiLogs[uiLogs.count - 1] = LogMessage(timestamp: log.timestamp, level: log.level, source: log.source, message: log.message)
            } else {
                uiLogs.append(log)
            }
        } else {
            uiLogs.append(log)
        }
        if uiLogs.count > 200 { uiLogs.removeFirst(40) }
    }
    
    // Метод для получения краткого резюме логов
    func getLogSummary() -> String {
        let errorCount = logs.filter { $0.level == .error }.count
        let warningCount = logs.filter { $0.level == .warning }.count
        let successCount = logs.filter { $0.level == .success }.count
        let totalCount = logs.count
        
        var summary = "📊 Log Summary:\n"
        summary += "Total: \(totalCount) | Errors: \(errorCount) | Warnings: \(warningCount) | Success: \(successCount)\n\n"
        
        // Добавляем последние важные события
        let recentImportant = logs.suffix(10).filter { $0.level != .debug }
        if !recentImportant.isEmpty {
            summary += "Recent events:\n"
            summary += recentImportant.map { log in
                "[\(log.formattedTimestamp)] \(log.level.icon) \(log.message)"
            }.joined(separator: "\n")
        }
        
        return summary
    }
    
    // Фильтрация логов по уровню
    func getLogs(level: LogLevel? = nil) -> [LogMessage] {
        if let level = level {
            return logs.filter { $0.level == level }
        }
        return logs
    }
    
    // Фильтрация логов по источнику
    func getLogs(source: String) -> [LogMessage] {
        return logs.filter { $0.source == source }
    }
}
