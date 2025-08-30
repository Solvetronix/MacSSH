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
    @Published var isEnabled: Bool = true
    
    // Minimum log level to record. In release builds we default to .info
    // to avoid high-frequency debug logging that can cause UI churn and
    // unnecessary energy usage while the app is idle.
    private let minLevel: LogLevel
    
    private init() {
        #if DEBUG
        self.minLevel = .debug
        #else
        self.minLevel = .info
        #endif
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
        
        // Выводим в системную консоль для отладки
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
