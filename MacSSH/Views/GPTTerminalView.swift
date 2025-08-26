import SwiftUI

struct GPTTerminalView: View {
    @ObservedObject var gptService: GPTTerminalService
    @State private var userRequest = ""
    @State private var suggestedCommand: String?
    @State private var showingConfirmation = false
    @State private var isEditingCommand = false
    @State private var editedCommand = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI Terminal Assistant")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
            
            // Input area
            VStack(alignment: .leading, spacing: 8) {
                Text("Ask GPT to help with terminal operations:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("e.g., 'show files in current directory', 'find all Python files', 'check disk usage'", text: $userRequest)
                        .textFieldStyle(.roundedBorder)
                        .disabled(gptService.isProcessing)
                    
                    Button(action: askGPT) {
                        if gptService.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(userRequest.isEmpty || gptService.isProcessing)
                }
            }
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
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Error display
            if let error = gptService.lastError {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text("Error:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(height: 200)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Actions
    private func askGPT() {
        guard !userRequest.isEmpty else { return }
        
        LoggingService.shared.info("🤖 User requested GPT assistance: '\(userRequest)'", source: "GPTTerminalView")
        
        Task {
            let result = await gptService.processUserRequest(userRequest)
            
            await MainActor.run {
                if let result = result {
                    LoggingService.shared.debug("📥 Received result from GPT service: '\(result)'", source: "GPTTerminalView")
                    
                    // Check if it's a command execution result
                    if result.hasPrefix("✅ Command executed:") {
                        LoggingService.shared.info("✅ Command was executed automatically", source: "GPTTerminalView")
                        resetState()
                    } else if result.hasPrefix("⚠️ Command blocked") {
                        LoggingService.shared.warning("🚫 Command was blocked by security", source: "GPTTerminalView")
                        suggestedCommand = result
                    } else {
                        LoggingService.shared.debug("💬 GPT gave text response, extracting command", source: "GPTTerminalView")
                        // GPT gave a text response, try to extract command
                        suggestedCommand = extractCommandFromResponse(result)
                    }
                } else {
                    LoggingService.shared.warning("⚠️ No result from GPT service", source: "GPTTerminalView")
                    // No result, might be an error
                    suggestedCommand = nil
                }
            }
        }
    }
    
    private func executeCommand() {
        let commandToExecute = isEditingCommand ? editedCommand : (suggestedCommand ?? "")
        guard !commandToExecute.isEmpty else { return }
        
        LoggingService.shared.info("🚀 User executing suggested command: '\(commandToExecute)'", source: "GPTTerminalView")
        
        // Execute the command through the terminal service
        // This will be handled by the GPT service
        Task {
            let result = await gptService.processUserRequest("Execute: \(commandToExecute)")
            await MainActor.run {
                LoggingService.shared.debug("✅ Command execution completed", source: "GPTTerminalView")
                resetState()
            }
        }
    }
    
    private func resetState() {
        LoggingService.shared.debug("🔄 Resetting GPT Terminal View state", source: "GPTTerminalView")
        userRequest = ""
        suggestedCommand = nil
        isEditingCommand = false
        editedCommand = ""
        gptService.lastError = nil
    }
    
    // MARK: - Helper functions
    private func extractCommandFromResponse(_ response: String) -> String? {
        LoggingService.shared.debug("🔍 Extracting command from GPT response: '\(response)'", source: "GPTTerminalView")
        
        // Try to extract command from GPT's text response
        // This is a fallback when GPT doesn't use tool calls
        
        let lines = response.components(separatedBy: .newlines)
        
        // Look for lines that look like commands
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and explanations
            if trimmed.isEmpty || trimmed.hasPrefix("Here") || trimmed.hasPrefix("You can") {
                continue
            }
            
            // Check if line looks like a command
            if isLikelyCommand(trimmed) {
                LoggingService.shared.info("✅ Extracted command from response: '\(trimmed)'", source: "GPTTerminalView")
                return trimmed
            }
        }
        
        LoggingService.shared.warning("⚠️ No command found in GPT response", source: "GPTTerminalView")
        return nil
    }
    
    private func isLikelyCommand(_ text: String) -> Bool {
        // Simple heuristic to detect if text looks like a command
        let commandPatterns = [
            "^[a-zA-Z]+\\s",           // Starts with word + space
            "^[a-zA-Z]+$",             // Just a command name
            "^[a-zA-Z]+\\s+[a-zA-Z0-9_./-]+", // Command with arguments
            "^cd\\s+",                 // cd command
            "^ls\\s*",                 // ls command
            "^cat\\s+",                // cat command
            "^grep\\s+",               // grep command
            "^find\\s+",               // find command
            "^ps\\s*",                 // ps command
            "^top\\s*",                // top command
            "^df\\s*",                 // df command
            "^du\\s*"                  // du command
        ]
        
        for pattern in commandPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Preview
struct GPTTerminalView_Previews: PreviewProvider {
    static var previews: some View {
        GPTTerminalView(gptService: GPTTerminalService(
            apiKey: "test",
            terminalService: SwiftTermProfessionalService()
        ))
    }
}
