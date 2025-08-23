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
struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let source: String
    let message: String
    
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
    
    private init() {}
    
    // Основные методы логирования
    func log(_ message: String, level: LogLevel = .info, source: String = "System") {
        guard isEnabled else { return }
        
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
