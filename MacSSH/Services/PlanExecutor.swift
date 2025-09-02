import Foundation
import SwiftUI

@MainActor
class PlanExecutor: ObservableObject {
    @Published var currentStatus: ExecutionStatus = .planning
    @Published var currentPlan: ExecutionPlan?
    @Published var stepResults: [StepExecutionResult] = []
    @Published var isExecuting = false
    @Published var lastError: String?
    @Published var progress: Double = 0.0
    
    private let terminalService: SwiftTermProfessionalService
    private let gptService: GPTTerminalService
    private let reliableCompletion: ReliableCommandCompletion
    private let enhancedRecoveryService: EnhancedRecoveryService
    // Safety & pauses
    private var yoloEnabled: Bool = false
    private var dangerContinuation: CheckedContinuation<Void, Never>?
    private var checkpointContinuation: CheckedContinuation<Void, Never>?
    
    init(terminalService: SwiftTermProfessionalService, gptService: GPTTerminalService) {
        self.terminalService = terminalService
        self.gptService = gptService
        self.reliableCompletion = ReliableCommandCompletion(terminalService: terminalService)
        self.enhancedRecoveryService = EnhancedRecoveryService(terminalService: terminalService, gptService: gptService)
        self.yoloEnabled = UserDefaults.standard.bool(forKey: "YOLOEnabled")
        // Stop ongoing execution if terminal session is closing
        NotificationCenter.default.addObserver(forName: .terminalSessionWillClose, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isExecuting = false
            }
        }
    }
    
    // MARK: - Plan Execution
    
    func executePlan(_ plan: ExecutionPlan) async -> PlanExecutionResult {
        LoggingService.shared.info("🚀 Starting plan execution: \(plan.title)", source: "PlanExecutor")
        
        await MainActor.run {
            self.currentPlan = plan
            self.currentStatus = .planning
            self.isExecuting = true
            self.stepResults = []
            self.lastError = nil
            self.progress = 0.0
        }
        
        let startTime = Date()
        var results: [StepExecutionResult] = []
        
        do {
            // PLAN phase indicator in chat/logs
            LoggingService.shared.info("🧠 Planning steps...", source: "PlanExecutor")
            await MainActor.run {
                // Emit chat-like status via LoggingService; UI can subscribe and render
                LoggingService.shared.info("[Chat] Планирование...", source: "PlanExecutor")
                self.gptService.addAssistantMessage("Планирование...")
            }
            
            // Switch to EXECUTION phase
            await MainActor.run { self.currentStatus = .executing }
            
            // Apply plan-level pre and env once before steps
            if let planPre = plan.planPre {
                for cmd in planPre { _ = await executeCommand(cmd, timeoutSeconds: 15) }
            }
            var planEnvExports = ""
            if let planEnv = plan.planEnv, !planEnv.isEmpty {
                planEnvExports = planEnv.map { k, v in
                    let esc = v.replacingOccurrences(of: "\"", with: "\\\"")
                    return "export \(k)=\"\(esc)\""
                }.joined(separator: "; ")
            }
            if !planEnvExports.isEmpty {
                _ = await executeCommand(planEnvExports, timeoutSeconds: 10)
            }

            // Execute each step (PEOV cycle)
            for (index, step) in plan.steps.enumerated() {
                await MainActor.run {
                    self.progress = Double(index) / Double(plan.steps.count)
                }
                
                LoggingService.shared.info("⚡ Executing step \(index + 1)/\(plan.steps.count): \(step.title)", source: "PlanExecutor")
                
                // OBSERVE: emit chat-like status
                LoggingService.shared.info("[Chat] Выполнение...", source: "PlanExecutor")
                await MainActor.run {
                    self.gptService.addAssistantMessage("Выполнение шага \(index + 1)/\(plan.steps.count): \(step.title)")
                }
                
                let stepResult = await executeStepWithAdaptation(step, retryCount: 0, maxRetries: plan.maxRetries)
                results.append(stepResult)
                
                await MainActor.run {
                    self.stepResults.append(stepResult)
                }

                // Optional testing checkpoint: pause for user testing before proceeding
                if step.checkpoint == true {
                    let instructions = step.testInstructions ?? "Промежуточное тестирование. Проверьте результат шага безопасно."
                    let prompts = (step.testPrompts ?? []).joined(separator: "\n- ")
                    let text = prompts.isEmpty ? instructions : instructions + "\n\nПредложенные тексты для тестирования:\n- " + prompts
                    await MainActor.run {
                        self.gptService.addAssistantMessage("⏸️ Чекпоинт: " + text)
                    }
                    // Wait for explicit user confirmation to proceed
                    LoggingService.shared.info("⏸️ Waiting for checkpoint confirmation...", source: "PlanExecutor")
                    await waitForCheckpoint()
                }

                // Build verification after each step
                await MainActor.run {
                    self.gptService.addAssistantMessage("🔧 Проверка сборки...")
                }
                let buildCommand = "xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release -quiet build"
                let buildResult = await executeCommand(buildCommand, timeoutSeconds: max(60, step.timeoutSeconds))
                if buildResult.ok {
                    LoggingService.shared.success("✅ Build succeeded after step \(index + 1)", source: "PlanExecutor")
                    await MainActor.run { self.gptService.addAssistantMessage("✅ Сборка успешна") }
                } else {
                    LoggingService.shared.error("❌ Build failed after step \(index + 1)", source: "PlanExecutor")
                    await MainActor.run { self.gptService.addAssistantMessage("❌ Сборка неуспешна") }
                    // Finalize early with failure
                    await MainActor.run {
                        self.currentStatus = .failed
                        self.isExecuting = false
                        self.lastError = "Build failed after step \(index + 1)"
                    }
                    let totalDuration = Date().timeIntervalSince(startTime)
                    return PlanExecutionResult(
                        planId: plan.id,
                        status: .failed,
                        startTime: startTime,
                        endTime: Date(),
                        totalDuration: totalDuration,
                        stepResults: results,
                        globalSuccessResults: [],
                        globalFailureResults: [],
                        finalMessage: "Сборка неуспешна после шага \(index + 1)",
                        error: "Build failed"
                    )
                }
                
                // No manual retry loop here; adaptation is handled inside executeStepWithAdaptation
                
                // Check timeout
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > TimeInterval(plan.maxTotalTime) {
                    throw ExecutionError.timeoutExceeded(plan.maxTotalTime)
                }
            }
            
            // Move to observation phase
            await MainActor.run {
                self.currentStatus = .observing
            }
            LoggingService.shared.info("[Chat] Проверка...", source: "PlanExecutor")
            await MainActor.run {
                self.gptService.addAssistantMessage("Проверка…")
                self.gptService.addAssistantMessage("Суммаризация…")
            }
            
            // Evaluate global criteria
            let globalSuccessResults = await evaluateGlobalCriteria(plan.globalSuccessCriteria, results)
            let globalFailureResults = await evaluateGlobalCriteria(plan.globalFailureCriteria, results)
            
            // Determine final status
            let finalStatus: ExecutionStatus
            let finalMessage: String
            let error: String?
            
            if globalFailureResults.contains(where: { $0.passed }) {
                finalStatus = .failed
                finalMessage = "План выполнен с ошибками. Глобальные критерии неудачи были выполнены."
                error = "Global failure criteria met"
            } else if globalSuccessResults.allSatisfy({ $0.passed }) {
                finalStatus = .completed
                finalMessage = "План успешно выполнен! Все критерии успеха выполнены."
                error = nil
            } else {
                finalStatus = .failed
                finalMessage = "План не выполнен. Не все глобальные критерии успеха выполнены."
                error = "Global success criteria not met"
            }
            
            await MainActor.run {
                self.currentStatus = finalStatus
                self.isExecuting = false
                self.progress = 1.0
                self.lastError = error
            }
            await MainActor.run {
                let msg = (finalStatus == .completed) ? "Завершено успешно ✅" : "Завершено с ошибками ❌"
                self.gptService.addAssistantMessage(msg)
            }
            
            let totalDuration = Date().timeIntervalSince(startTime)
            return PlanExecutionResult(
                planId: plan.id,
                status: finalStatus,
                startTime: startTime,
                endTime: Date(),
                totalDuration: totalDuration,
                stepResults: results,
                globalSuccessResults: globalSuccessResults,
                globalFailureResults: globalFailureResults,
                finalMessage: finalMessage,
                error: error
            )
            
        } catch {
            await MainActor.run {
                self.currentStatus = .failed
                self.isExecuting = false
                self.lastError = error.localizedDescription
            }
            
            let totalDuration = Date().timeIntervalSince(startTime)
            return PlanExecutionResult(
                planId: plan.id,
                status: .failed,
                startTime: startTime,
                endTime: Date(),
                totalDuration: totalDuration,
                stepResults: results,
                globalSuccessResults: [],
                globalFailureResults: [],
                finalMessage: "План выполнен с ошибкой: \(error.localizedDescription)",
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - Step Execution
    
    private func executeStepWithAdaptation(_ step: PlanStep, retryCount: Int, maxRetries: Int) async -> StepExecutionResult {
        // PRE: apply env exports and pre-commands if any
        if let pre = step.pre, !pre.isEmpty {
            for cmd in pre { _ = await executeCommand(cmd, timeoutSeconds: 10) }
        }
        // Execute original step
        var result = await executeStep(step, retryCount: retryCount, maxRetries: maxRetries)
        if result.isSuccess { return result }
        
        // If failed and auto-recovery is enabled, try enhanced recovery
        if step.enableAutoRecovery ?? true {
            if let recoveryResult = await enhancedRecoveryService.recoverFromFailure(step, failedResult: result) {
                if recoveryResult.isSuccess {
                    return recoveryResult
                }
            }
        }
        
        // If enhanced recovery failed, try original alternatives based on observed output
        await MainActor.run {
            self.gptService.addAssistantMessage("Адаптация…")
        }
        let combinedOutput = result.output.lowercased() + "\n" + (result.error ?? "").lowercased()
        if let alternatives = step.alternatives, !alternatives.isEmpty {
            for alt in alternatives {
                // Match by regex if provided
                if let pattern = alt.whenRegex, !pattern.isEmpty {
                    if !matchesRegex(pattern: pattern, text: combinedOutput) { continue }
                }
                // Apply preparatory commands
                var appliedType: String? = nil
                let matchedRegex: String? = alt.whenRegex
                if let applyCmds = alt.apply { for cmd in applyCmds { _ = await executeCommand(cmd, timeoutSeconds: 10) }; appliedType = "apply" }
                // Replace command(s) if provided
                if let replace = alt.replaceCommands, !replace.isEmpty {
                    // Execute replacement pipeline as one joined command with '&&'
                    let replacedCommand = replace.joined(separator: " && ")
                    let replacedStep = PlanStep(
                        id: step.id + "-alt",
                        title: step.title + " (alternative)",
                        description: step.description,
                        command: replacedCommand,
                        successCriteria: step.successCriteria,
                        failureCriteria: step.failureCriteria,
                        expectedOutput: step.expectedOutput,
                        timeoutSeconds: step.timeoutSeconds,
                        env: step.env,
                        pre: nil,
                        alternatives: nil,
                        enhancedAlternatives: nil
                    )
                    await MainActor.run {
                        self.gptService.addAssistantMessage("Ретрай \(retryCount + 1)/\(maxRetries)")
                    }
                    result = await executeStep(replacedStep, retryCount: retryCount + 1, maxRetries: maxRetries)
                    // annotate
                    result = annotateAlternative(result: result, matchedRegex: matchedRegex, appliedType: "replace")
                    if result.isSuccess { return result }
                } else if alt.retry == true {
                    // Retry original command after apply
                    await MainActor.run {
                        self.gptService.addAssistantMessage("Ретрай \(retryCount + 1)/\(maxRetries)")
                    }
                    result = await executeStep(step, retryCount: retryCount + 1, maxRetries: maxRetries)
                    result = annotateAlternative(result: result, matchedRegex: matchedRegex, appliedType: appliedType ?? "retry")
                    if result.isSuccess { return result }
                }
            }
        }
        
        // Fallback retries up to maxRetries
        if retryCount < maxRetries {
            await MainActor.run {
                self.gptService.addAssistantMessage("Ретрай \(retryCount + 1)/\(maxRetries)")
            }
            let retried = await executeStepWithAdaptation(step, retryCount: retryCount + 1, maxRetries: maxRetries)
            return retried
        }
        
        return result
    }

    private func annotateAlternative(result: StepExecutionResult, matchedRegex: String?, appliedType: String?) -> StepExecutionResult {
        return StepExecutionResult(
            stepId: result.stepId,
            status: result.status,
            command: result.command,
            output: result.output,
            error: result.error,
            exitCode: result.exitCode,
            rawStdout: result.rawStdout,
            rawStderr: result.rawStderr,
            startTime: result.startTime,
            endTime: result.endTime,
            duration: result.duration,
            successCriteriaResults: result.successCriteriaResults,
            failureCriteriaResults: result.failureCriteriaResults,
            retryCount: result.retryCount,
            notes: result.notes,
            matchedAlternativeRegex: matchedRegex,
            appliedAlternativeType: appliedType ?? "none",
            recoveryAttempts: [],
            autoRecoveryEnabled: true,
            finalRecoveryStrategy: nil
        )
    }

    private func executeStep(_ step: PlanStep, retryCount: Int, maxRetries: Int) async -> StepExecutionResult {
        LoggingService.shared.info("🔧 Executing step: \(step.title) (retry \(retryCount)/\(maxRetries))", source: "PlanExecutor")
        
        let startTime = Date()
        
        // Execute command
        let commandToRun: String
        if let env = step.env, !env.isEmpty {
            let exports = env.map { key, value in
                let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
                return "export \(key)=\"\(escaped)\""
            }.joined(separator: "; ")
            commandToRun = "\(exports); \(step.command)"
        } else {
            commandToRun = step.command
        }
        let commandResult = await executeCommand(commandToRun, timeoutSeconds: step.timeoutSeconds)
        
        // Use stdout from command result as step output
        let output = commandResult.stdout
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Evaluate success criteria
        let successResults = await evaluateCriteria(step.successCriteria, output: output, commandResult: commandResult)
        let failureResults = await evaluateCriteria(step.failureCriteria, output: output, commandResult: commandResult)
        
        // Determine step status
        let status: StepStatus
        let error: String?
        
        if failureResults.contains(where: { $0.passed }) {
            status = .failed
            error = "Failure criteria met: \(failureResults.first(where: { $0.passed })?.description ?? "Unknown")"
        } else if successResults.allSatisfy({ $0.passed }) {
            status = .success
            error = nil
        } else {
            status = .failed
            error = "Success criteria not met: \(successResults.first(where: { !$0.passed })?.description ?? "Unknown")"
        }
        
        return StepExecutionResult(
            stepId: step.id,
            status: status,
            command: step.command,
            output: output,
            error: error,
            exitCode: commandResult.exitCode,
            rawStdout: commandResult.stdout,
            rawStderr: commandResult.stderr,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            successCriteriaResults: successResults,
            failureCriteriaResults: failureResults,
            retryCount: retryCount,
            notes: status == .failed ? "Applied PEOV evaluation. Consider alternatives if provided." : nil,
            matchedAlternativeRegex: nil,
            appliedAlternativeType: "none",
            recoveryAttempts: [],
            autoRecoveryEnabled: step.enableAutoRecovery ?? true,
            finalRecoveryStrategy: nil
        )
    }
    
    private func executeCommand(_ command: String, timeoutSeconds: Int) async -> (ok: Bool, exitCode: Int, stdout: String, stderr: String) {
        LoggingService.shared.debug("🔧 Executing command: \(command)", source: "PlanExecutor")

        // Safety: require confirmation for dangerous commands unless YOLO is enabled
        if isDangerousCommand(command) && !yoloEnabled {
            await MainActor.run {
                self.gptService.addAssistantMessage("⚠️ Обнаружена потенциально опасная команда. Ожидаю подтверждение для выполнения:")
                self.gptService.addAssistantMessage("`\(command)`")
            }
            LoggingService.shared.warning("⚠️ Dangerous command detected, waiting for confirmation", source: "PlanExecutor")
            await waitForDangerConfirmation()
        }
        
        // Save current output state
        let outputBeforeCommand = await terminalService.getCurrentOutput() ?? ""
        
        // Wait for terminal to stabilize
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Execute command
        // Wrap command to emit explicit exit code marker
        let wrapped = "\(command); printf \"[[MACSSH_EXIT=%d]]\\n\" $?"
        await MainActor.run { terminalService.sendCommand(wrapped) }
        
        // Wait for completion using reliable monitor
        _ = await reliableCompletion.waitForCommandCompletion(command: wrapped)
        
        // Additional safety delay to ensure terminal is fully ready
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Extract new output with final verification
        let currentOutput = await terminalService.getCurrentOutput() ?? ""
        let newOutput = String(currentOutput.dropFirst(outputBeforeCommand.count))
        
        // Parse explicit exit code marker [[MACSSH_EXIT=N]]
        var exitCode = -1
        var cleanedOutput = newOutput
        if let range = newOutput.range(of: #"\[\[MACSSH_EXIT=(\d+)\]\]"#, options: .regularExpression) {
            let match = String(newOutput[range])
            if let numRange = match.range(of: #"\d+"#, options: .regularExpression) {
                exitCode = Int(match[numRange]) ?? -1
            }
            // Remove the marker line from stdout
            cleanedOutput.removeSubrange(range)
        }
        // Fallback if marker not found: heuristic
        if exitCode == -1 {
            let lower = newOutput.lowercased()
            let hasNegative = lower.contains("error") || lower.contains("command not found") || lower.contains("no such file") || lower.contains("permission denied")
            exitCode = hasNegative ? 1 : 0
        }
        let ok = (exitCode == 0)
        
        return (ok: ok, exitCode: exitCode, stdout: cleanedOutput.trimmingCharacters(in: .whitespacesAndNewlines), stderr: "")
    }

    // MARK: - Safety helpers
    private func isDangerousCommand(_ command: String) -> Bool {
        let patterns = [
            #"\brm\s+-rf\b"#,
            #"\bsudo\b"#,
            #"\bmkfs\b|\bfdisk\b"#,
            #"\bshutdown\b|\breboot\b|\bhalt\b"#,
            #"\bchmod\s+-R\s+777\b"#
        ]
        return patterns.contains { command.range(of: $0, options: .regularExpression) != nil }
    }
    
    private func waitForDangerConfirmation() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.dangerContinuation = continuation
        }
    }
    
    private func waitForCheckpoint() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.checkpointContinuation = continuation
        }
    }
    
    // External triggers from UI
    func confirmDanger() {
        dangerContinuation?.resume()
        dangerContinuation = nil
    }
    func confirmCheckpoint() {
        checkpointContinuation?.resume()
        checkpointContinuation = nil
    }
    
    private func waitForCommandCompletion(command: String, timeoutSeconds: Int) async -> String {
        let pollInterval: TimeInterval = 0.3 // Faster polling
        
        var lastOutputLength = 0
        var stableOutputCount = 0
        let requiredStableChecks = 5 // More reliable
        var lastOutput = ""
        var consecutivePromptChecks = 0
        let requiredPromptChecks = 3
        var noOutputTime: TimeInterval = 0
        let maxNoOutputTime: TimeInterval = 10.0 // Maximum time without any output changes
        
        while true {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            
            let currentOutput = await terminalService.getCurrentOutput() ?? ""
            
            // Check for command prompt indicators (most reliable)
            let hasPrompt = currentOutput.contains("$ ") || currentOutput.contains("# ") || currentOutput.contains("> ") || 
                           currentOutput.contains("bash$") || currentOutput.contains("zsh$") || currentOutput.contains("sh$") ||
                           currentOutput.contains("rise@") || currentOutput.contains("user@")
            
            if hasPrompt {
                consecutivePromptChecks += 1
                if consecutivePromptChecks >= requiredPromptChecks {
                    LoggingService.shared.info("✅ Command completed (prompt confirmed): '\(command)'", source: "PlanExecutor")
                    return currentOutput
                }
            } else {
                consecutivePromptChecks = 0
            }
            
            // Check if output has stabilized
            if currentOutput.count == lastOutputLength && currentOutput == lastOutput {
                stableOutputCount += 1
                noOutputTime += pollInterval
                if stableOutputCount >= requiredStableChecks {
                    // Additional final check
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    let finalCheck = await terminalService.getCurrentOutput() ?? ""
                    if finalCheck.count == currentOutput.count {
                        LoggingService.shared.info("✅ Command completed (output stabilized): '\(command)'", source: "PlanExecutor")
                        return currentOutput
                    } else {
                        // Output changed during final check, reset counters
                        stableOutputCount = 0
                        lastOutputLength = finalCheck.count
                        lastOutput = finalCheck
                        noOutputTime = 0
                    }
                }
            } else {
                stableOutputCount = 0
                lastOutputLength = currentOutput.count
                lastOutput = currentOutput
                noOutputTime = 0
            }
            
            // Check for specific command completion patterns
            if isCommandSpecificCompletion(command: command, output: currentOutput) {
                LoggingService.shared.info("✅ Command completed (specific pattern): '\(command)'", source: "PlanExecutor")
                return currentOutput
            }
            
            // Safety check: if no output changes for too long, consider command stuck
            if noOutputTime > maxNoOutputTime {
                LoggingService.shared.warning("⚠️ Command appears stuck (no output for \(maxNoOutputTime)s): '\(command)'", source: "PlanExecutor")
                return currentOutput
            }
        }
    }
    
    // Helper method to check for command-specific completion patterns
    private func isCommandSpecificCompletion(command: String, output: String) -> Bool {
        let cmd = command.lowercased()
        let out = output.lowercased()
        
        // Check for specific command completion patterns
        if cmd.contains("find") && (out.contains("no such file") || out.contains("0 files") || out.contains("total")) {
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
    
    // MARK: - Criteria Evaluation
    
    private func evaluateCriteria(_ criteria: [SuccessCriterion], output: String, commandResult: (ok: Bool, exitCode: Int, stdout: String, stderr: String)) async -> [CriterionResult] {
        var results: [CriterionResult] = []
        
        for criterion in criteria {
            let result = await evaluateCriterion(criterion, output: output, commandResult: commandResult)
            results.append(result)
        }
        
        return results
    }
    
    private func evaluateCriteria(_ criteria: [FailureCriterion], output: String, commandResult: (ok: Bool, exitCode: Int, stdout: String, stderr: String)) async -> [CriterionResult] {
        var results: [CriterionResult] = []
        
        for criterion in criteria {
            let result = await evaluateCriterion(criterion, output: output, commandResult: commandResult)
            results.append(result)
        }
        
        return results
    }
    
    private func evaluateCriterion(_ criterion: SuccessCriterion, output: String, commandResult: (ok: Bool, exitCode: Int, stdout: String, stderr: String)) async -> CriterionResult {
        return await evaluateCriterionInternal(criterion.description, type: criterion.type, expectedValue: criterion.value, output: output, commandResult: commandResult)
    }
    
    private func evaluateCriterion(_ criterion: FailureCriterion, output: String, commandResult: (ok: Bool, exitCode: Int, stdout: String, stderr: String)) async -> CriterionResult {
        return await evaluateCriterionInternal(criterion.description, type: criterion.type, expectedValue: criterion.value, output: output, commandResult: commandResult)
    }
    
    private func evaluateCriterionInternal(_ description: String, type: CriterionType, expectedValue: String, output: String, commandResult: (ok: Bool, exitCode: Int, stdout: String, stderr: String)) async -> CriterionResult {
        let actualValue: String
        let passed: Bool
        let message: String
        
        switch type {
        case .containsText:
            actualValue = output
            passed = output.lowercased().contains(expectedValue.lowercased())
            message = passed ? "Text found" : "Text not found"
            
        case .notContainsText:
            actualValue = output
            passed = !output.lowercased().contains(expectedValue.lowercased())
            message = passed ? "Text not found" : "Text found"
            
        case .exitCode:
            actualValue = String(commandResult.exitCode)
            passed = String(commandResult.exitCode) == expectedValue
            message = passed ? "Exit code matches" : "Exit code does not match"
            
        case .fileExists:
            actualValue = await checkFileExists(expectedValue) ? "exists" : "not exists"
            passed = await checkFileExists(expectedValue)
            message = passed ? "File exists" : "File does not exist"
            
        case .fileNotExists:
            let fileExists = await checkFileExists(expectedValue)
            actualValue = fileExists ? "exists" : "not exists"
            passed = !fileExists
            message = passed ? "File does not exist" : "File exists"
            
        case .directoryExists:
            let dirExists = await checkDirectoryExists(expectedValue)
            actualValue = dirExists ? "exists" : "not exists"
            passed = dirExists
            message = passed ? "Directory exists" : "Directory does not exist"
            
        case .directoryNotExists:
            let dirExists = await checkDirectoryExists(expectedValue)
            actualValue = dirExists ? "exists" : "not exists"
            passed = !dirExists
            message = passed ? "Directory does not exist" : "Directory exists"
            
        case .regexMatch:
            actualValue = output
            passed = matchesRegex(pattern: expectedValue, text: output)
            message = passed ? "Regex matches" : "Regex does not match"
            
        case .regexNotMatch:
            actualValue = output
            passed = !matchesRegex(pattern: expectedValue, text: output)
            message = passed ? "Regex does not match" : "Regex matches"
            
        case .outputLength:
            actualValue = String(output.count)
            passed = String(output.count) == expectedValue
            message = passed ? "Output length matches" : "Output length does not match"
            
        case .outputEmpty:
            actualValue = output.isEmpty ? "empty" : "not empty"
            passed = output.isEmpty
            message = passed ? "Output is empty" : "Output is not empty"
            
        case .outputNotEmpty:
            actualValue = output.isEmpty ? "empty" : "not empty"
            passed = !output.isEmpty
            message = passed ? "Output is not empty" : "Output is empty"
            
        case .commandSucceeded:
            actualValue = commandResult.ok ? "succeeded" : "failed"
            passed = commandResult.ok && commandResult.exitCode == 0
            message = passed ? "Command executed successfully" : "Command failed or returned non-zero exit code"
            
        case .fileCreated:
            actualValue = await checkFileExists(expectedValue) ? "exists" : "not exists"
            passed = await checkFileExists(expectedValue)
            message = passed ? "File was created successfully" : "File was not created"
            
        case .fileModified:
            let fileExists = await checkFileExists(expectedValue)
            actualValue = fileExists ? "exists" : "not exists"
            passed = fileExists
            message = passed ? "File exists and can be modified" : "File does not exist for modification"
            
        case .contentAdded:
            actualValue = output.isEmpty ? "empty" : "contains content"
            passed = !output.isEmpty && output.count > 10 // Basic content check
            message = passed ? "Content was added successfully" : "No content was added"
            
        case .processCompleted:
            actualValue = commandResult.ok ? "completed" : "failed"
            passed = commandResult.ok
            message = passed ? "Process completed successfully" : "Process failed to complete"
            
        case .noErrors:
            let hasErrors = output.lowercased().contains("error") || 
                           output.lowercased().contains("failed") || 
                           output.lowercased().contains("permission denied") ||
                           commandResult.exitCode != 0
            actualValue = hasErrors ? "has errors" : "no errors"
            passed = !hasErrors
            message = passed ? "No errors detected" : "Errors were detected in output"
            
        case .expectedPattern:
            actualValue = output
            passed = matchesRegex(pattern: expectedValue, text: output)
            message = passed ? "Expected pattern found" : "Expected pattern not found"
        }
        
        return CriterionResult(
            criterionId: UUID(),
            description: description,
            type: type,
            expectedValue: expectedValue,
            actualValue: actualValue,
            passed: passed,
            message: message
        )
    }
    
    private func evaluateGlobalCriteria(_ criteria: [SuccessCriterion], _ stepResults: [StepExecutionResult]) async -> [CriterionResult] {
        // For global criteria, we evaluate against the overall execution results
        let allOutput = stepResults.map { $0.output }.joined(separator: "\n")
        let overallSuccess = stepResults.allSatisfy { $0.isSuccess }
        
        var results: [CriterionResult] = []
        
        for criterion in criteria {
            let commandResult = (ok: overallSuccess, exitCode: overallSuccess ? 0 : 1, stdout: allOutput, stderr: "")
            let result = await evaluateCriterion(criterion, output: allOutput, commandResult: commandResult)
            results.append(result)
        }
        
        return results
    }
    
    private func evaluateGlobalCriteria(_ criteria: [FailureCriterion], _ stepResults: [StepExecutionResult]) async -> [CriterionResult] {
        // For global criteria, we evaluate against the overall execution results
        let allOutput = stepResults.map { $0.output }.joined(separator: "\n")
        let overallSuccess = stepResults.allSatisfy { $0.isSuccess }
        
        var results: [CriterionResult] = []
        
        for criterion in criteria {
            let commandResult = (ok: overallSuccess, exitCode: overallSuccess ? 0 : 1, stdout: allOutput, stderr: "")
            let result = await evaluateCriterion(criterion, output: allOutput, commandResult: commandResult)
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func checkFileExists(_ path: String) async -> Bool {
        let result = await executeCommand("test -f \(path)", timeoutSeconds: 5)
        return result.ok
    }
    
    private func checkDirectoryExists(_ path: String) async -> Bool {
        let result = await executeCommand("test -d \(path)", timeoutSeconds: 5)
        return result.ok
    }
    
    private func matchesRegex(pattern: String, text: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}

// MARK: - Execution Errors

enum ExecutionError: Error, LocalizedError {
    case timeoutExceeded(Int)
    case stepFailed(String, String)
    case criteriaEvaluationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .timeoutExceeded(let seconds):
            return "Execution timeout exceeded: \(seconds) seconds"
        case .stepFailed(let stepId, let error):
            return "Step '\(stepId)' failed: \(error)"
        case .criteriaEvaluationFailed(let error):
            return "Criteria evaluation failed: \(error)"
        }
    }
}
