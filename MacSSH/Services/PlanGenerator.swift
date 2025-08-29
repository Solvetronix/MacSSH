import Foundation

@MainActor
class PlanGenerator: ObservableObject {
    @Published var isGenerating = false
    @Published var lastError: String?
    
    private let gptService: GPTTerminalService
    
    init(gptService: GPTTerminalService) {
        self.gptService = gptService
    }
    
    func generatePlan(from userRequest: String) async throws -> ExecutionPlan {
        LoggingService.shared.info("🎯 Generating execution plan for: \(userRequest)", source: "PlanGenerator")
        
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }
        
        do {
            let prompt = createPlanningPrompt(userRequest: userRequest)
            let response = try await gptService.callOpenAI(prompt: prompt, systemPrompt: systemPrompt)
            
            let plan = try parsePlanFromResponse(response)
            
            await MainActor.run {
                isGenerating = false
            }
            
            LoggingService.shared.info("✅ Plan generated successfully: \(plan.title)", source: "PlanGenerator")
            return plan
            
        } catch {
            await MainActor.run {
                isGenerating = false
                lastError = error.localizedDescription
            }
            
            LoggingService.shared.error("❌ Failed to generate plan: \(error.localizedDescription)", source: "PlanGenerator")
            throw error
        }
    }
    
    private func createPlanningPrompt(userRequest: String) -> String {
        return """
        Создай детальный план выполнения для следующей задачи:
        
        ЗАДАЧА: \(userRequest)
        
        Требования к плану:
        1. Разбей задачу на логические шаги
        2. Для каждого шага определи:
           - Четкое название и описание
           - Команду для выполнения
           - Критерии успеха (что должно произойти для успешного завершения)
           - Критерии неудачи (что указывает на ошибку)
           - Ожидаемый вывод (если применимо)
           - Таймаут в секундах
           - Необязательные pre-команды (например, создание каталогов), переменные окружения `env`
           - Альтернативы на случай неуспеха: `whenRegex`, `apply` (команды для подготовки), `replaceCommands`, `retry`
        
        3. Определи глобальные критерии успеха для всего плана
        4. Установи разумные ограничения по времени и повторным попыткам
        
        Верни результат в формате JSON согласно следующей схеме:
        {
          "title": "Название плана",
          "description": "Описание плана",
          "steps": [
            {
              "id": "уникальный_идентификатор",
              "title": "Название шага",
              "description": "Описание шага",
              "command": "команда для выполнения",
              "successCriteria": [
                {
                  "description": "Описание критерия успеха",
                  "type": "contains_text|not_contains_text|exit_code|file_exists|directory_exists|regex_match|output_empty|output_not_empty",
                  "value": "ожидаемое значение"
                }
              ],
              "failureCriteria": [
                {
                  "description": "Описание критерия неудачи",
                  "type": "contains_text|not_contains_text|exit_code|file_exists|directory_exists|regex_match|output_empty|output_not_empty",
                  "value": "значение указывающее на ошибку"
                }
              ],
              "expectedOutput": "ожидаемый вывод (опционально)",
              "timeoutSeconds": 30,
              "env": { "KEY": "VALUE" },
              "pre": ["mkdir -p /tmp/safe"],
              "checkpoint": false,
              "testInstructions": "Кратко опиши, как проверить этот шаг вручную без опасных действий",
              "testPrompts": [
                "Собери безопасный диагностический снимок",
                "Проверь недоступные команды и предложи аналоги",
                "Собери только чтение-метрики (df/top) без sudo"
              ],
              "alternatives": [
                {
                  "whenRegex": "No such file or directory",
                  "apply": ["mkdir -p /tmp/safe"],
                  "retry": true
                },
                {
                  "whenRegex": "command not found",
                  "replaceCommands": ["ss -lntp | head -n 20"],
                  "retry": false
                }
              ]
            }
          ],
          "globalSuccessCriteria": [
            {
              "description": "Глобальный критерий успеха",
              "type": "contains_text|not_contains_text|exit_code|file_exists|directory_exists|regex_match|output_empty|output_not_empty",
              "value": "ожидаемое значение"
            }
          ],
          "globalFailureCriteria": [
            {
              "description": "Глобальный критерий неудачи",
              "type": "contains_text|not_contains_text|exit_code|file_exists|directory_exists|regex_match|output_empty|output_not_empty",
              "value": "значение указывающее на ошибку"
            }
          ],
          "maxTotalTime": 300,
          "maxRetries": 3
        }
        
        Важно:
        - Используй только безопасные команды
        - Критерии должны быть конкретными и проверяемыми
        - Учитывай возможные ошибки и edge cases
        - План должен быть выполнимым и логичным
        """
    }
    
    private let systemPrompt = """
    Ты эксперт по планированию выполнения задач в терминале. Твоя задача - создавать детальные, безопасные и выполнимые планы.
    
    Правила:
    1. Всегда создавай планы с четкими критериями успеха и неудачи
    2. Используй только безопасные команды
    3. Учитывай возможные ошибки и edge cases
    4. Делай планы модульными и переиспользуемыми
    5. Всегда возвращай валидный JSON без дополнительного текста
    6. Критерии должны быть конкретными и проверяемыми
    7. Не используй опасные команды (rm -rf, shutdown, etc.)
    8. Устанавливай разумные таймауты для каждого шага
    """
    
    private func parsePlanFromResponse(_ response: String) throws -> ExecutionPlan {
        LoggingService.shared.debug("🔍 Parsing plan from response", source: "PlanGenerator")
        
        // Extract JSON from response (handle markdown code blocks)
        let jsonString = extractJSONFromResponse(response)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw PlanGenerationError.invalidJSON("Failed to convert response to data")
        }
        
        do {
            let decoder = JSONDecoder()
            let plan = try decoder.decode(ExecutionPlan.self, from: data)
            
            // Validate plan
            try validatePlan(plan)
            
            return plan
            
        } catch {
            LoggingService.shared.error("❌ JSON parsing failed: \(error.localizedDescription)", source: "PlanGenerator")
            throw PlanGenerationError.parsingFailed(error.localizedDescription)
        }
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        // Try to extract JSON from markdown code blocks first
        let codeBlockPattern = "```(?:json)?\\s*([\\s\\S]*?)\\s*```"
        
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)) {
            let jsonRange = match.range(at: 1)
            if let range = Range(jsonRange, in: response) {
                return String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If no code block found, try to find JSON in the response
        let jsonPattern = "\\{[\\s\\S]*\\}"
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)) {
            let jsonRange = match.range
            if let range = Range(jsonRange, in: response) {
                return String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If all else fails, return the original response
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func validatePlan(_ plan: ExecutionPlan) throws {
        // Validate basic structure
        guard !plan.title.isEmpty else {
            throw PlanGenerationError.validationFailed("Plan title cannot be empty")
        }
        
        guard !plan.steps.isEmpty else {
            throw PlanGenerationError.validationFailed("Plan must have at least one step")
        }
        
        // Validate steps
        for (index, step) in plan.steps.enumerated() {
            guard !step.id.isEmpty else {
                throw PlanGenerationError.validationFailed("Step \(index + 1) must have an ID")
            }
            
            guard !step.command.isEmpty else {
                throw PlanGenerationError.validationFailed("Step \(index + 1) must have a command")
            }
            
            // Validate command safety
            if isDangerousCommand(step.command) {
                throw PlanGenerationError.validationFailed("Step \(index + 1) contains dangerous command: \(step.command)")
            }
        }
        
        // Validate timeouts
        guard plan.maxTotalTime > 0 else {
            throw PlanGenerationError.validationFailed("Max total time must be positive")
        }
        
        guard plan.maxRetries >= 0 else {
            throw PlanGenerationError.validationFailed("Max retries cannot be negative")
        }
    }
    
    private func isDangerousCommand(_ command: String) -> Bool {
        let dangerousCommands = [
            "rm -rf", "rm -rf /", "rm -rf /*",
            "shutdown", "halt", "reboot",
            "dd if=", "dd of=",
            "mkfs", "fdisk",
            "chmod 777", "chmod -R 777",
            "sudo rm", "sudo shutdown", "sudo reboot"
        ]
        
        let lowercasedCommand = command.lowercased()
        return dangerousCommands.contains { lowercasedCommand.contains($0.lowercased()) }
    }
}

// MARK: - Errors

enum PlanGenerationError: Error, LocalizedError {
    case invalidJSON(String)
    case parsingFailed(String)
    case validationFailed(String)
    case gptError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .parsingFailed(let message):
            return "Failed to parse plan: \(message)"
        case .validationFailed(let message):
            return "Plan validation failed: \(message)"
        case .gptError(let message):
            return "GPT error: \(message)"
        }
    }
}

// MARK: - Example Plans

extension PlanGenerator {
    static func createExamplePlan() -> ExecutionPlan {
        return ExecutionPlan(
            title: "Feature branch + commit + push",
            description: "Example plan for creating a new feature branch, committing changes, and pushing to remote.",
            steps: [
                PlanStep(
                    id: "branch-create",
                    title: "Create new feature branch",
                    description: "Check out a new branch from the current branch.",
                    command: "git checkout -b feat/improve-logging",
                    successCriteria: [
                        SuccessCriterion(description: "Branch created successfully", type: .containsText, value: "feat/improve-logging")
                    ],
                    failureCriteria: [
                        FailureCriterion(description: "Branch creation failed", type: .exitCode, value: "1")
                    ],
                    expectedOutput: "Switched to a new branch 'feat/improve-logging'",
                    timeoutSeconds: 10
                ),
                PlanStep(
                    id: "edit-file",
                    title: "Edit file to add logging",
                    description: "Add a line to the src/server.ts file to enable structured logging.",
                    command: "echo '// TODO: structured logging' >> src/server.ts",
                    successCriteria: [
                        SuccessCriterion(description: "File content updated", type: .containsText, value: "structured logging")
                    ],
                    failureCriteria: [
                        FailureCriterion(description: "File update failed", type: .exitCode, value: "1")
                    ],
                    expectedOutput: "echo '// TODO: structured logging' >> src/server.ts",
                    timeoutSeconds: 10
                ),
                PlanStep(
                    id: "lint-test",
                    title: "Run lint and tests",
                    description: "Run the lint and test commands to ensure code quality.",
                    command: "npm run -s lint && npm -s test",
                    successCriteria: [
                        SuccessCriterion(description: "Lint and tests completed successfully", type: .exitCode, value: "0")
                    ],
                    failureCriteria: [
                        FailureCriterion(description: "Lint or test failed", type: .exitCode, value: "1")
                    ],
                    expectedOutput: "npm run -s lint && npm -s test",
                    timeoutSeconds: 30
                ),
                PlanStep(
                    id: "commit",
                    title: "Commit changes",
                    description: "Add all changes and create a commit with a descriptive message.",
                    command: "git add -A && git commit -m 'feat(logging): structured request/response logging'",
                    successCriteria: [
                        SuccessCriterion(description: "Commit successful", type: .containsText, value: "feat(logging):")
                    ],
                    failureCriteria: [
                        FailureCriterion(description: "Commit failed", type: .exitCode, value: "1")
                    ],
                    expectedOutput: "git add -A && git commit -m 'feat(logging): structured request/response logging'",
                    timeoutSeconds: 15
                ),
                PlanStep(
                    id: "push",
                    title: "Push changes to remote",
                    description: "Push the new branch to the remote repository.",
                    command: "git push -u origin feat/improve-logging",
                    successCriteria: [
                        SuccessCriterion(description: "Push successful", type: .containsText, value: "feat/improve-logging")
                    ],
                    failureCriteria: [
                        FailureCriterion(description: "Push failed", type: .exitCode, value: "1")
                    ],
                    expectedOutput: "git push -u origin feat/improve-logging",
                    timeoutSeconds: 15
                )
            ],
            globalSuccessCriteria: [
                SuccessCriterion(description: "All steps completed successfully", type: .exitCode, value: "0")
            ],
            globalFailureCriteria: [
                FailureCriterion(description: "Any step failed", type: .exitCode, value: "1")
            ],
            maxTotalTime: 180,
            maxRetries: 3
        )
    }
}
