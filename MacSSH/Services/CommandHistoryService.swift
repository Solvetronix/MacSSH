import Foundation

// Сервис для управления историей команд с сохранением между сессиями
class CommandHistoryService: ObservableObject {
    static let shared = CommandHistoryService()
    
    @Published var commandHistory: [String] = []
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "terminalCommandHistory"
    private let maxHistorySize = 1000 // Максимальное количество команд в истории
    
    private init() {
        loadHistory()
    }
    
    // Загрузка истории из UserDefaults
    private func loadHistory() {
        if let savedHistory = userDefaults.stringArray(forKey: historyKey) {
            commandHistory = savedHistory
            LoggingService.shared.debug("Loaded \(commandHistory.count) commands from history", source: "CommandHistoryService")
        } else {
            LoggingService.shared.debug("No command history found in UserDefaults", source: "CommandHistoryService")
        }
    }
    
    // Сохранение истории в UserDefaults
    private func saveHistory() {
        userDefaults.set(commandHistory, forKey: historyKey)
        LoggingService.shared.debug("Saved \(commandHistory.count) commands to history", source: "CommandHistoryService")
    }
    
    // Добавление команды в историю
    func addCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Не добавляем пустые команды
        guard !trimmedCommand.isEmpty else {
            LoggingService.shared.debug("Skipping empty command", source: "CommandHistoryService")
            return
        }
        
        LoggingService.shared.debug("addCommand called with: '\(command)' -> trimmed: '\(trimmedCommand)'", source: "CommandHistoryService")
        LoggingService.shared.debug("Before adding: history count = \(commandHistory.count), history = \(commandHistory)", source: "CommandHistoryService")
        
        // Удаляем дубликаты (если команда уже есть в истории)
        commandHistory.removeAll { $0 == trimmedCommand }
        
        // Добавляем команду в конец истории
        commandHistory.append(trimmedCommand)
        
        // Ограничиваем размер истории
        if commandHistory.count > maxHistorySize {
            commandHistory.removeFirst(commandHistory.count - maxHistorySize)
            LoggingService.shared.debug("History limit reached, removed oldest commands", source: "CommandHistoryService")
        }
        
        saveHistory()
        LoggingService.shared.debug("After adding: history count = \(commandHistory.count), history = \(commandHistory)", source: "CommandHistoryService")
        LoggingService.shared.debug("Added command '\(trimmedCommand)' to history, total: \(commandHistory.count)", source: "CommandHistoryService")
    }
    
    // Получение истории команд
    func getHistory() -> [String] {
        return commandHistory
    }
    
    // Очистка истории
    func clearHistory() {
        commandHistory.removeAll()
        saveHistory()
        LoggingService.shared.debug("Command history cleared", source: "CommandHistoryService")
    }
    
    // Получение статистики истории
    func getHistoryStats() -> (total: Int, unique: Int) {
        let uniqueCommands = Set(commandHistory)
        return (commandHistory.count, uniqueCommands.count)
    }
    
    // Поиск команд в истории по префиксу
    func searchHistory(prefix: String) -> [String] {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrefix.isEmpty else { return [] }
        
        return commandHistory.filter { $0.hasPrefix(trimmedPrefix) }
    }
    
    // Получение последней команды
    func getLastCommand() -> String? {
        return commandHistory.last
    }
    
    // Получение команды по индексу (с конца)
    func getCommand(at index: Int) -> String? {
        let reversedIndex = commandHistory.count - 1 - index
        guard reversedIndex >= 0 && reversedIndex < commandHistory.count else {
            return nil
        }
        return commandHistory[reversedIndex]
    }
    
    // Получение размера истории
    var historySize: Int {
        return commandHistory.count
    }
}
