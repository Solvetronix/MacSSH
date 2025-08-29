import SwiftUI

struct MultiStepAIChatView: View {
    @ObservedObject var gptService: GPTTerminalService
    @State private var taskInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages area
            ChatMessagesView(gptService: gptService)
            
            // Input area
            ChatInputView(gptService: gptService, taskInput: $taskInput)
        }
    }
}

// MARK: - Chat Messages View
struct ChatMessagesView: View {
    @ObservedObject var gptService: GPTTerminalService
    @State private var pendingScrollWork: DispatchWorkItem?
    private let scrollDebounceInterval: TimeInterval = 0.12
    
    // Ключ последнего сообщения (учитывает изменение текста/вывода)
    private var lastMessageKey: String {
        if let last = gptService.chatMessages.last {
            return "\(last.id)-\(last.content.count)-\(last.output?.count ?? 0)"
        }
        return "none"
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(gptService.chatMessages) { message in
                        ChatMessageView(message: message)
                            .id(message.id)
                    }
                    
                    // Pending command confirmation
                    if gptService.isWaitingForConfirmation {
                        PendingCommandView(gptService: gptService)
                            .id("pending-command")
                    }
                    
                    // Нижний якорь для стабильного автоскролла
                    Color.clear.frame(height: 1).id("bottom-anchor")
                }
                .padding(.horizontal)
            }
            .onAppear { scrollToBottom(proxy: proxy) }
            .onChange(of: gptService.chatMessages.count) { _, _ in debounceScroll(proxy: proxy) }
            .onChange(of: gptService.isWaitingForConfirmation) { _, _ in debounceScroll(proxy: proxy) }
            .onChange(of: lastMessageKey) { _, _ in debounceScroll(proxy: proxy) }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        // Первый проход — сразу после обновления данных
        DispatchQueue.main.async {
            withAnimation(.none) {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
        // Второй проход — после компоновки, чтобы исключить скрытие за рамкой
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.none) {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }

    private func debounceScroll(proxy: ScrollViewProxy) {
        pendingScrollWork?.cancel()
        let work = DispatchWorkItem { scrollToBottom(proxy: proxy) }
        pendingScrollWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + scrollDebounceInterval, execute: work)
    }
}

// MARK: - Chat Input View
struct ChatInputView: View {
    @ObservedObject var gptService: GPTTerminalService
    @Binding var taskInput: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Task input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Введите задачу для выполнения:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Например: перейди в директорию /var/www и покажи содержимое", text: $taskInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            
            // Action buttons
            HStack {
                Button("Начать выполнение") {
                    startMultiStepExecution()
                }
                .buttonStyle(.borderedProminent)
                .disabled(taskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || gptService.isMultiStepMode)
                
                if gptService.isMultiStepMode {
                    Button("Остановить") {
                        Task {
                            await gptService.stopMultiStepExecution()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }
    
    private func startMultiStepExecution() {
        let task = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }
        
        Task {
            await gptService.startMultiStepExecution(task: task)
        }
        taskInput = ""
    }
}

// MARK: - Pending Command View
struct PendingCommandView: View {
    @ObservedObject var gptService: GPTTerminalService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Ожидание подтверждения команды")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if let command = gptService.pendingCommand {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Команда:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(command)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(gptService.isPendingCommandDangerous ? .red : .primary)
                }
            }
            

            
            HStack {
                Button("Выполнить") {
                    Task {
                        await gptService.confirmNextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(gptService.isPendingCommandDangerous ? .red : .blue)
                
                Button("Отменить") {
                    Task {
                        await gptService.cancelStep()
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    MultiStepAIChatView(gptService: GPTTerminalService(

        terminalService: SwiftTermProfessionalService()
    ))
}
