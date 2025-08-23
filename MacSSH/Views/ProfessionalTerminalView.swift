import SwiftUI
import AppKit
import SwiftTerm

struct ProfessionalTerminalView: View {
    let profile: Profile
    @ObservedObject var terminalService: SwiftTermService
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
                SwiftTerminalView(terminalService: terminalService)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .onDisappear {
            // Отключаемся при исчезновении view
            terminalService.disconnect()
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

struct SwiftTerminalView: NSViewRepresentable {
    let terminalService: SwiftTermService
    
    func makeNSView(context: Context) -> TerminalView {
        // Получаем терминал из сервиса или создаем новый
        if let terminal = terminalService.getTerminalView() {
            return terminal
        } else {
            let terminal = TerminalView()
            terminal.configureNativeColors()
            terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            return terminal
        }
    }
    
    func updateNSView(_ nsView: TerminalView, context: Context) {
        // Обновляем терминал при изменении сервиса
        if let terminal = terminalService.getTerminalView() {
            // Если терминал изменился, обновляем ссылку
            if terminal != nsView {
                // В реальном приложении здесь нужно будет обновить view
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
            privateKeyPath: nil,
            keyType: .password
        ),
        terminalService: SwiftTermService()
    )
}
