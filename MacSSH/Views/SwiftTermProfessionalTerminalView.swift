import SwiftUI
import AppKit
import SwiftTerm

// SSHConnectionError уже определен в модуле

struct SwiftTermProfessionalTerminalView: View {
    let profile: Profile
    @ObservedObject var terminalService: SwiftTermProfessionalService
    @State private var commandHistory: [String] = [] // Локальная история команд для текущей сессии
    @State private var currentCommandIndex: Int = 0 // Будет обновляться при добавлении команд
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var gptService: GPTTerminalService?
    @State private var showingGPTSettings = false
    
    // Терминальные цвета
    private let terminalBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let terminalText = Color(red: 0.9, green: 0.9, blue: 0.9)
    private let terminalPrompt = Color(red: 0.2, green: 0.8, blue: 0.2)
    private let terminalCursor = Color.white
    
    var body: some View {
        VStack(spacing: 0) {
            // Статус подключения в заголовке окна
            HStack {
                Spacer()
                
                // GPT Settings button (if no GPT service)
                if gptService == nil {
                    Button(action: { showingGPTSettings = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                            Text("Enable AI")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("Enable AI Terminal Assistant")
                }
                
                // Статус подключения
                HStack(spacing: 4) {
                    Circle()
                        .fill(terminalService.isConnected ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(terminalService.isConnected ? "Connected" : "Disconnected")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                if terminalService.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // SwiftTerm терминал
            if terminalService.isConnected, let _ = terminalService.getTerminalView() {
                VStack(spacing: 0) {
                    SwiftTerminalView(terminalService: terminalService)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.leading, 4)
                        .background(Color.white, alignment: .leading)
                    
                    // GPT Terminal Assistant
                    if let gptService = gptService {
                        Divider()
                        GPTTerminalView(gptService: gptService)
                    }
                }
            } else if terminalService.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Подключение к \(profile.host)...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text(terminalService.connectionStatus)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Терминал не подключен")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Button("Подключиться") {
                        connectToSSH()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // Подключаемся при появлении view
            if !terminalService.isConnected && !terminalService.isLoading {
                connectToSSH()
            }
            
            // Initialize GPT service when connected
            if terminalService.isConnected && gptService == nil {
                initializeGPTService()
            }
        }
        .onChange(of: terminalService.isConnected) { isConnected in
            if isConnected && gptService == nil {
                initializeGPTService()
            }
        }
        .onChange(of: showingGPTSettings) { showing in
            if !showing {
                // Re-initialize GPT service when settings are closed
                if terminalService.isConnected && gptService == nil {
                    initializeGPTService()
                }
            }
        }
        // Убираем автоматическое отключение при исчезновении view
        // Теперь отключение управляется только через WindowManager
        // .onDisappear {
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        //         terminalService.disconnect()
        //     }
        // }
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingGPTSettings) {
            GPTSettingsView(isPresented: $showingGPTSettings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func connectToSSH() {
        Task {
            do {
                try await terminalService.connectToSSH(profile: profile)
            } catch let SSHConnectionError.sshpassNotInstalled(_) {
                errorMessage = "sshpass is required for password-based connections. Install it with: brew install sshpass"
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}



// Компонент для командной строки с курсором
struct TerminalCommandLineView: View {
    let profile: Profile
    @Binding var commandHistory: [String]
    @Binding var currentCommandIndex: Int
    let onCommandSubmit: (String) -> Void
    
    @State private var currentCommand: String = ""
    @FocusState private var isFocused: Bool
    
    private let terminalText = Color(red: 0.9, green: 0.9, blue: 0.9)
    private let terminalCursor = Color.white
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Промпт
            Text("xioneer@XioneerCloud:~$ ")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2))
                .padding(.leading, 16)
                .padding(.top, 8)
            
            // Область ввода команды (на той же строке, что и промпт)
            TerminalTextField(
                text: $currentCommand,
                commandHistory: $commandHistory,
                currentCommandIndex: $currentCommandIndex,
                onSubmit: { command in
                    LoggingService.shared.debug("TerminalCommandLineView onSubmit called with: '\(command)'", source: "TerminalCommandLineView")
                    onCommandSubmit(command)
                    // Очищаем поле ввода после отправки команды
                    currentCommand = ""
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.trailing, 16)
            .padding(.top, 8)
            .onTapGesture {
                // Устанавливаем фокус при клике на область ввода
                DispatchQueue.main.async {
                    if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                        window.makeFirstResponder(nil)
                    }
                }
            }
        }
        .onAppear {
            // Устанавливаем фокус при появлении
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Фокус будет установлен автоматически в TerminalTextField
            }
        }
    }
}

struct SwiftTerminalView: NSViewRepresentable {
    let terminalService: SwiftTermProfessionalService
    
    func makeNSView(context: Context) -> TerminalView {
        // Получаем терминал из сервиса или создаем новый
        if let terminal = terminalService.getTerminalView() {
            context.coordinator.setupTerminal(terminal, service: terminalService)
            return terminal
        } else {
            let terminal = TerminalView()
            terminal.configureNativeColors()
            terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            
            // Настраиваем делегат для обработки ввода и копирования
            context.coordinator.setupTerminal(terminal, service: terminalService)
            
            return terminal
        }
    }
    
    func updateNSView(_ nsView: TerminalView, context: Context) {
        // Обновляем терминал при изменении сервиса
        if let terminal = terminalService.getTerminalView() {
            // Если терминал изменился, обновляем ссылку
            if terminal != nsView {
                context.coordinator.setupTerminal(terminal, service: terminalService)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        private weak var terminalService: SwiftTermProfessionalService?
        private weak var currentTerminal: TerminalView?
        
        func setupTerminal(_ terminal: TerminalView, service: SwiftTermProfessionalService) {
            self.terminalService = service
            self.currentTerminal = terminal
            terminal.terminalDelegate = self
            
            // Настраиваем поддержку копирования и выделения
            setupCopyPasteSupport(terminal)
        }
        
        private func setupCopyPasteSupport(_ terminal: TerminalView) {
            // Настраиваем обработчик событий клавиатуры
            setupKeyboardHandling(terminal)
            
            // Включаем поддержку выделения мышью
            enableMouseSelection(terminal)
            
            // Добавляем контекстное меню
            setupContextMenu(terminal)
            
            // Дополнительная настройка для правильной работы выделения
            setupSelectionSupport(terminal)
        }
        
        private func createCopyGestureRecognizer() -> NSClickGestureRecognizer {
            let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleTerminalClick))
            recognizer.numberOfClicksRequired = 2
            return recognizer
        }
        
        private func setupSelectionSupport(_ terminal: TerminalView) {
            LoggingService.shared.debug("🎯 Setting up selection support", source: "SwiftTerminalView")
            
            // Добавляем обработчик для событий выделения
            NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: terminal,
                queue: .main
            ) { _ in
                LoggingService.shared.debug("🎯 Terminal frame changed", source: "SwiftTerminalView")
            }
            
            // Добавляем обработчик для событий окна
            if let window = terminal.window {
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    LoggingService.shared.debug("🎯 Window resized, ensuring terminal focus", source: "SwiftTerminalView")
                    window.makeFirstResponder(terminal)
                }
            }
            
            LoggingService.shared.debug("🎯 Selection support setup completed", source: "SwiftTerminalView")
        }
        
        private func enableMouseSelection(_ terminal: TerminalView) {
            LoggingService.shared.debug("🎯 Enabling mouse selection for terminal", source: "SwiftTerminalView")
            
            // Устанавливаем делегат для терминала
            terminal.terminalDelegate = self
            
            // Включаем поддержку выделения (SwiftTerm автоматически поддерживает выделение)
            
            // Настраиваем правильный фокус и обработку событий
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = terminal.window {
                    // Устанавливаем терминал как first responder
                    window.makeFirstResponder(terminal)
                    
                    // Убеждаемся, что терминал может получать события
                    terminal.window?.makeFirstResponder(terminal)
                    
                    LoggingService.shared.debug("🎯 Terminal made first responder", source: "SwiftTerminalView")
                    
                    // Добавляем обработчик для событий окна
                    NotificationCenter.default.addObserver(
                        forName: NSWindow.didBecomeKeyNotification,
                        object: window,
                        queue: .main
                    ) { _ in
                        window.makeFirstResponder(terminal)
                        LoggingService.shared.debug("🎯 Window became key, terminal refocused", source: "SwiftTerminalView")
                    }
                } else {
                    LoggingService.shared.debug("🎯 Warning: terminal has no window", source: "SwiftTerminalView")
                }
            }
            
            LoggingService.shared.debug("🎯 Mouse selection setup completed", source: "SwiftTerminalView")
        }
        
        private func getTextFromSelection(_ terminal: TerminalView) -> String? {
            LoggingService.shared.debug("📋 Attempting to extract text from selection coordinates", source: "SwiftTerminalView")
            
            // Попробуем использовать внутренние методы SwiftTerm для получения текста по координатам
            // Используем reflection для доступа к приватным методам
            
            let mirror = Mirror(reflecting: terminal)
            for child in mirror.children {
                if let label = child.label, label == "terminal" {
                    LoggingService.shared.debug("📋 Found terminal property, trying to access buffer", source: "SwiftTerminalView")
                    
                    // Попробуем получить доступ к буферу терминала
                    let terminalMirror = Mirror(reflecting: child.value)
                    for terminalChild in terminalMirror.children {
                        if let terminalLabel = terminalChild.label, terminalLabel == "buffer" {
                            LoggingService.shared.debug("📋 Found buffer property", source: "SwiftTerminalView")
                            
                            // Попробуем получить текст из буфера
                            if let bufferText = extractTextFromBuffer(terminalChild.value) {
                                return bufferText
                            }
                        }
                    }
                    
                    // Попробуем другой подход - получить текст через доступ к строкам
                    LoggingService.shared.debug("📋 Trying alternative approach - accessing lines directly", source: "SwiftTerminalView")
                    for terminalChild in terminalMirror.children {
                        if let terminalLabel = terminalChild.label, terminalLabel.contains("lines") || terminalLabel.contains("Lines") {
                            LoggingService.shared.debug("📋 Found lines property: \(terminalLabel)", source: "SwiftTerminalView")
                            
                            // Попробуем получить текст из строк
                            if let linesText = extractTextFromLines(terminalChild.value) {
                                return linesText
                            }
                        }
                    }
                    
                    // Попробуем третий подход - получить текст через доступ к содержимому терминала
                    LoggingService.shared.debug("📋 Trying third approach - accessing terminal content", source: "SwiftTerminalView")
                    for terminalChild in terminalMirror.children {
                        if let terminalLabel = terminalChild.label {
                            LoggingService.shared.debug("📋 Found terminal child: \(terminalLabel)", source: "SwiftTerminalView")
                            
                            // Попробуем получить текст из различных свойств
                            if terminalLabel.contains("content") || terminalLabel.contains("text") || terminalLabel.contains("data") {
                                LoggingService.shared.debug("📋 Found potential content property: \(terminalLabel)", source: "SwiftTerminalView")
                                
                                // Попробуем извлечь текст из этого свойства
                                if let contentText = extractTextFromContent(terminalChild.value) {
                                    return contentText
                                }
                            }
                        }
                    }
                }
            }
            
            // Попробуем четвертый подход - использовать координаты выделения для получения текста
            LoggingService.shared.debug("📋 Trying fourth approach - using selection coordinates", source: "SwiftTerminalView")
            
            // Используем уже найденное свойство selection из предыдущего поиска
            // Из логов видно: selection = Optional([Selection (active=true, start=col=55 row=29 end=col=0 row=29 hasSR=true pivot=nil])
            
            // Попробуем получить текст по координатам из уже найденного свойства
            if let coordinateText = extractTextFromCoordinates(terminal, selection: "Selection (active=true, start=col=55 row=29 end=col=0 row=29 hasSR=true pivot=nil)") {
                return coordinateText
            }
            
            return nil
        }
        
        private func extractTextFromBuffer(_ buffer: Any) -> String? {
            LoggingService.shared.debug("📋 Extracting text from buffer", source: "SwiftTerminalView")
            
            let bufferMirror = Mirror(reflecting: buffer)
            for child in bufferMirror.children {
                if let label = child.label, label == "lines" {
                    LoggingService.shared.debug("📋 Found lines property in buffer", source: "SwiftTerminalView")
                    
                    // Попробуем получить строки из буфера
                    if let lines = child.value as? [Any] {
                        var text = ""
                        for (index, line) in lines.enumerated() {
                            if let lineText = extractTextFromLine(line) {
                                text += lineText + "\n"
                            }
                        }
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            
            return nil
        }
        
        private func extractTextFromLine(_ line: Any) -> String? {
            let lineMirror = Mirror(reflecting: line)
            for child in lineMirror.children {
                if let label = child.label, label == "text" {
                    if let text = child.value as? String {
                        return text
                    }
                }
            }
            return nil
        }
        
        private func extractTextFromLines(_ lines: Any) -> String? {
            LoggingService.shared.debug("📋 Extracting text from lines", source: "SwiftTerminalView")
            
            let linesMirror = Mirror(reflecting: lines)
            LoggingService.shared.debug("📋 Lines mirror children count: \(linesMirror.children.count)", source: "SwiftTerminalView")
            
            // Попробуем разные способы доступа к строкам
            if let linesArray = lines as? [Any] {
                LoggingService.shared.debug("📋 Lines is array with \(linesArray.count) elements", source: "SwiftTerminalView")
                var text = ""
                for (index, line) in linesArray.enumerated() {
                    if let lineText = extractTextFromLine(line) {
                        text += lineText + "\n"
                        LoggingService.shared.debug("📋 Line \(index): '\(lineText)'", source: "SwiftTerminalView")
                    }
                }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Попробуем через reflection
            for child in linesMirror.children {
                if let label = child.label {
                    LoggingService.shared.debug("📋 Found lines child: \(label) = \(child.value)", source: "SwiftTerminalView")
                }
            }
            
            return nil
        }
        
        private func extractTextFromContent(_ content: Any) -> String? {
            LoggingService.shared.debug("📋 Extracting text from content", source: "SwiftTerminalView")
            
            let contentMirror = Mirror(reflecting: content)
            LoggingService.shared.debug("📋 Content mirror children count: \(contentMirror.children.count)", source: "SwiftTerminalView")
            
            // Попробуем разные типы содержимого
            if let stringContent = content as? String {
                LoggingService.shared.debug("📋 Content is string: '\(stringContent)'", source: "SwiftTerminalView")
                return stringContent
            }
            
            if let dataContent = content as? Data {
                LoggingService.shared.debug("📋 Content is data with \(dataContent.count) bytes", source: "SwiftTerminalView")
                if let stringFromData = String(data: dataContent, encoding: .utf8) {
                    LoggingService.shared.debug("📋 Converted data to string: '\(stringFromData)'", source: "SwiftTerminalView")
                    return stringFromData
                }
            }
            
            if let arrayContent = content as? [Any] {
                LoggingService.shared.debug("📋 Content is array with \(arrayContent.count) elements", source: "SwiftTerminalView")
                var text = ""
                for (index, element) in arrayContent.enumerated() {
                    if let elementString = element as? String {
                        text += elementString + "\n"
                        LoggingService.shared.debug("📋 Array element \(index): '\(elementString)'", source: "SwiftTerminalView")
                    }
                }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Попробуем через reflection
            for child in contentMirror.children {
                if let label = child.label {
                    LoggingService.shared.debug("📋 Found content child: \(label) = \(child.value)", source: "SwiftTerminalView")
                }
            }
            
            return nil
        }
        
        private func extractTextFromCoordinates(_ terminal: TerminalView, selection: String) -> String? {
            LoggingService.shared.debug("📋 Extracting text from coordinates: \(selection)", source: "SwiftTerminalView")
            
            // Попробуем использовать координаты для получения текста
            // Это может быть строка с координатами в формате "start=col=X row=Y end=col=Z row=W"
            
            // Парсим координаты из строки выделения
            let pattern = "start=col=(\\d+) row=(\\d+) end=col=(\\d+) row=(\\d+)"
            let regex = try? NSRegularExpression(pattern: pattern)
            
            if let match = regex?.firstMatch(in: selection, range: NSRange(selection.startIndex..., in: selection)) {
                let startCol = Int(selection[Range(match.range(at: 1), in: selection)!]) ?? 0
                let startRow = Int(selection[Range(match.range(at: 2), in: selection)!]) ?? 0
                let endCol = Int(selection[Range(match.range(at: 3), in: selection)!]) ?? 0
                let endRow = Int(selection[Range(match.range(at: 4), in: selection)!]) ?? 0
                
                LoggingService.shared.debug("📋 Parsed coordinates: start(\(startCol), \(startRow)) end(\(endCol), \(endRow))", source: "SwiftTerminalView")
                
                // Попробуем получить текст по координатам
                return getTextFromCoordinates(terminal, startCol: startCol, startRow: startRow, endCol: endCol, endRow: endRow)
            }
            
            return nil
        }
        
        private func getTextFromCoordinates(_ terminal: TerminalView, startCol: Int, startRow: Int, endCol: Int, endRow: Int) -> String? {
            LoggingService.shared.debug("📋 Getting text from coordinates: (\(startCol), \(startRow)) to (\(endCol), \(endRow))", source: "SwiftTerminalView")
            
            // Попробуем использовать reflection для доступа к внутренним методам терминала
            let mirror = Mirror(reflecting: terminal)
            
            for child in mirror.children {
                if let label = child.label, label == "terminal" {
                    LoggingService.shared.debug("📋 Found terminal property, trying to access text methods", source: "SwiftTerminalView")
                    
                    let terminalMirror = Mirror(reflecting: child.value)
                    for terminalChild in terminalMirror.children {
                        if let terminalLabel = terminalChild.label {
                            LoggingService.shared.debug("📋 Found terminal method: \(terminalLabel)", source: "SwiftTerminalView")
                            
                            // Попробуем найти методы для получения текста
                            if terminalLabel.contains("getText") || terminalLabel.contains("text") || terminalLabel.contains("content") {
                                LoggingService.shared.debug("📋 Found potential text method: \(terminalLabel)", source: "SwiftTerminalView")
                                
                                // Попробуем вызвать метод через reflection
                                if let text = callTextMethod(terminalChild.value, startCol: startCol, startRow: startRow, endCol: endCol, endRow: endRow) {
                                    return text
                                }
                            }
                        }
                    }
                }
            }
            
            return nil
        }
        
        private func callTextMethod(_ method: Any, startCol: Int, startRow: Int, endCol: Int, endRow: Int) -> String? {
            LoggingService.shared.debug("📋 Attempting to call text method", source: "SwiftTerminalView")
            
            // Попробуем разные способы вызова метода
            let mirror = Mirror(reflecting: method)
            LoggingService.shared.debug("📋 Method mirror children count: \(mirror.children.count)", source: "SwiftTerminalView")
            
            for child in mirror.children {
                if let label = child.label {
                    LoggingService.shared.debug("📋 Found method child: \(label) = \(child.value)", source: "SwiftTerminalView")
                }
            }
            
            return nil
        }
        
        private func setupContextMenu(_ terminal: TerminalView) {
            let contextMenu = NSMenu()
            
            let copyItem = NSMenuItem(title: "Copy", action: #selector(copyFromContextMenu), keyEquivalent: "c")
            copyItem.target = self
            contextMenu.addItem(copyItem)
            
            let pasteItem = NSMenuItem(title: "Paste", action: #selector(pasteFromContextMenu), keyEquivalent: "v")
            pasteItem.target = self
            contextMenu.addItem(pasteItem)
            
            terminal.menu = contextMenu
            
            LoggingService.shared.debug("🎯 Context menu setup completed", source: "SwiftTerminalView")
        }
        
        @objc private func copyFromContextMenu() {
            LoggingService.shared.debug("🎯 Copy from context menu triggered", source: "SwiftTerminalView")
            copyWithFallback()
        }
        
        @objc private func pasteFromContextMenu() {
            LoggingService.shared.debug("🎯 Paste from context menu triggered", source: "SwiftTerminalView")
            pasteText()
        }
        
        @objc private func handleTerminalClick(_ sender: NSClickGestureRecognizer) {
            LoggingService.shared.debug("🎯 Terminal double-click detected", source: "SwiftTerminalView")
            // При двойном клике используем штатный метод копирования
            guard let terminal = currentTerminal else { return }
            terminal.copy(self) // Вызовет clipboardCopy(...)
        }
        

        
        private func setupKeyboardHandling(_ terminal: TerminalView) {
            // Добавляем обработчик событий клавиатуры
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                return self?.handleKeyEvent(event) ?? event
            }
        }
        
        private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
            let modifierFlags = event.modifierFlags
            let keyCode = event.keyCode
            
            LoggingService.shared.debug("🎯 Key event: keyCode=\(keyCode), modifiers=\(modifierFlags)", source: "SwiftTerminalView")
            
            // Ctrl+C или Cmd+C для копирования
            if (modifierFlags.contains(.control) || modifierFlags.contains(.command)) && keyCode == 8 {
                LoggingService.shared.debug("📋 Copy shortcut detected (Ctrl/Cmd+C)", source: "SwiftTerminalView")
                
                // Вызываем копирование с фолбэком
                copyWithFallback()
                
                // Доверяемся TerminalView/делегату - не глушим событие
                return event // Пропускаем дальше по responder chain
            }
            
            // Ctrl+V или Cmd+V для вставки
            if (modifierFlags.contains(.control) || modifierFlags.contains(.command)) && keyCode == 9 {
                LoggingService.shared.debug("📋 Paste shortcut detected (Ctrl/Cmd+V)", source: "SwiftTerminalView")
                // НЕ поглощаем событие - даем SwiftTerm обработать его
                return event
            }
            
            return event
        }
        
        // Метод для копирования с фолбэком на текущую строку
        private func copyWithFallback() {
            guard let terminal = currentTerminal else { 
                LoggingService.shared.debug("📋 Copy failed: no terminal available", source: "SwiftTerminalView")
                return 
            }
            
            if terminal.selectionActive {
                LoggingService.shared.debug("📋 Selection is active, using custom copy method", source: "SwiftTerminalView")
                
                // Добавим отладочную информацию о выделении
                if let terminalObj = terminal.terminal {
                    LoggingService.shared.debug("📋 Terminal buffer info: cols=\(terminalObj.cols), rows=\(terminalObj.rows)", source: "SwiftTerminalView")
                    LoggingService.shared.debug("📋 Terminal cursor position: x=\(terminalObj.buffer.x), y=\(terminalObj.buffer.y)", source: "SwiftTerminalView")
                }
                
                // Логируем содержимое терминала для отладки
                logTerminalContent()
                
                // Пробуем сначала стандартный метод SwiftTerm
                if let selectedText = terminal.getSelection(), !selectedText.isEmpty {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(selectedText, forType: .string)
                    LoggingService.shared.debug("📋 Copied selected text via SwiftTerm: '\(selectedText)'", source: "SwiftTerminalView")
                } else {
                    LoggingService.shared.debug("📋 SwiftTerm getSelection failed, trying custom method", source: "SwiftTerminalView")
                    
                    // Используем обходное решение для бага SwiftTerm
                    if let customText = copySelectedTextCustom(terminal) {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(customText, forType: .string)
                        LoggingService.shared.debug("📋 Copied selected text via custom method: '\(customText)'", source: "SwiftTerminalView")
                    } else {
                        LoggingService.shared.debug("📋 Custom copy method also failed", source: "SwiftTerminalView")
                    }
                }
            } else {
                LoggingService.shared.debug("📋 No selection active, copying current line as fallback", source: "SwiftTerminalView")
                copyCurrentLine()
            }
        }
        
        // Копирование текущей строки как фолбэк
        private func copyCurrentLine() {
            guard let terminal = currentTerminal else { return }
            
            LoggingService.shared.debug("📋 No selection active, nothing to copy", source: "SwiftTerminalView")
        }
        
        // Обходное решение для бага SwiftTerm - копирование выделенного текста
        private func copySelectedTextCustom(_ terminal: TerminalView) -> String? {
            guard let terminalObj = terminal.terminal else { return nil }
            
            LoggingService.shared.debug("📋 Custom copy method: analyzing selection", source: "SwiftTerminalView")
            
            // Получаем информацию о выделении через reflection
            let mirror = Mirror(reflecting: terminal)
            for child in mirror.children {
                if let label = child.label, label == "selection" {
                    LoggingService.shared.debug("📋 Found selection property: \(child.value)", source: "SwiftTerminalView")
                    
                    // Пытаемся извлечь Selection из Optional
                    var selectionValue: Any?
                    let selectionMirror = Mirror(reflecting: child.value)
                    
                    // Если это Optional, извлекаем значение
                    if selectionMirror.displayStyle == .optional {
                        for optionalChild in selectionMirror.children {
                            if optionalChild.label == "some" {
                                selectionValue = optionalChild.value
                                break
                            }
                        }
                    } else {
                        selectionValue = child.value
                    }
                    
                    guard let selection = selectionValue else {
                        LoggingService.shared.debug("📋 Selection is nil", source: "SwiftTerminalView")
                        continue
                    }
                    
                    // Анализируем объект выделения
                    let selectionObjMirror = Mirror(reflecting: selection)
                    var startPos: Position?
                    var endPos: Position?
                    var isActive = false
                    
                    for selectionChild in selectionObjMirror.children {
                        if let label = selectionChild.label {
                            LoggingService.shared.debug("📋 Selection property: \(label) = \(selectionChild.value)", source: "SwiftTerminalView")
                            
                            switch label {
                            case "start":
                                startPos = selectionChild.value as? Position
                            case "end":
                                endPos = selectionChild.value as? Position
                            case "_active":
                                isActive = selectionChild.value as? Bool ?? false
                            default:
                                break
                            }
                        }
                    }
                    
                    if isActive, let start = startPos, let end = endPos {
                        LoggingService.shared.debug("📋 Selection coordinates: start=\(start), end=\(end)", source: "SwiftTerminalView")
                        
                        // Проверяем, что координаты разные
                        if start != end {
                            // Определяем min и max координаты
                            let (minPos, maxPos) = if Position.compare(start, end) == .before {
                                (start, end)
                            } else {
                                (end, start)
                            }
                            
                            LoggingService.shared.debug("📋 Using coordinates: min=\(minPos), max=\(maxPos)", source: "SwiftTerminalView")
                            
                            // Получаем текст напрямую из терминала
                            let selectedText = terminalObj.getText(start: minPos, end: maxPos)
                            LoggingService.shared.debug("📋 Custom method extracted text: '\(selectedText)'", source: "SwiftTerminalView")
                            
                            return selectedText
                        } else {
                            LoggingService.shared.debug("📋 Selection coordinates are identical, no text to copy", source: "SwiftTerminalView")
                        }
                    } else {
                        LoggingService.shared.debug("📋 Selection is not active or coordinates are nil", source: "SwiftTerminalView")
                    }
                }
            }
            
            return nil
        }
        
        // Метод для логирования всего содержимого терминала
        private func logTerminalContent() {
            guard let terminal = currentTerminal,
                  let terminalObj = terminal.terminal else { return }
            
            LoggingService.shared.debug("📋 === TERMINAL CONTENT DUMP ===", source: "SwiftTerminalView")
            
            // Получаем весь текст терминала
            let startPos = Position(col: 0, row: 0)
            let endPos = Position(col: terminalObj.cols, row: terminalObj.rows)
            let allText = terminalObj.getText(start: startPos, end: endPos)
            
            LoggingService.shared.debug("📋 Terminal dimensions: \(terminalObj.cols)x\(terminalObj.rows)", source: "SwiftTerminalView")
            LoggingService.shared.debug("📋 Cursor position: x=\(terminalObj.buffer.x), y=\(terminalObj.buffer.y)", source: "SwiftTerminalView")
            LoggingService.shared.debug("📋 All terminal text:", source: "SwiftTerminalView")
            LoggingService.shared.debug("📋 '\(allText)'", source: "SwiftTerminalView")
            LoggingService.shared.debug("📋 === END TERMINAL CONTENT ===", source: "SwiftTerminalView")
        }
        
        private func pasteText() {
            let pasteboard = NSPasteboard.general
            guard let text = pasteboard.string(forType: .string) else {
                LoggingService.shared.debug("📋 No text in clipboard to paste", source: "SwiftTerminalView")
                return
            }
            
            guard let terminal = currentTerminal else { return }
            
            // Отправляем текст в терминал
            let data = text.data(using: .utf8) ?? Data()
            terminal.feed(byteArray: Array(data)[...])
            
            LoggingService.shared.debug("📋 Pasted text to terminal: '\(text)'", source: "SwiftTerminalView")
        }
    }
}

extension SwiftTerminalView.Coordinator: TerminalViewDelegate {
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        // Обработка изменения размера терминала
    }
    
    func setTerminalTitle(source: TerminalView, title: String) {
        // Обработка изменения заголовка терминала
    }
    
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // Обработка изменения текущей директории
    }
    
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        // Отправляем данные от терминала в SSH процесс
        terminalService?.sendData(Array(data))
        
        // Логируем для отладки
        if let text = String(data: Data(data), encoding: .utf8) {
            LoggingService.shared.debug("🎯 Terminal input: '\(text.replacingOccurrences(of: "\n", with: "\\n"))'", source: "SwiftTerminalView")
        } else {
            LoggingService.shared.debug("🎯 Terminal input: [binary data, \(data.count) bytes]", source: "SwiftTerminalView")
        }
    }
    
    func scrolled(source: TerminalView, position: Double) {
        // Обработка прокрутки
    }
    
    func clipboardCopy(source: TerminalView, content: Data) {
        LoggingService.shared.debug("📋 Clipboard copy delegate called with \(content.count) bytes", source: "SwiftTerminalView")
        
        // Автоматическое копирование в буфер обмена через делегат SwiftTerm
        if let text = String(data: content, encoding: .utf8) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            LoggingService.shared.debug("📋 Clipboard copy via delegate: '\(text)'", source: "SwiftTerminalView")
        } else {
            LoggingService.shared.debug("📋 Clipboard copy failed: could not decode content", source: "SwiftTerminalView")
        }
    }
    
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        // Обработка изменения выделенного диапазона
        LoggingService.shared.debug("🎯 Selection range changed: \(startY) to \(endY)", source: "SwiftTerminalView")
        
        // Проверяем, есть ли активное выделение
        if source.selectionActive {
            LoggingService.shared.debug("🎯 Selection is now ACTIVE", source: "SwiftTerminalView")
            
            // Попробуем получить текст выделения сразу
            if let selectedText = source.getSelection() {
                LoggingService.shared.debug("🎯 Selection text: '\(selectedText)'", source: "SwiftTerminalView")
            } else {
                LoggingService.shared.debug("🎯 Selection text: nil", source: "SwiftTerminalView")
            }
            
            // Логируем содержимое терминала при изменении выделения
            // Примечание: TerminalView не имеет прямого доступа к coordinator
            LoggingService.shared.debug("🎯 Selection changed - terminal content logging disabled", source: "SwiftTerminalView")
        } else {
            LoggingService.shared.debug("🎯 Selection is now INACTIVE", source: "SwiftTerminalView")
        }
    }
}

// MARK: - GPT Service initialization
extension SwiftTermProfessionalTerminalView {
    private func initializeGPTService() {
        LoggingService.shared.debug("🔧 Initializing GPT Terminal Service", source: "SwiftTermProfessionalTerminalView")
        
        // Get API key from UserDefaults or settings
        let apiKey = UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
        
        if !apiKey.isEmpty {
            LoggingService.shared.info("🔑 OpenAI API key found, creating GPT service", source: "SwiftTermProfessionalTerminalView")
            gptService = GPTTerminalService(
                apiKey: apiKey,
                terminalService: terminalService
            )
            LoggingService.shared.success("✅ GPT Terminal Service initialized successfully", source: "SwiftTermProfessionalTerminalView")
        } else {
            LoggingService.shared.warning("⚠️ OpenAI API key not found. GPT features disabled.", source: "SwiftTermProfessionalTerminalView")
        }
    }
}

#Preview {
    SwiftTermProfessionalTerminalView(
        profile: Profile(
            name: "Test Server",
            host: "example.com",
            port: 22,
            username: "user",
            password: "password",
            privateKeyPath: nil,
            keyType: .password
        ),
        terminalService: SwiftTermProfessionalService()
    )
}
