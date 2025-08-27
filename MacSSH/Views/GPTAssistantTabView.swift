import SwiftUI

struct GPTAssistantTabView: View {
    @ObservedObject var gptService: GPTTerminalService
    
    var body: some View {
        VStack(spacing: 0) {
            // Input area
            VStack(alignment: .leading, spacing: 12) {
                Text("Ask GPT to help with terminal operations:")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                TextField("e.g., 'show files in current directory', 'find all Python files', 'check disk usage', 'install packages', 'configure services'", text: $userRequest, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...10)
                    .frame(minHeight: 100)
                    .disabled(gptService.isProcessing)
                
                HStack {
                    Spacer()
                    Button(action: askGPT) {
                        HStack(spacing: 6) {
                            if gptService.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            Text("Ask GPT")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userRequest.isEmpty || gptService.isProcessing)
                    .controlSize(.large)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Suggested command area
            if let command = suggestedCommand {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(.green)
                        Text("GPT suggests:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    if isEditingCommand {
                        TextField("Edit command", text: $editedCommand)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text(command)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Execute") {
                            executeCommand()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isEditingCommand && editedCommand.isEmpty)
                        
                        Button(isEditingCommand ? "Done" : "Edit") {
                            if isEditingCommand {
                                suggestedCommand = editedCommand
                                isEditingCommand = false
                            } else {
                                editedCommand = command
                                isEditingCommand = true
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Cancel") {
                            resetState()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // State variables
    @State private var userRequest = ""
    @State private var suggestedCommand: String?
    @State private var showingConfirmation = false
    @State private var isEditingCommand = false
    @State private var editedCommand = ""
    
    // Methods
    private func askGPT() {
        guard !userRequest.isEmpty else { return }
        
        LoggingService.shared.info("🤖 User requested GPT assistance: '\(userRequest)'", source: "GPTTerminalView")
        
        Task {
            let result = await gptService.processUserRequest(userRequest)
            
            await MainActor.run {
                LoggingService.shared.debug("📥 Received result from GPT service: '\(result)'", source: "GPTTerminalView")
                
                if let result = result {
                    if result.hasPrefix("✅ Command executed:") {
                        LoggingService.shared.info("✅ Command was executed automatically", source: "GPTTerminalView")
                        resetState()
                    } else if result.hasPrefix("🚫 Command blocked:") {
                        LoggingService.shared.warning("🚫 Command was blocked by security", source: "GPTTerminalView")
                        suggestedCommand = extractCommand(from: result)
                        showingConfirmation = true
                    } else {
                        LoggingService.shared.debug("💬 GPT gave text response, extracting command", source: "GPTTerminalView")
                        suggestedCommand = extractCommand(from: result)
                        showingConfirmation = true
                    }
                } else {
                    LoggingService.shared.warning("⚠️ No result from GPT service", source: "GPTTerminalView")
                }
            }
        }
    }
    
    private func executeCommand() {
        guard let command = suggestedCommand else { return }
        
        LoggingService.shared.info("🚀 User executing suggested command: '\(command)'", source: "GPTTerminalView")
        
        Task {
            do {
                let result = await gptService.processUserRequest("Execute command: \(command)")
                LoggingService.shared.debug("✅ Command execution completed", source: "GPTTerminalView")
            } catch {
                LoggingService.shared.error("❌ Command execution failed: \(error.localizedDescription)", source: "GPTTerminalView")
            }
        }
        
        resetState()
    }
    
    private func resetState() {
        userRequest = ""
        suggestedCommand = nil
        showingConfirmation = false
        isEditingCommand = false
        editedCommand = ""
        LoggingService.shared.debug("🔄 Resetting GPT Terminal View state", source: "GPTTerminalView")
    }
    
    private func extractCommand(from response: String) -> String? {
        LoggingService.shared.debug("🔍 Extracting command from GPT response: '\(response)'", source: "GPTTerminalView")
        
        // Look for command patterns in the response
        let patterns = [
            "```bash\\s*([^`]+)```",
            "```shell\\s*([^`]+)```",
            "`([^`]+)`",
            "command:\\s*([^\\n]+)",
            "execute:\\s*([^\\n]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)) {
                
                let range = Range(match.range(at: 1), in: response)!
                let command = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !command.isEmpty {
                    LoggingService.shared.info("✅ Extracted command from response: '\(command)'", source: "GPTTerminalView")
                    return command
                }
            }
        }
        
        LoggingService.shared.warning("⚠️ No command found in GPT response", source: "GPTTerminalView")
        return nil
    }
}

#Preview {
    GPTAssistantTabView(gptService: GPTTerminalService(

        terminalService: SwiftTermProfessionalService()
    ))
}
