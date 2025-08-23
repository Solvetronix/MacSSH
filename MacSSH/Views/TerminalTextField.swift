import SwiftUI
import AppKit

// MARK: - NSViewRepresentable для TextField с обработкой клавиш
struct TerminalTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var commandHistory: [String]
    @Binding var currentCommandIndex: Int
    let onSubmit: (String) -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = false
        textField.backgroundColor = NSColor.clear
        textField.textColor = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        textField.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.delegate = context.coordinator
        
        // Устанавливаем делегат для обработки клавиш
        context.coordinator.textField = textField
        
        // Автоматически устанавливаем фокус при создании с небольшой задержкой
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            LoggingService.shared.debug("Attempting to set focus on text field", source: "TerminalTextField")
            if let window = textField.window {
                LoggingService.shared.debug("Window found, setting first responder", source: "TerminalTextField")
                window.makeFirstResponder(textField)
                LoggingService.shared.debug("First responder set successfully", source: "TerminalTextField")
            } else {
                LoggingService.shared.debug("Window not found, cannot set focus", source: "TerminalTextField")
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        LoggingService.shared.debug("updateNSView called with text: '\(text)'", source: "TerminalTextField")
        nsView.stringValue = text
        LoggingService.shared.debug("Text field updated", source: "TerminalTextField")
    }
    
    static func dismantleNSView(_ nsView: NSTextField, coordinator: Coordinator) {
        LoggingService.shared.debug("dismantleNSView called", source: "TerminalTextField")
        // Безопасно очищаем делегат перед освобождением
        nsView.delegate = nil
        coordinator.textField = nil
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TerminalTextField
        weak var textField: NSTextField?
        private var isDeallocating = false
        
        init(_ parent: TerminalTextField) {
            self.parent = parent
        }
        
        deinit {
            LoggingService.shared.debug("TerminalTextField Coordinator deinit", source: "TerminalTextField")
            isDeallocating = true
            // Безопасно очищаем делегат
            textField?.delegate = nil
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard !isDeallocating else { return }
            LoggingService.shared.debug("controlTextDidChange called", source: "TerminalTextField")
            if let textField = obj.object as? NSTextField {
                LoggingService.shared.debug("Text changed to: '\(textField.stringValue)'", source: "TerminalTextField")
                parent.text = textField.stringValue
                LoggingService.shared.debug("Parent text updated to: '\(parent.text)'", source: "TerminalTextField")
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            guard !isDeallocating else { return }
            LoggingService.shared.debug("controlTextDidEndEditing called", source: "TerminalTextField")
            // Проверяем, если это было нажатие Enter (а не потеря фокуса)
            if let textField = obj.object as? NSTextField, !textField.stringValue.isEmpty {
                LoggingService.shared.debug("Text field ended editing with text: '\(textField.stringValue)'", source: "TerminalTextField")
                // Не вызываем submitCommand здесь, так как это может быть потеря фокуса
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !isDeallocating else { return false }
            LoggingService.shared.debug("=== KEY EVENT DETECTED ===", source: "TerminalTextField")
            LoggingService.shared.debug("Key pressed - \(commandSelector)", source: "TerminalTextField")
            LoggingService.shared.debug("Control: \(control)", source: "TerminalTextField")
            LoggingService.shared.debug("TextView: \(textView)", source: "TerminalTextField")
            
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                // Стрелка вверх - навигация по истории
                LoggingService.shared.debug("Up arrow pressed", source: "TerminalTextField")
                navigateHistory(up: true)
                return true
                
            case #selector(NSResponder.moveDown(_:)):
                // Стрелка вниз - навигация по истории
                LoggingService.shared.debug("Down arrow pressed", source: "TerminalTextField")
                navigateHistory(up: false)
                return true
                
            case #selector(NSResponder.insertNewline(_:)):
                // Enter - выполнение команды
                LoggingService.shared.debug("Enter pressed - insertNewline detected", source: "TerminalTextField")
                submitCommand()
                return true
                
            case #selector(NSResponder.insertLineBreak(_:)):
                // Альтернативный способ обработки Enter
                LoggingService.shared.debug("Enter pressed - insertLineBreak detected", source: "TerminalTextField")
                submitCommand()
                return true
                
            default:
                LoggingService.shared.debug("Other key pressed - \(commandSelector)", source: "TerminalTextField")
                return false
            }
        }
        
        private func navigateHistory(up: Bool) {
            if parent.commandHistory.isEmpty { 
                LoggingService.shared.debug("History is empty, cannot navigate", source: "TerminalTextField")
                return 
            }
            
            LoggingService.shared.debug("Navigating history: up=\(up), currentIndex=\(parent.currentCommandIndex), historyCount=\(parent.commandHistory.count)", source: "TerminalTextField")
            
            if up {
                // Стрелка вверх - идем назад по истории
                if parent.currentCommandIndex > 0 {
                    parent.currentCommandIndex -= 1
                    parent.text = parent.commandHistory[parent.currentCommandIndex]
                    LoggingService.shared.debug("Moved up to index \(parent.currentCommandIndex): '\(parent.text)'", source: "TerminalTextField")
                } else if parent.currentCommandIndex == 0 {
                    // Если мы в начале истории, сохраняем текущий текст
                    parent.text = parent.commandHistory[0]
                    LoggingService.shared.debug("At beginning of history: '\(parent.text)'", source: "TerminalTextField")
                }
            } else {
                // Стрелка вниз - идем вперед по истории
                if parent.currentCommandIndex < parent.commandHistory.count - 1 {
                    parent.currentCommandIndex += 1
                    parent.text = parent.commandHistory[parent.currentCommandIndex]
                    LoggingService.shared.debug("Moved down to index \(parent.currentCommandIndex): '\(parent.text)'", source: "TerminalTextField")
                } else if parent.currentCommandIndex == parent.commandHistory.count - 1 {
                    // Достигли конца истории - очищаем поле ввода
                    parent.currentCommandIndex = parent.commandHistory.count
                    parent.text = ""
                    LoggingService.shared.debug("Reached end of history, cleared input", source: "TerminalTextField")
                }
            }
            
            // Обновляем текст в TextField
            textField?.stringValue = parent.text
            
            // Убираем выделение текста и устанавливаем курсор в конец сразу
            if let textField = self.textField {
                textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                textField.needsDisplay = true
            }
        }
        
        private func submitCommand() {
            let command = parent.text.trimmingCharacters(in: .whitespacesAndNewlines)
            LoggingService.shared.debug("Submit command called with: '\(command)'", source: "TerminalTextField")
            LoggingService.shared.debug("Parent text: '\(parent.text)'", source: "TerminalTextField")
            LoggingService.shared.debug("TextField stringValue: '\(textField?.stringValue ?? "nil")'", source: "TerminalTextField")
            
            if !command.isEmpty {
                LoggingService.shared.debug("Command is not empty, processing...", source: "TerminalTextField")
                
                // ВОЗВРАЩАЕМ ПРОСТУЮ ИСТОРИЮ КОМАНД (только для текущей сессии)
                // Добавляем команду в локальную историю
                if !parent.commandHistory.contains(command) {
                    parent.commandHistory.append(command)
                }
                parent.currentCommandIndex = parent.commandHistory.count
                
                LoggingService.shared.debug("Added command to local history, count: \(parent.commandHistory.count)", source: "TerminalTextField")
                
                // Вызываем onSubmit для отправки команды в SSH
                parent.onSubmit(command)
                LoggingService.shared.debug("Command submitted to parent", source: "TerminalTextField")
                
                // Очищаем поле ввода
                parent.text = ""
                textField?.stringValue = ""
                LoggingService.shared.debug("Input field cleared", source: "TerminalTextField")
                
                // Принудительно обновляем UI
                DispatchQueue.main.async {
                    self.textField?.needsDisplay = true
                }
            } else {
                LoggingService.shared.debug("Empty command, not submitting", source: "TerminalTextField")
            }
        }
    }
}
