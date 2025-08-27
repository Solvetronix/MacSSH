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
    
    init(terminalService: SwiftTermProfessionalService, gptService: GPTTerminalService) {
        self.terminalService = terminalService
        self.gptService = gptService
    }
    
    // MARK: - Plan Execution
    
    func executePlan(_ plan: ExecutionPlan) async -> PlanExecutionResult {
        LoggingService.shared.info("🚀 Starting plan execution: \(plan.title)", source: "PlanExecutor")
        
        await MainActor.run {
            self.currentPlan = plan
            self.currentStatus = .executing
            self.isExecuting = true
            self.stepResults = []
            self.lastError = nil
            self.progress = 0.0
        }
        
        let startTime = Date()
        var results: [StepExecutionResult] = []
        
        do {
            // Execute each step
            for (index, step) in plan.steps.enumerated() {
                await MainActor.run {
                    self.progress = Double(index) / Double(plan.steps.count)
                }
                
                LoggingService.shared.info("⚡ Executing step \(index + 1)/\(plan.steps.count): \(step.title)", source: "PlanExecutor")
                
                let stepResult = await executeStep(step, retryCount: 0, maxRetries: plan.maxRetries)
                results.append(stepResult)
                
                await MainActor.run {
                    self.stepResults.append(stepResult)
                }
                
                // Check if step failed and handle retries
                if stepResult.isFailed && stepResult.retryCount < plan.maxRetries {
                    LoggingService.shared.warning("🔄 Step failed, attempting retry \(stepResult.retryCount + 1)/\(plan.maxRetries)", source: "PlanExecutor")
                    
                    for retry in 1...plan.maxRetries {
                        let retryResult = await executeStep(step, retryCount: retry, maxRetries: plan.maxRetries)
                        results.append(retryResult)
                        
                        await MainActor.run {
                            self.stepResults.append(retryResult)
                        }
                        
                        if retryResult.isSuccess {
                            break
                        }
                    }
                }
                
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
    
    private func executeStep(_ step: PlanStep, retryCount: Int, maxRetries: Int) async -> StepExecutionResult {
        LoggingService.shared.info("🔧 Executing step: \(step.title) (retry \(retryCount)/\(maxRetries))", source: "PlanExecutor")
        
        let startTime = Date()
        
        // Execute command
        let commandResult = await executeCommand(step.command, timeoutSeconds: step.timeoutSeconds)
        
        // Wait for command completion
        let output = await waitForCommandCompletion(command: step.command, timeoutSeconds: step.timeoutSeconds)
        
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
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            successCriteriaResults: successResults,
            failureCriteriaResults: failureResults,
            retryCount: retryCount
        )
    }
    
    private func executeCommand(_ command: String, timeoutSeconds: Int) async -> (ok: Bool, exitCode: Int, stdout: String, stderr: String) {
        LoggingService.shared.debug("🔧 Executing command: \(command)", source: "PlanExecutor")
        
        // Save current output state
        let outputBeforeCommand = await terminalService.getCurrentOutput() ?? ""
        
        // Wait for terminal to stabilize
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Execute command
        await MainActor.run {
            terminalService.sendCommand(command)
        }
        
        // Wait for completion
        let output = await waitForCommandCompletion(command: command, timeoutSeconds: timeoutSeconds)
        
        // Additional safety delay to ensure terminal is fully ready
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Extract new output with final verification
        let currentOutput = await terminalService.getCurrentOutput() ?? ""
        let newOutput = String(currentOutput.dropFirst(outputBeforeCommand.count))
        
        // Determine success (simplified - in real implementation you'd parse actual exit code)
        let ok = !newOutput.lowercased().contains("error") && !newOutput.lowercased().contains("command not found")
        let exitCode = ok ? 0 : 1
        
        return (ok: ok, exitCode: exitCode, stdout: newOutput, stderr: "")
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
