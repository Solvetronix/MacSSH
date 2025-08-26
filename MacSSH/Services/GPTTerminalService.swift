import Foundation

// MARK: - OpenAI API Models
struct OpenAIRequest: Codable {
    let model: String
    let messages: [Message]
    let tools: [Tool]?
    let tool_choice: String?
    
    init(model: String = "gpt-3.5-turbo", messages: [Message], tools: [Tool]? = nil, tool_choice: String? = nil) {
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

// MARK: - GPT Terminal Service
class GPTTerminalService: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private let apiKey: String
    private let terminalService: SwiftTermProfessionalService
    
    // Universal terminal tool definition
    private let terminalTool = Tool(
        type: "function",
        function: FunctionDefinition(
            name: "execute_terminal_command",
            description: "Execute any shell command in the connected SSH terminal. Use this for file operations, system commands, navigation, process management, and any other terminal operations.",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "command": PropertyDefinition(
                        type: "string",
                        description: "Shell command to execute (can be any valid shell command like ls, cd, cat, grep, find, ps, etc.)"
                    )
                ],
                required: ["command"]
            )
        )
    )
    
    init(apiKey: String, terminalService: SwiftTermProfessionalService) {
        self.apiKey = apiKey
        self.terminalService = terminalService
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
    
    // MARK: - Request creation
    private func createRequest(userRequest: String) -> OpenAIRequest {
        let systemMessage = Message(
            role: "system",
            content: """
            You are a helpful terminal assistant. When users ask for terminal operations, use the execute_terminal_command tool to perform the requested action.
            
            Guidelines:
            - Always use the execute_terminal_command tool for terminal operations
            - Generate appropriate shell commands based on user requests
            - Be helpful and provide useful commands
            - Consider the context and current working directory
            """
        )
        
        let userMessage = Message(role: "user", content: userRequest)
        
        return OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: [systemMessage, userMessage],
            tools: [terminalTool],
            tool_choice: "auto"
        )
    }
    
    // MARK: - OpenAI API call
    private func callOpenAI(_ request: OpenAIRequest) async throws -> OpenAIResponse {
        LoggingService.shared.debug("🌐 Preparing OpenAI API call", source: "GPTTerminalService")
        
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
        
        // Debug: Log the request body
        if let requestString = String(data: requestData, encoding: .utf8) {
            LoggingService.shared.debug("📤 Request body: \(requestString)", source: "GPTTerminalService")
        }
        
        LoggingService.shared.debug("📤 Sending request to OpenAI API", source: "GPTTerminalService")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            LoggingService.shared.error("❌ Invalid HTTP response from OpenAI", source: "GPTTerminalService")
            throw GPTError.apiError("Invalid HTTP response")
        }
        
        LoggingService.shared.debug("📥 Received response from OpenAI: HTTP \(httpResponse.statusCode)", source: "GPTTerminalService")
        
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
        LoggingService.shared.debug("✅ Successfully decoded OpenAI response", source: "GPTTerminalService")
        
        return openAIResponse
    }
    
    // MARK: - Response handling
    private func handleResponse(_ response: OpenAIResponse) async throws -> String? {
        LoggingService.shared.debug("🔍 Handling OpenAI response", source: "GPTTerminalService")
        
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
        LoggingService.shared.debug("🔧 Processing \(toolCalls.count) tool calls", source: "GPTTerminalService")
        
        var results: [String] = []
        
        for (index, toolCall) in toolCalls.enumerated() {
            LoggingService.shared.debug("🔧 Tool call \(index + 1): \(toolCall.function.name)", source: "GPTTerminalService")
            
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
        LoggingService.shared.debug("🔍 Parsing command arguments: '\(arguments)'", source: "GPTTerminalService")
        
        // Parse command from JSON arguments
        guard let command = parseCommand(arguments) else {
            LoggingService.shared.error("❌ Failed to parse command from arguments: '\(arguments)'", source: "GPTTerminalService")
            throw GPTError.invalidCommand("Failed to parse command from: \(arguments)")
        }
        
        LoggingService.shared.info("📝 Parsed command: '\(command)'", source: "GPTTerminalService")
        
        // Validate command security
        guard isValidCommand(command) else {
            let error = "⚠️ Command blocked for security: \(command)"
            LoggingService.shared.warning("🚫 Security validation failed: '\(command)'", source: "GPTTerminalService")
            return error
        }
        
        LoggingService.shared.info("✅ Command passed security validation", source: "GPTTerminalService")
        
        // Execute command through existing terminal service
        LoggingService.shared.info("🚀 Sending command to terminal: '\(command)'", source: "GPTTerminalService")
        await MainActor.run {
            terminalService.sendCommand(command)
        }
        
        LoggingService.shared.success("✅ GPT executed command successfully: '\(command)'", source: "GPTTerminalService")
        return "✅ Command executed: \(command)"
    }
    
    // MARK: - Command parsing
    private func parseCommand(_ arguments: String) -> String? {
        LoggingService.shared.debug("🔍 Parsing JSON arguments: '\(arguments)'", source: "GPTTerminalService")
        
        guard let data = arguments.data(using: .utf8) else {
            LoggingService.shared.error("❌ Failed to convert arguments to data: '\(arguments)'", source: "GPTTerminalService")
            return nil
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            LoggingService.shared.error("❌ Failed to parse JSON from arguments: '\(arguments)'", source: "GPTTerminalService")
            return nil
        }
        
        guard let command = json["command"] as? String else {
            LoggingService.shared.error("❌ No 'command' field in JSON: \(json)", source: "GPTTerminalService")
            return nil
        }
        
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        LoggingService.shared.debug("✅ Successfully parsed command: '\(trimmedCommand)'", source: "GPTTerminalService")
        
        return trimmedCommand
    }
    
    // MARK: - Command validation
    private func isValidCommand(_ command: String) -> Bool {
        LoggingService.shared.debug("🔒 Validating command security: '\(command)'", source: "GPTTerminalService")
        
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
            ">\\s*/dev/",          // Write to device files
            "\\|\\s*tee\\s+/dev/"  // Write to device files
        ]
        
        for pattern in dangerousPatterns {
            if command.range(of: pattern, options: .regularExpression) != nil {
                LoggingService.shared.warning("🚫 Dangerous command pattern detected: '\(pattern)' in command: '\(command)'", source: "GPTTerminalService")
                return false
            }
        }
        
        LoggingService.shared.debug("✅ Command passed security validation", source: "GPTTerminalService")
        return true
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
