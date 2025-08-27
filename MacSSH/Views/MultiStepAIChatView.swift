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
                }
                .padding(.horizontal)
            }
            .onChange(of: gptService.chatMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: gptService.isWaitingForConfirmation) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let lastMessage = gptService.chatMessages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                } else if gptService.isWaitingForConfirmation {
                    proxy.scrollTo("pending-command", anchor: .bottom)
                }
            }
        }
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
