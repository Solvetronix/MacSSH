import SwiftUI
import AppKit

struct ProfessionalTerminalView: View {
    let profile: Profile
    @ObservedObject var terminalService: EmbeddedTerminalService
    @State private var commandHistory: [String] = [] // Локальная история команд для текущей сессии
    @State private var currentCommandIndex: Int = 0 // Будет обновляться при добавлении команд
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
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
                
                // Статус подключения
                HStack(spacing: 4) {
                    Circle()
                        .fill(terminalService.isConnected ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(terminalService.isConnected ? "Connected" : "Disconnected")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Основная область терминала
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Вывод терминала (очищаем от лишних символов)
                        Text(terminalService.output
                            .replacingOccurrences(of: "xioneer@XioneerCloud:~$ ", with: "")
                            .replacingOccurrences(of: "\u{1B}[?2004h", with: "") // Убираем escape-код
                            .replacingOccurrences(of: "\u{1B}]0;", with: "") // Убираем начало escape-кода заголовка
                        )
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .id("output")
                        
                        // Текущая командная строка с промптом
                        if terminalService.isConnected {
                            TerminalCommandLineView(
                                profile: profile,
                                commandHistory: $commandHistory, // Локальная история команд
                                currentCommandIndex: $currentCommandIndex,
                                onCommandSubmit: { command in
                                    LoggingService.shared.debug("Command submitted from ProfessionalTerminalView: '\(command)'", source: "ProfessionalTerminalView")
                                    LoggingService.shared.debug("Current history count: \(commandHistory.count)", source: "ProfessionalTerminalView")
                                    terminalService.sendCommand(command)
                                }
                            )
                            .id("commandline")
                            
                            // Небольшой отступ под командной строкой
                            Spacer()
                                .frame(height: 8)
                        }
                    }
                }
                .onChange(of: terminalService.output) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("commandline", anchor: .bottom)
                    }
                }
                .onChange(of: terminalService.isConnected) { isConnected in
                    if isConnected {
                        // Автоматическая прокрутка вниз при подключении
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("commandline", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(terminalBackground)
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            // Добавляем небольшую задержку перед подключением для стабильности
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                connectToSSH()
            }
        }
        .onDisappear {
            // Безопасное отключение с защитой от краша
            LoggingService.shared.debug("ProfessionalTerminalView onDisappear called", source: "ProfessionalTerminalView")
            
            // Сначала очищаем историю команд
            commandHistory.removeAll()
            currentCommandIndex = 0
            
            // Затем отключаем сервис
            DispatchQueue.main.async {
                terminalService.disconnect()
            }
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func connectToSSH() {
        Task {
            do {
                try await terminalService.connectToSSH(profile: profile)
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

#Preview {
    ProfessionalTerminalView(
        profile: Profile(
            name: "Test Server",
            host: "example.com",
            port: 22,
            username: "user",
            password: "password",
            keyType: .password
        ),
        terminalService: EmbeddedTerminalService()
    )
}
