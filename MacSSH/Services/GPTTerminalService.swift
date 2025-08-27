import Foundation
import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let terminalBufferChanged = Notification.Name("terminalBufferChanged")
}

// MARK: - OpenAI API Models
struct OpenAIRequest: Codable {
    let model: String
    let messages: [Message]
    let tools: [Tool]?
    let tool_choice: String?
    
    init(model: String = "gpt-4o", messages: [Message], tools: [Tool]? = nil, tool_choice: String? = nil) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.tool_choice = tool_choice
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

struct Tool: Codable {
    let type: String
    let function: FunctionDefinition
}

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: JSONSchema
    
    init(name: String, description: String, parameters: JSONSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

struct JSONSchema: Codable {
    let type: String
    let properties: [String: PropertyDefinition]
    let required: [String]
}

struct PropertyDefinition: Codable {
    let type: String
    let description: String
    let pattern: String?
    
    init(type: String, description: String, pattern: String? = nil) {
        self.type = type
        self.description = description
        self.pattern = pattern
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: ResponseMessage
}

struct ResponseMessage: Codable {
    let content: String?
    let tool_calls: [ToolCall]?
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Codable {
    let name: String
    let arguments: String
}

// MARK: - Execution Step Model
struct ExecutionStep: Identifiable, Codable {
    let id: UUID
    let stepNumber: Int
    let command: String
    let explanation: String
    let output: String
    let timestamp: Date
    
    init(stepNumber: Int, command: String, explanation: String, output: String) {
        self.id = UUID()
        self.stepNumber = stepNumber
        self.command = command
        self.explanation = explanation
        self.output = output
        self.timestamp = Date()
    }
}

// MARK: - Universal Information Collector
struct UniversalInfoCollector {
    var collectedData: [String: String] = [:]
    
    mutating func collectFromOutput(_ output: String, command: String) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            // Store all output lines with command context
            let key = "\(command)_output"
            collectedData[key] = (collectedData[key] ?? "") + trimmedLine + "  \n"
        }
    }
    
    func generateSummary() -> String {
        var summary = ""
        
        // Combine all collected data
        for (key, value) in collectedData {
            if !value.trimmingCharacters(in: .whitespaces).isEmpty {
                summary += "**\(key):**\n"
                summary += "```\n"
                summary += value.trimmingCharacters(in: .whitespaces)
                summary += "\n```\n\n"
            }
        }
        
        return summary
    }
}

// MARK: - GPT Terminal Service
class GPTTerminalService: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: String?
    
    // Multi-step execution properties
    @Published var isMultiStepMode = false
    @Published var currentStep = 0
    @Published var totalSteps = 0
    @Published var pendingCommand: String?
    @Published var pendingExplanation: String?
    @Published var isWaitingForConfirmation = false
    @Published var executionHistory: [ExecutionStep] = []
    @Published var currentTask: String = ""
    @Published var showingTaskInput = false
    @Published var taskInput: String = ""
    @Published var isPendingCommandDangerous = false
    
    // Chat messages for new interface
    @Published var chatMessages: [ChatMessage] = []
    private var infoCollector = UniversalInfoCollector()
    
    private var apiKey: String
    private let terminalService: SwiftTermProfessionalService
    private var conversationHistory: [Message] = []
    private let maxSteps = 10 // Safety limit
    
    // Universal terminal tool definition
    private let terminalTool = Tool(
        type: "function",
        function: FunctionDefinition(
            name: "execute_terminal_command",
            description: "Execute shell commands in the connected SSH terminal. Use this for file operations, system administration, navigation, process management, network operations, package management, and any other terminal tasks. Always consider security implications and use appropriate commands for the task.",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "command": PropertyDefinition(
                        type: "string",
                        description: "Shell command to execute. Can be any valid shell command including: file operations (ls, cd, cat, grep, find, cp, mv, rm), system commands (ps, top, df, du), network tools (ping, curl, wget), package management (apt, yum, brew), process management (kill, pkill), and more. Always use appropriate flags and options for better results."
                    )
                ],
                required: ["command"]
            )
        )
    )
    
    init(terminalService: SwiftTermProfessionalService) {
        self.terminalService = terminalService
        self.apiKey = GPTTerminalService.resolveApiKey()
        if self.apiKey.isEmpty {
            LoggingService.shared.error("❌ OpenAI API key is empty. Set it in settings.", source: "GPTTerminalService")
        } else {
            LoggingService.shared.info("🔑 OpenAI API key loaded", source: "GPTTerminalService")
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminalBufferChanged),
            name: .terminalBufferChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Cleanup if needed
    }
    
    @objc private func handleTerminalBufferChanged() {
        currentCompletionHandler?.bufferChanged()
    }
    
    private static func resolveApiKey() -> String {
        // Try multiple locations to improve robustness
        let defaults = UserDefaults.standard
        if let key = defaults.string(forKey: "OpenAIAPIKey"), !key.isEmpty { return key }
        if let key = defaults.string(forKey: "OpenAI_API_Key"), !key.isEmpty { return key }
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty { return env }
        return ""
    }
    
    // MARK: - Main processing function
    func processUserRequest(_ request: String) async -> String? {
        LoggingService.shared.info("🤖 Processing GPT request: '\(request)'", source: "GPTTerminalService")
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        do {
            // Create OpenAI request with universal tool
            LoggingService.shared.debug("📝 Creating OpenAI request", source: "GPTTerminalService")
            let openAIRequest = createRequest(userRequest: request)
            
            // Call OpenAI API
            LoggingService.shared.debug("🌐 Calling OpenAI API", source: "GPTTerminalService")
            let response = try await callOpenAI(openAIRequest)
            
            // Parse and execute tool calls
            LoggingService.shared.debug("🔍 Parsing OpenAI response", source: "GPTTerminalService")
            return try await handleResponse(response)
            
        } catch let gptError as GPTError {
            let userMessage = gptError.userFriendlyMessage
            await MainActor.run { lastError = userMessage }
            LoggingService.shared.error("❌ GPT API error: \(gptError.localizedDescription)", source: "GPTTerminalService")
            return nil
        } catch {
            await MainActor.run { lastError = error.localizedDescription }
            LoggingService.shared.error("❌ GPT API error: \(error.localizedDescription)", source: "GPTTerminalService")
            return nil
        }
    }
    
    // MARK: - Multi-step execution
    func startMultiStepExecution(task: String) async {
        LoggingService.shared.info("🚀 Starting multi-step execution: '\(task)'", source: "GPTTerminalService")
        
        await MainActor.run {
            isMultiStepMode = true
            currentStep = 0
            totalSteps = 0
            currentTask = task
            executionHistory.removeAll()
            conversationHistory.removeAll()
            showingTaskInput = false
            taskInput = ""
            
            // Clear chat history and info collector
            clearChatHistory()
            infoCollector = UniversalInfoCollector()
            addUserMessage(task)
            addAssistantMessage("Я начну выполнение задачи: \(task)")
        }
        
        // Initialize conversation with task
        let systemMessage = Message(
            role: "system",
            content: """
            You are an advanced AI terminal assistant with deep expertise in Unix/Linux systems, shell scripting, and system administration. You can execute multi-step tasks intelligently.
            
            Guidelines:
            - Break down complex tasks into logical, efficient steps
            - Use the execute_terminal_command tool for each step
            - Provide clear, detailed explanations for each command
            - Analyze terminal output critically to understand what happened
            - Use the terminal output to make intelligent decisions about next steps
            - If a command fails, analyze the error and try smarter alternative approaches
            - For navigation tasks: execute the final navigation command (like cd www) and then say "TASK COMPLETE"
            - For file operations: verify the file/directory exists, check permissions, and ensure safety
            - For system operations: consider security implications and use best practices
            - Use **bold text** for important information and `code` for commands
            - Maximum \(maxSteps) steps allowed for safety
            
            Current task: \(task)
            
            IMPORTANT: 
            - After each command execution, you will receive the terminal output
            - Use this output to understand what happened and plan your next step accordingly
            - For navigation tasks: execute the actual navigation command (cd, etc.) and then say "TASK COMPLETE"
            - If a step fails, analyze the error message and try alternative approaches
            - Be proactive - if you see potential issues, address them before they become problems
            - Use your knowledge of Unix/Linux systems to make intelligent decisions
            - Don't just plan navigation - actually execute the cd command when you know the target directory exists
            - Say "TASK COMPLETE" immediately after successfully executing the final command
            - For information gathering tasks, say "TASK COMPLETE" after collecting comprehensive information
            - Use **bold text** for emphasis and `code` formatting for commands and paths
            - IMPORTANT: After 3-5 steps of information gathering, provide a summary and say "TASK COMPLETE"
            """
        )
        
        conversationHistory = [systemMessage]
        
        // Start the first step
        await planNextStep()
    }
    
    func planNextStep() async {
        // Stop immediately if multi-step mode was turned off
        guard isMultiStepMode else { return }
        guard currentStep < 3 else {
            await MainActor.run {
                isMultiStepMode = false
                lastError = "Maximum number of steps (3) reached. Task stopped for safety."
            }
            return
        }
        
        LoggingService.shared.info("🧠 Planning step \(currentStep + 1)", source: "GPTTerminalService")
        
        // Create request for next step planning
        let planningRequest = Message(
            role: "user",
            content: """
            Plan the next step to complete this task: \(currentTask)
            
            CONTEXT SUMMARY:
            - Current step: \(currentStep)
            - Total steps executed: \(executionHistory.count)
            - Task objective: \(currentTask)
            
            PREVIOUS STEPS DETAILED:
            \(executionHistory.map { step in
                """
                Step \(step.stepNumber):
                - Command: \(step.command)
                - Explanation: \(step.explanation)
                - Output length: \(step.output.count) characters
                - Output preview: \(String(step.output.prefix(200)))\(step.output.count > 200 ? "..." : "")
                """
            }.joined(separator: "\n\n"))
            
            ANALYSIS INSTRUCTIONS:
            Based on the terminal output from previous steps, what is the next command to execute? 
            Analyze the output to understand what worked, what failed, and what needs to be done next.
            
            CRITICAL: The "Output:" section contains the ACTUAL terminal output from each command. 
            This is the real data you need to analyze to make decisions.
            
            TASK COMPLETION ANALYSIS:
            - If the requested information has been successfully gathered from the command outputs, say "TASK COMPLETE"
            - If the command outputs contain the data that was asked for in the original task, say "TASK COMPLETE"
            - If no further commands are needed to complete the task objective, say "TASK COMPLETE"
            - If you have executed 2-3 successful commands with useful output, say "TASK COMPLETE"
            - Do not repeat the same command multiple times
            - Maximum 3 steps allowed - if you've done 3 steps, say "TASK COMPLETE"
            
            COMMAND FORMATTING:
            - When providing commands, use ONLY the command itself in code blocks, like: `cut -d: -f1 /etc/passwd`
            - DO NOT add 'sh' prefix or extra formatting to commands
            - DO NOT use ```sh or ```bash - use only ``` for code blocks
            - Commands should be clean and ready to execute directly
            
            Provide a clear explanation of what this command will do and why it's needed.
            
            Be intelligent and proactive - suggest the most efficient approach. Use the best command for the task.
            
            IMPORTANT: If you believe the task is complete based on the command outputs, say "TASK COMPLETE" instead of suggesting another command.
            """
        )
        
        LoggingService.shared.info("🧠 Planning request content: \(planningRequest.content)", source: "GPTTerminalService")
        LoggingService.shared.info("📊 Execution history count: \(executionHistory.count)", source: "GPTTerminalService")
        if !executionHistory.isEmpty {
            LoggingService.shared.info("📋 Last step output: \(executionHistory.last?.output ?? "No output")", source: "GPTTerminalService")
            LoggingService.shared.info("📋 Last step command: \(executionHistory.last?.command ?? "No command")", source: "GPTTerminalService")
        }
        
        // Log the full execution history for debugging
        for (index, step) in executionHistory.enumerated() {
            LoggingService.shared.info("📋 Step \(index): Command='\(step.command)', Output='\(step.output)'", source: "GPTTerminalService")
        }
        
        conversationHistory.append(planningRequest)
        
        do {
            // Clip planning prompt to avoid model limits
            let clippedPlanning = sanitizeForGPT(planningRequest.content, maxChars: 12000)
            let openAIRequest = OpenAIRequest(
                model: "gpt-4o",
                messages: conversationHistory.dropLast() + [Message(role: "user", content: clippedPlanning)],
                tools: [], // Remove tools to prevent GPT from executing commands
                tool_choice: "none"
            )
            
            let response = try await callOpenAI(openAIRequest)
            
            // Extract the planned command from GPT's response
            let responseContent = response.choices.first?.message.content ?? ""
            
            // Parse command from GPT's response (look for code blocks or quoted commands)
            let command = extractCommandFromResponse(responseContent)
            let explanation = responseContent
            
            // Use GPT to determine if task is complete (only if we have execution history and at least 1 step)
            let gptCompletionCheck = executionHistory.count >= 1 ? await checkTaskCompletionWithGPT(
                originalTask: currentTask,
                executionHistory: executionHistory,
                responseContent: sanitizeForGPT(responseContent, maxChars: 6000)
            ) : false
            
            let phraseCompletion = responseContent.lowercased().contains("task complete")
            let isTaskComplete = gptCompletionCheck || phraseCompletion || currentStep >= 3 // Fallback: limit to 3 steps maximum
            
            LoggingService.shared.info("🔍 Checking task completion. Response contains 'task complete': \(responseContent.lowercased().contains("task complete"))", source: "GPTTerminalService")
            LoggingService.shared.info("🔍 Response content: \(responseContent)", source: "GPTTerminalService")
            
            if isTaskComplete {
                // Task is complete, finish regardless of command
                await MainActor.run {
                    isMultiStepMode = false
                    totalSteps = currentStep
                }
                
                // Add summary message to chat
                let summary = await createTaskSummary()
                addSummaryMessage("**Задача завершена!** \(summary)")
                
                LoggingService.shared.success("✅ Task completed in \(currentStep) steps", source: "GPTTerminalService")
                return
            } else if !command.isEmpty {
                // Check if this command was already executed recently
                let recentCommands = executionHistory.suffix(2).map { $0.command }
                if recentCommands.contains(command) {
                    LoggingService.shared.warning("⚠️ Command '\(command)' was already executed recently. Concluding task to avoid loop.", source: "GPTTerminalService")
                    await MainActor.run {
                        isMultiStepMode = false
                        totalSteps = currentStep
                    }
                    let summary = await createTaskSummary()
                    addSummaryMessage("**Задача завершена!** \(summary)")
                    return
                }
                
                // Add assistant message to chat with command included (merged message)
                addAssistantMessage(explanation, command: command, isDangerous: isDangerousCommand(command), stepNumber: currentStep + 1)
                
                await MainActor.run {
                    pendingCommand = command
                    pendingExplanation = explanation
                    isWaitingForConfirmation = true
                    isPendingCommandDangerous = isDangerousCommand(command)
                }
                
                LoggingService.shared.info("📋 Planned step \(currentStep + 1): \(command)", source: "GPTTerminalService")
            } else {
                // No command found and no task completion detected
                // Check if we're repeating the same command multiple times
                if currentStep >= 2 {
                    let lastCommands = executionHistory.suffix(2).map { $0.command }
                    if lastCommands.count >= 2 && lastCommands[0] == lastCommands[1] {
                        LoggingService.shared.warning("⚠️ Same command repeated twice. Completing task...", source: "GPTTerminalService")
                        
                        await MainActor.run {
                            isMultiStepMode = false
                            totalSteps = currentStep
                        }
                        
                        // Add summary message to chat
                        let summary = await createTaskSummary()
                        addSummaryMessage("**Задача завершена!** \(summary)")
                        
                        LoggingService.shared.success("✅ Task completed after command repetition", source: "GPTTerminalService")
                        return
                    }
                }
                
                if currentStep >= 3 {
                    // Force completion after 3 steps
                    LoggingService.shared.info("🔄 Reached maximum steps (3). Completing task...", source: "GPTTerminalService")
                    
                    await MainActor.run {
                        isMultiStepMode = false
                        totalSteps = currentStep
                    }
                    
                    // Add summary message to chat
                    let summary = await createTaskSummary()
                    addSummaryMessage("**Задача завершена!** \(summary)")
                    
                    LoggingService.shared.success("✅ Task completed after maximum steps", source: "GPTTerminalService")
                    return
                } else {
                    // Continue with next step
                    LoggingService.shared.info("🔄 GPT didn't indicate task completion. Planning next step...", source: "GPTTerminalService")
                    await planNextStep()
                    return
                }
            }
            
        } catch {
            let errText = error.localizedDescription.lowercased()
            if errText.contains("429") || errText.contains("rate limit") {
                LoggingService.shared.error("❌ OpenAI rate limit: \(error.localizedDescription)", source: "GPTTerminalService")
                await MainActor.run {
                    isMultiStepMode = false
                    lastError = "Rate limit from OpenAI. Please retry in ~20s."
                }
                return
            }
            await MainActor.run {
                isMultiStepMode = false
                lastError = "Failed to plan next step: \(error.localizedDescription)"
            }
        }
    }
    
    func confirmNextStep() async {
        guard let command = pendingCommand, let explanation = pendingExplanation else { return }
        
        LoggingService.shared.info("✅ User confirmed step \(currentStep): \(command)", source: "GPTTerminalService")
        
        await MainActor.run {
            isWaitingForConfirmation = false
            pendingCommand = nil
            pendingExplanation = nil
            isPendingCommandDangerous = false
        }
        
        do {
            // Execute the command and get terminal output
            let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
            let commandJson = "{\"command\":\"\(escapedCommand)\"}"
            let terminalOutput = try await executeTerminalCommand(commandJson)
            
            // Log the actual terminal output
            LoggingService.shared.info("📋 Command '\(command)' output: \(terminalOutput)", source: "GPTTerminalService")
            
            // Additional verification that terminal is completely ready before analysis
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Final check that terminal output is stable
            let finalOutputCheck = await terminalService.getCurrentOutput() ?? ""
            let finalNewOutput = String(finalOutputCheck.dropFirst(outputBeforeCommand.count))
            
            // Use the most complete output
            let finalTerminalOutput = finalNewOutput.isEmpty ? terminalOutput : finalNewOutput
            
            LoggingService.shared.info("🔍 Final verified output for analysis: '\(finalTerminalOutput)'", source: "GPTTerminalService")
            
            // Collect information from output
            infoCollector.collectFromOutput(finalTerminalOutput, command: command)
            
            // Add output to the existing assistant message
            addOutputToLastAssistantMessage(finalTerminalOutput)
            
            // Add to execution history
            let step = ExecutionStep(
                stepNumber: currentStep,
                command: command,
                explanation: explanation,
                output: finalTerminalOutput
            )
            
            await MainActor.run {
                executionHistory.append(step)
                currentStep += 1 // Increment step counter
            }
            
            // Plan next step
            await planNextStep()
            
        } catch {
            LoggingService.shared.warning("⚠️ Command execution failed: \(error.localizedDescription)", source: "GPTTerminalService")
            
            let step = ExecutionStep(
                stepNumber: currentStep,
                command: command,
                explanation: explanation,
                output: "Error: \(error.localizedDescription)"
            )
            
            await MainActor.run {
                executionHistory.append(step)
                currentStep += 1
            }
            
            // Plan next step even on error
            await planNextStep()
        }
    }
    
    func cancelStep() async {
        LoggingService.shared.info("❌ User cancelled step \(currentStep)", source: "GPTTerminalService")
        
        await MainActor.run {
            isWaitingForConfirmation = false
            pendingCommand = nil
            pendingExplanation = nil
            isPendingCommandDangerous = false
            isMultiStepMode = false
        }
    }
    
    func stopMultiStepExecution() async {
        LoggingService.shared.info("🛑 Stopping multi-step execution", source: "GPTTerminalService")
        
        await MainActor.run {
            isMultiStepMode = false
            isWaitingForConfirmation = false
            pendingCommand = nil
            pendingExplanation = nil
            totalSteps = currentStep
        }
    }
    
    // MARK: - Request creation
    private func createRequest(userRequest: String) -> OpenAIRequest {
        let systemMessage = Message(
            role: "system",
            content: """
            You are an advanced terminal assistant with deep knowledge of Unix/Linux systems, shell scripting, and system administration.
            
            Guidelines:
            - Always use the execute_terminal_command tool for terminal operations
            - Generate appropriate shell commands based on user requests
            - Be intelligent and proactive - suggest better approaches when possible
            - Consider the context, current working directory, and system state
            - Use best practices for security and efficiency
            - Provide clear explanations for complex commands
            - Handle errors gracefully and suggest alternatives
            - For file operations, consider permissions and safety
            - For system operations, be aware of potential impacts
            """
        )
        
        let userMessage = Message(role: "user", content: sanitizeForGPT(userRequest, maxChars: 12000))
        
        return OpenAIRequest(
            model: "gpt-4o",
            messages: [systemMessage, userMessage],
            tools: [terminalTool],
            tool_choice: "auto"
        )
    }

    // MARK: - Prompt sanitation and clipping
    /// Remove ANSI, normalize newlines, and clip long text to fit model/context limits
    private func sanitizeForGPT(_ text: String, maxChars: Int = 20000) -> String {
        // Strip ANSI escape sequences
        let ansiPattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
        let regex = try? NSRegularExpression(pattern: ansiPattern, options: [])
        var clean = text
        if let regex = regex {
            let range = NSRange(location: 0, length: (clean as NSString).length)
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
        }
        // Normalize CRLF/CR -> LF
        clean = clean.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        // Fast path
        if clean.count <= maxChars { return clean }
        // Head/Tail clipping to preserve начало и конец вывода
        let marker = "\n\n... [truncated] ...\n\n"
        let reserve = marker.count
        let headCount = max(2000, min(8000, maxChars * 2 / 3))
        let tailCount = max(1000, maxChars - headCount - reserve)
        let head = String(clean.prefix(headCount))
        let tail = String(clean.suffix(tailCount))
        return head + marker + tail
    }
    
    // MARK: - OpenAI API call
    func callOpenAI(_ request: OpenAIRequest) async throws -> OpenAIResponse {
        LoggingService.shared.info("🌐 OpenAI API call", source: "GPTTerminalService")
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            LoggingService.shared.error("❌ Invalid OpenAI API URL", source: "GPTTerminalService")
            throw GPTError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            LoggingService.shared.error("❌ Invalid HTTP response from OpenAI", source: "GPTTerminalService")
            throw GPTError.apiError("Invalid HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unknown error"
            LoggingService.shared.error("❌ OpenAI API error: HTTP \(httpResponse.statusCode) - \(errorData)", source: "GPTTerminalService")
            
            // Special handling for quota exceeded
            if httpResponse.statusCode == 429 && errorData.contains("insufficient_quota") {
                LoggingService.shared.error("💳 OpenAI API quota exceeded", source: "GPTTerminalService")
                throw GPTError.quotaExceeded
            }
            
            throw GPTError.apiError("HTTP \(httpResponse.statusCode): \(errorData)")
        }
        
        let decoder = JSONDecoder()
        let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
        
        return openAIResponse
    }
    
    // MARK: - Simplified OpenAI API call for plan generation
    func callOpenAI(prompt: String, systemPrompt: String) async throws -> String {
        let request = OpenAIRequest(
            model: "gpt-4o",
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: sanitizeForGPT(prompt, maxChars: 12000))
            ]
        )
        
        let response = try await callOpenAI(request)
        
        guard let content = response.choices.first?.message.content else {
            throw GPTError.noResponse
        }
        
        return content
    }
    
    // MARK: - Response handling
    private func handleResponse(_ response: OpenAIResponse) async throws -> String? {
        guard let choice = response.choices.first else {
            LoggingService.shared.error("❌ No choices in OpenAI response", source: "GPTTerminalService")
            throw GPTError.noResponse
        }
        
        // Check if GPT wants to call a tool
        if let toolCalls = choice.message.tool_calls, !toolCalls.isEmpty {
            LoggingService.shared.info("🔧 GPT requested tool calls: \(toolCalls.count)", source: "GPTTerminalService")
            return try await handleToolCalls(toolCalls)
        }
        
        // GPT gave a text response (no tool call needed)
        if let content = choice.message.content {
            LoggingService.shared.info("💬 GPT text response: '\(content)'", source: "GPTTerminalService")
            return content
        }
        
        LoggingService.shared.warning("⚠️ No content or tool calls in GPT response", source: "GPTTerminalService")
        return nil
    }
    
    // MARK: - Tool call handling
    private func handleToolCalls(_ toolCalls: [ToolCall]) async throws -> String? {
        var results: [String] = []
        
        for (index, toolCall) in toolCalls.enumerated() {
            if toolCall.function.name == "execute_terminal_command" {
                LoggingService.shared.info("⚡ Executing terminal command from GPT", source: "GPTTerminalService")
                let result = try await executeTerminalCommand(toolCall.function.arguments)
                results.append(result)
            } else {
                LoggingService.shared.warning("⚠️ Unknown tool call: \(toolCall.function.name)", source: "GPTTerminalService")
            }
        }
        
        let finalResult = results.joined(separator: "\n")
        LoggingService.shared.info("✅ Tool calls completed: \(finalResult)", source: "GPTTerminalService")
        return finalResult
    }
    
    // MARK: - Terminal command execution
    private func executeTerminalCommand(_ arguments: String) async throws -> String {
        // Parse command from JSON arguments
        guard let command = parseCommand(arguments) else {
            LoggingService.shared.error("❌ Failed to parse command from arguments: '\(arguments)'", source: "GPTTerminalService")
            throw GPTError.invalidCommand("Failed to parse command from: \(arguments)")
        }
        
        LoggingService.shared.info("📝 Parsed command: '\(command)'", source: "GPTTerminalService")
        
        // Execute command through existing terminal service
        LoggingService.shared.info("🚀 Sending command to terminal: '\(command)'", source: "GPTTerminalService")
        
        // Save current output state before executing command
        outputBeforeCommand = await terminalService.getCurrentOutput() ?? ""
        
        // Wait a moment for terminal to stabilize
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await MainActor.run {
            terminalService.sendCommand(command)
        }
        
        // Ожидаем строго по событию промпта
        let actualOutput = await waitForCommandCompletion(command: command)
        
        // Финальная проверка
        let finalCheck = await terminalService.getCurrentOutput() ?? ""
        let finalNewOutput = String(finalCheck.dropFirst(outputBeforeCommand.count))
        
        let verifiedOutput = finalNewOutput.isEmpty ? actualOutput : actualOutput
        
        LoggingService.shared.success("✅ GPT executed command successfully: '\(command)'", source: "GPTTerminalService")
        LoggingService.shared.info("📋 Final verified command output: '\(verifiedOutput)'", source: "GPTTerminalService")
        
        return verifiedOutput
    }
    
    // MARK: - Enhanced Command Completion Detection
    
    /// Enhanced method to ensure command completion with multiple verification layers
    private func ensureCommandCompletion(command: String, initialOutput: String) async -> String {
        LoggingService.shared.info("🔍 Enhanced completion verification for: '\(command)'", source: "GPTTerminalService")
        
        // First layer: Wait for basic completion
        let basicOutput = await waitForCommandCompletion(command: command)
        
        // Second layer: Additional stability check
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let stabilityCheck = await terminalService.getCurrentOutput() ?? ""
        let stabilityNewOutput = String(stabilityCheck.dropFirst(outputBeforeCommand.count))
        
        // Third layer: Prompt detection verification
        let hasPrompt = stabilityNewOutput.contains("$ ") || stabilityNewOutput.contains("# ") || 
                       stabilityNewOutput.contains("> ") || stabilityNewOutput.contains("bash$") || 
                       stabilityNewOutput.contains("zsh$") || stabilityNewOutput.contains("sh$")
        
        // Fourth layer: Command-specific completion verification
        let isCommandComplete = isCommandSpecificCompletion(command: command, output: stabilityNewOutput)
        
        // Use the most complete output
        let finalOutput = stabilityNewOutput.isEmpty ? basicOutput : stabilityNewOutput
        
        LoggingService.shared.info("🔍 Completion verification results:", source: "GPTTerminalService")
        LoggingService.shared.info("  - Has prompt: \(hasPrompt)", source: "GPTTerminalService")
        LoggingService.shared.info("  - Command-specific complete: \(isCommandComplete)", source: "GPTTerminalService")
        LoggingService.shared.info("  - Output length: \(finalOutput.count)", source: "GPTTerminalService")
        
        return finalOutput
    }
    
    // MARK: - Command parsing
    private func parseCommand(_ arguments: String) -> String? {
        LoggingService.shared.debug("🔍 Parsing JSON arguments: '\(arguments)'", source: "GPTTerminalService")
        
        // Try to parse as JSON first
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = json["command"] as? String {
            let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
            LoggingService.shared.debug("✅ Successfully parsed command from JSON: '\(trimmedCommand)'", source: "GPTTerminalService")
            return trimmedCommand
        }
        
        // Fallback: try to extract command from simple format
        if arguments.hasPrefix("{\"command\":\"") && arguments.hasSuffix("\"}") {
            let startIndex = arguments.index(arguments.startIndex, offsetBy: 12) // Skip {"command":"
            let endIndex = arguments.index(arguments.endIndex, offsetBy: -2) // Skip "}
            let command = String(arguments[startIndex..<endIndex])
                .replacingOccurrences(of: "\\\"", with: "\"") // Unescape quotes
            let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
            LoggingService.shared.debug("✅ Successfully parsed command from fallback: '\(trimmedCommand)'", source: "GPTTerminalService")
            return trimmedCommand
        }
        
        LoggingService.shared.error("❌ Failed to parse command from arguments: '\(arguments)'", source: "GPTTerminalService")
        return nil
    }
    
    // MARK: - Terminal output capture
    private var lastCommandTime: Date = Date()
    private var outputBeforeCommand: String = ""
    
    private func waitForCommandCompletion(command: String) async -> String {
        LoggingService.shared.info("⏳ Waiting for command completion (prompt-based, event-driven): '\(command)'", source: "GPTTerminalService")
        
        return await withCheckedContinuation { continuation in
            let completionHandler = PromptCompletionHandler(
                initialOutputLength: outputBeforeCommand.count,
                terminalService: terminalService,
                onComplete: { [weak self] output in
                    self?.currentCompletionHandler = nil
                    continuation.resume(returning: output)
                }
            )
            
            self.currentCompletionHandler = completionHandler
            completionHandler.checkNow()
        }
    }
    
    // Event-based prompt detector without timers/markers
    private class PromptCompletionHandler {
        private let initialOutputLength: Int
        private let onComplete: (String) -> Void
        private weak var terminalService: SwiftTermProfessionalService?
        
        // Guard against multiple resumes
        private var didResume = false
        private let resumeQueue = DispatchQueue(label: "macssh.prompt-completion.resume")
        
        // Common prompt patterns (configurable later via Profile if needed)
        private let promptRegexes: [NSRegularExpression] = {
            let patterns = [
                "[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:[^\n]*\\$\\s*$", // user@host:path$
                "[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:[^\n]*#\\s*$",     // root prompt
                "\\$\\s*$",                                        // simple $
                "#\\s*$",                                             // simple #
                ">\\s*$",                                             // simple > (some shells)
                "\\[[^\\]]+\\]\\s?\\$\\s*$"                 // [venv] $
            ]
            return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]) }
        }()
        
        init(initialOutputLength: Int, terminalService: SwiftTermProfessionalService, onComplete: @escaping (String) -> Void) {
            self.initialOutputLength = initialOutputLength
            self.terminalService = terminalService
            self.onComplete = onComplete
        }
        
        func bufferChanged() {
            checkNow()
        }
        
        func checkNow() {
            Task { @MainActor in
                let full = await terminalService?.getCurrentOutput() ?? ""
                // Work only with the suffix produced after command start
                let start = full.index(full.startIndex, offsetBy: max(0, initialOutputLength))
                let suffix = String(full[start...])
                guard let tailInSuffix = promptTailRange(in: suffix) else { return }
                var shouldResume = false
                resumeQueue.sync { if !didResume { didResume = true; shouldResume = true } }
                guard shouldResume else { return }
                // Compute tail range in original 'full'
                let tailLower = full.index(start, offsetBy: suffix.distance(from: suffix.startIndex, to: tailInSuffix.lowerBound))
                // Safe content range [start ..< tailLower]
                let contentRange: Range<String.Index> = start <= tailLower ? start..<tailLower : start..<start
                let result = String(full[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                onComplete(result.isEmpty ? "Command executed successfully" : result)
            }
        }
        
        private func matchesPromptTail(in text: String) -> Bool {
            for rx in promptRegexes { if rx.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil { return true } }
            return false
        }
        
        private func promptTailRange(in text: String) -> Range<String.Index>? {
            for rx in promptRegexes {
                if let m = rx.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                    if let r = Range(m.range, in: text) { return r }
                }
            }
            return nil
        }
    }
    
    // Property to store current completion handler
    private var currentCompletionHandler: PromptCompletionHandler?
    

    
    // Helper method to check for command-specific completion patterns
    private func isCommandSpecificCompletion(command: String, output: String) -> Bool {
        let cmd = command.lowercased()
        let out = output.lowercased()
        
        // Check for specific command completion patterns
        if cmd.contains("find") && (out.contains("no such file") || out.contains("0 files") || out.contains("total") || 
                                   out.contains("$ ") || out.contains("# ") || out.contains("> ") ||
                                   out.contains("rise@") || out.contains("bash$") || out.contains("zsh$")) {
            return true
        }
        
        if cmd.contains("grep") && (out.contains("no such file") || out.contains("binary file") || out.contains("matches")) {
            return true
        }
        
        if cmd.contains("ls") && (out.contains("no such file") || out.contains("total")) {
            return true
        }
        
        if cmd.contains("cat") && (out.contains("no such file") || out.contains("is a directory")) {
            return true
        }
        
        if cmd.contains("ps") && (out.contains("pid") || out.contains("command")) {
            return true
        }
        
        if cmd.contains("top") && out.contains("processes") {
            return true
        }
        
        if cmd.contains("df") && out.contains("filesystem") {
            return true
        }
        
        if cmd.contains("du") && out.contains("total") {
            return true
        }
        
        // For interactive commands, check for specific completion indicators
        if cmd.contains("vim") || cmd.contains("nano") || cmd.contains("less") || cmd.contains("more") {
            return out.contains("$ ") || out.contains("# ") || out.contains("> ")
        }
        
        return false
    }
    
    private func getTerminalOutput() async -> String {
        // Get the current terminal output
        let currentOutput = await terminalService.getCurrentOutput() ?? ""
        
        // Extract only the new output (after the command was sent)
        let newOutput = String(currentOutput.dropFirst(outputBeforeCommand.count))
        
        LoggingService.shared.info("📥 Extracted new output: '\(newOutput)'", source: "GPTTerminalService")
        
        return newOutput.isEmpty ? "Command executed successfully" : newOutput
    }
    
    private func clearTerminalOutput() async {
        // Clear the terminal output buffer to prevent old output from being included in next step
        terminalService.clearOutput()
    }
    
    // MARK: - Command validation
    private func isDangerousCommand(_ command: String) -> Bool {
        LoggingService.shared.debug("🔒 Checking command security: '\(command)'", source: "GPTTerminalService")
        
        // Check for dangerous patterns
        let dangerousPatterns = [
            "rm\\s+-rf",           // Force delete
            "sudo\\s+",            // Privileged commands
            "chmod\\s+777",        // Dangerous permissions
            "dd\\s+if=",           // Disk operations
            "mkfs",                // Format filesystem
            "format",              // Format
            "shutdown",            // System shutdown
            "reboot",              // System reboot
            "halt",                // System halt
            "init\\s+0",           // System halt
            "killall",             // Kill all processes
            "pkill\\s+-9",         // Force kill
            ">\\s*/dev/[^n]",      // Write to device files (but allow /dev/null)
            "\\|\\s*tee\\s+/dev/[^n]"  // Write to device files (but allow /dev/null)
        ]
        
        for pattern in dangerousPatterns {
            if command.range(of: pattern, options: .regularExpression) != nil {
                LoggingService.shared.warning("⚠️ Dangerous command pattern detected: '\(pattern)' in command: '\(command)'", source: "GPTTerminalService")
                return true
            }
        }
        
        LoggingService.shared.debug("✅ Command is safe", source: "GPTTerminalService")
        return false
    }
    
    // MARK: - Chat Interface Methods
    func addChatMessage(_ message: ChatMessage) {
        DispatchQueue.main.async {
            self.chatMessages.append(message)
        }
    }
    
    func clearChatHistory() {
        DispatchQueue.main.async {
            self.chatMessages.removeAll()
        }
    }
    
    func addUserMessage(_ content: String) {
        let message = ChatMessage(type: .user, content: content)
        addChatMessage(message)
    }
    
    func addAssistantMessage(_ content: String, command: String? = nil, isDangerous: Bool = false, stepNumber: Int? = nil) {
        let message = ChatMessage(type: .assistant, content: content, command: command, isDangerous: isDangerous, stepNumber: stepNumber)
        addChatMessage(message)
    }
    
    func addCommandMessage(_ content: String, command: String, output: String? = nil, isDangerous: Bool = false, stepNumber: Int? = nil) {
        let message = ChatMessage(type: .command, content: content, command: command, output: output, isDangerous: isDangerous, stepNumber: stepNumber)
        addChatMessage(message)
    }
    
    func addOutputMessage(_ content: String, output: String) {
        let message = ChatMessage(type: .output, content: content, output: output)
        addChatMessage(message)
    }
    
    func addSummaryMessage(_ content: String) {
        let message = ChatMessage(type: .summary, content: content)
        addChatMessage(message)
    }
    
    func addOutputToLastAssistantMessage(_ output: String) {
        DispatchQueue.main.async {
            if let lastIndex = self.chatMessages.lastIndex(where: { $0.type == .assistant && $0.command != nil }) {
                // Create a new message with the output added
                let originalMessage = self.chatMessages[lastIndex]
                let updatedMessage = ChatMessage(
                    type: .assistant,
                    content: originalMessage.content,
                    command: originalMessage.command,
                    output: output,
                    isDangerous: originalMessage.isDangerous,
                    stepNumber: originalMessage.stepNumber
                )
                self.chatMessages[lastIndex] = updatedMessage
            }
        }
    }
    
    private func createTaskSummary() async -> String {
        // Get collected information
        let collectedInfo = infoCollector.generateSummary()
        
        LoggingService.shared.info("📊 Collected info: \(collectedInfo)", source: "GPTTerminalService")
        
        if !collectedInfo.isEmpty {
            // Send collected information through GPT for summarization
            let conciseAnswer = await generateConciseSummary(from: collectedInfo, for: currentTask)
            
            LoggingService.shared.info("🤖 GPT summary: \(conciseAnswer)", source: "GPTTerminalService")
            
            if !conciseAnswer.isEmpty {
                return conciseAnswer
            }
        }
        
        // Fallback: simple completion message
        return "✅ Задача выполнена успешно!"
    }
    
    private func extractUniversalAnswerFromOutputs() -> String {
        // Combine all terminal outputs
        let allOutputs = executionHistory.map { $0.output }.joined(separator: "\n")
        
        // Use universal analysis for any question
        return extractUniversalAnswer(from: allOutputs, for: currentTask)
    }
    
    private func generateConciseSummary(from collectedInfo: String, for task: String) async -> String {
        let prompt = """
        Ты - эксперт по анализу информации с глубокими знаниями Unix/Linux систем. Пользователь задал вопрос: "\(task)"
        
        Вот собранная информация из терминала:
        \(collectedInfo)
        
        Задача: Выбери самое важное из этой информации и представь это в виде краткой сводки, понятной для человека.
        
        Требования:
        1. Отвечай ТОЛЬКО на заданный вопрос
        2. Показывай только ключевую информацию
        3. Используй простой и понятный язык
        4. Форматируй ответ с использованием markdown (**жирный**, `код`)
        5. Если информация не отвечает на вопрос - скажи об этом
        6. Максимум 5-7 строк
        7. Будь точным и информативным
        8. Если есть числовые данные - выдели их
        
        Ответ:
        """
        
        do {
            // Use direct OpenAI API call instead of processUserRequest
            let request = OpenAIRequest(
                model: "gpt-4o",
                messages: [
                    Message(role: "system", content: "Ты - эксперт по анализу информации. Отвечай кратко и по делу."),
                    Message(role: "user", content: sanitizeForGPT(prompt, maxChars: 8000))
                ]
            )
            
            let response = try await callOpenAI(request)
            
            if let content = response.choices.first?.message.content {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            return ""
        } catch {
            LoggingService.shared.error("❌ Failed to generate concise summary: \(error.localizedDescription)", source: "GPTTerminalService")
            return ""
        }
    }
    
    private func extractUniversalAnswer(from output: String, for question: String) -> String {
        // Universal approach: let GPT analyze the output and question
        // This method is now completely generic and doesn't rely on specific keywords
        return extractKeyInformation(from: output)
    }
    
    private func extractCommandFromResponse(_ response: String) -> String {
        LoggingService.shared.info("🔍 Extracting command from response: \(response.prefix(200))...", source: "GPTTerminalService")
        
        // Look for commands in code blocks (```command```)
        let codeBlockPattern = "```(?:bash|shell)?\\s*([^`]+)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)) {
            let commandRange = match.range(at: 1)
            if let range = Range(commandRange, in: response) {
                let command = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                let cleaned = cleanCommand(command)
                LoggingService.shared.info("🔍 Found command in code block: '\(cleaned)'", source: "GPTTerminalService")
                return cleaned
            }
        }
        
        // Look for commands in backticks (`command`)
        let inlineCodePattern = "`([^`]+)`"
        if let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)) {
            let commandRange = match.range(at: 1)
            if let range = Range(commandRange, in: response) {
                let command = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                let cleaned = cleanCommand(command)
                LoggingService.shared.info("🔍 Found command in backticks: '\(cleaned)'", source: "GPTTerminalService")
                return cleaned
            }
        }
        
        // Look for commands in quotes ("command")
        let quotePattern = "\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: quotePattern, options: []),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)) {
            let commandRange = match.range(at: 1)
            if let range = Range(commandRange, in: response) {
                let command = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                let cleaned = cleanCommand(command)
                LoggingService.shared.info("🔍 Found command in quotes: '\(cleaned)'", source: "GPTTerminalService")
                return cleaned
            }
        }
        
        LoggingService.shared.warning("⚠️ No command found in response", source: "GPTTerminalService")
        return ""
    }
    
    private func cleanCommand(_ command: String) -> String {
        var cleaned = command
        
        // First, remove newlines and normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "\n", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove 'sh' prefix if present (after whitespace normalization)
        if cleaned.hasPrefix("sh ") {
            cleaned = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleaned.hasPrefix("sh") {
            cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Final cleanup
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        LoggingService.shared.info("🧹 Cleaned command: '\(command)' -> '\(cleaned)'", source: "GPTTerminalService")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func checkTaskCompletionWithGPT(originalTask: String, executionHistory: [ExecutionStep], responseContent: String) async -> Bool {
        // Create a comprehensive analysis prompt for GPT
        let analysisPrompt = """
        Analyze if the task has been completed successfully.
        
        ORIGINAL TASK: \(originalTask)
        
        EXECUTION CONTEXT:
        - Total steps executed: \(executionHistory.count)
        - Task type: Information gathering/System analysis
        
        EXECUTION HISTORY:
        \(executionHistory.map { step in
            """
            Step \(step.stepNumber):
            - Command: \(step.command)
            - Output length: \(step.output.count) characters
            - Output preview: \(String(step.output.prefix(300)))\(step.output.count > 300 ? "..." : "")
            - Contains useful data: \(step.output.count > 10 && !step.output.lowercased().contains("error") && !step.output.lowercased().contains("command not found") ? "YES" : "NO")
            """
        }.joined(separator: "\n\n"))
        
        GPT RESPONSE: \(responseContent)
        
        COMPLETION CRITERIA:
        1. The requested information has been successfully gathered from command outputs
        2. The command outputs contain the data that was asked for in the original task
        3. No further commands are needed to complete the task objective
        4. The task objective has been achieved
        5. At least 2 successful commands with useful output have been executed
        
        ANALYSIS INSTRUCTIONS:
        - Look for the specific information requested in the original task
        - Check if command outputs contain relevant data
        - Consider if more commands would provide additional value
        - Evaluate if the current information is sufficient to answer the user's question
        
        RESPOND WITH ONLY ONE WORD:
        - "COMPLETE" if the task is finished successfully
        - "INCOMPLETE" if more steps are needed
        
        Analysis:
        """
        
        do {
            let request = OpenAIRequest(
                model: "gpt-4o",
                messages: [
                    Message(role: "system", content: "You are a task completion analyzer. Analyze if a terminal task has been completed successfully based on the original request and command outputs. Respond with only 'COMPLETE' or 'INCOMPLETE'."),
                    Message(role: "user", content: sanitizeForGPT(analysisPrompt, maxChars: 8000))
                ]
            )
            
            let response = try await callOpenAI(request)
            
            if let content = response.choices.first?.message.content {
                let result = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isComplete = result == "complete" // Только точное совпадение
                
                LoggingService.shared.info("🤖 GPT Task Completion Analysis: '\(content)' -> \(isComplete)", source: "GPTTerminalService")
                
                return isComplete
            }
            
            return false
        } catch {
            LoggingService.shared.error("❌ Failed to check task completion with GPT: \(error.localizedDescription)", source: "GPTTerminalService")
            return false
        }
    }
    
    private func hasSuccessfulInformationGathering() -> Bool {
        // Check if we have collected meaningful information
        guard !executionHistory.isEmpty else { return false }
        
        // Get the last command output
        let lastOutput = executionHistory.last?.output ?? ""
        
        // Check if the output contains useful information (not just errors or empty)
        let hasUsefulOutput = !lastOutput.isEmpty && 
                             !lastOutput.lowercased().contains("error") &&
                             !lastOutput.lowercased().contains("command not found") &&
                             !lastOutput.lowercased().contains("permission denied") &&
                             !lastOutput.lowercased().contains("no such file") &&
                             lastOutput.count > 10 // At least some meaningful output
        
        // Check if we have at least 2 successful steps
        let successfulSteps = executionHistory.filter { step in
            let output = step.output.lowercased()
            return !output.contains("error") && 
                   !output.contains("command not found") && 
                   !output.contains("permission denied") &&
                   !output.isEmpty
        }.count
        
        LoggingService.shared.info("🔍 Information gathering analysis: hasUsefulOutput=\(hasUsefulOutput), successfulSteps=\(successfulSteps)", source: "GPTTerminalService")
        
        // Consider task complete if we have useful output and at least 2 successful steps
        return hasUsefulOutput && successfulSteps >= 2
    }
    
    private func extractKeyInformation(from output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        var keyInfo: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            // Skip very long lines (likely logs or verbose output)
            if trimmedLine.count > 200 { continue }
            
            // Skip lines that are clearly not relevant (errors, warnings, etc.)
            if trimmedLine.lowercased().contains("error") || 
               trimmedLine.lowercased().contains("warning") ||
               trimmedLine.lowercased().contains("debug") ||
               trimmedLine.hasPrefix("#") ||
               trimmedLine.hasPrefix("//") {
                continue
            }
            
            // Include all non-empty, relevant lines
            keyInfo.append("• `\(trimmedLine)`")
        }
        
        // Limit to most relevant information (first 15 items)
        let limitedInfo = Array(keyInfo.prefix(15))
        return limitedInfo.isEmpty ? "" : limitedInfo.joined(separator: "\n") + "\n\n"
    }
    

}

// MARK: - Errors
enum GPTError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case quotaExceeded
    case noResponse
    case invalidCommand(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .quotaExceeded:
            return "OpenAI API quota exceeded. Please check your billing or contact your administrator."
        case .noResponse:
            return "No response from GPT"
        case .invalidCommand(let message):
            return "Invalid command: \(message)"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .quotaExceeded:
            return "💳 OpenAI API quota exceeded\n\nPlease:\n• Check your billing status\n• Contact your administrator\n• Add funds to your account\n\nVisit: https://platform.openai.com/account/billing"
        case .apiError(let message):
            if message.contains("insufficient_quota") || message.contains("quota") {
                return "💳 OpenAI API quota exceeded\n\nPlease:\n• Check your billing status\n• Contact your administrator\n• Add funds to your account\n\nVisit: https://platform.openai.com/account/billing"
            }
            return "❌ API Error: \(message)"
        default:
            return errorDescription ?? "Unknown error"
        }
    }
}
