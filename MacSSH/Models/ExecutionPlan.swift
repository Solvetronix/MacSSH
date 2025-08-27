import Foundation

// MARK: - Core Execution Models

struct PlanStep: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let command: String
    let successCriteria: [SuccessCriterion]
    let failureCriteria: [FailureCriterion]
    let expectedOutput: String?
    let timeoutSeconds: Int
    
    init(id: String, title: String, description: String, command: String, 
         successCriteria: [SuccessCriterion] = [], failureCriteria: [FailureCriterion] = [],
         expectedOutput: String? = nil, timeoutSeconds: Int = 30) {
        self.id = id
        self.title = title
        self.description = description
        self.command = command
        self.successCriteria = successCriteria
        self.failureCriteria = failureCriteria
        self.expectedOutput = expectedOutput
        self.timeoutSeconds = timeoutSeconds
    }
}

struct SuccessCriterion: Codable, Identifiable {
    let id = UUID()
    let description: String
    let type: CriterionType
    let value: String
    
    init(description: String, type: CriterionType, value: String) {
        self.description = description
        self.type = type
        self.value = value
    }
}

struct FailureCriterion: Codable, Identifiable {
    let id = UUID()
    let description: String
    let type: CriterionType
    let value: String
    
    init(description: String, type: CriterionType, value: String) {
        self.description = description
        self.type = type
        self.value = value
    }
}

enum CriterionType: String, Codable, CaseIterable {
    case containsText = "contains_text"
    case notContainsText = "not_contains_text"
    case exitCode = "exit_code"
    case fileExists = "file_exists"
    case fileNotExists = "file_not_exists"
    case directoryExists = "directory_exists"
    case directoryNotExists = "directory_not_exists"
    case regexMatch = "regex_match"
    case regexNotMatch = "regex_not_match"
    case outputLength = "output_length"
    case outputEmpty = "output_empty"
    case outputNotEmpty = "output_not_empty"
}

struct ExecutionPlan: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let steps: [PlanStep]
    let globalSuccessCriteria: [SuccessCriterion]
    let globalFailureCriteria: [FailureCriterion]
    let maxTotalTime: Int // seconds
    let maxRetries: Int
    
    init(title: String, description: String, steps: [PlanStep], 
         globalSuccessCriteria: [SuccessCriterion] = [], globalFailureCriteria: [FailureCriterion] = [],
         maxTotalTime: Int = 300, maxRetries: Int = 3) {
        self.title = title
        self.description = description
        self.steps = steps
        self.globalSuccessCriteria = globalSuccessCriteria
        self.globalFailureCriteria = globalFailureCriteria
        self.maxTotalTime = maxTotalTime
        self.maxRetries = maxRetries
    }
}

// MARK: - Execution State

enum ExecutionStatus: String, Codable, CaseIterable {
    case planning = "PLANNING"
    case executing = "EXECUTING"
    case observing = "OBSERVING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
}

enum StepStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case executing = "EXECUTING"
    case success = "SUCCESS"
    case failed = "FAILED"
    case skipped = "SKIPPED"
}

struct StepExecutionResult: Codable, Identifiable {
    let id = UUID()
    let stepId: String
    let status: StepStatus
    let command: String
    let output: String
    let error: String?
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let successCriteriaResults: [CriterionResult]
    let failureCriteriaResults: [CriterionResult]
    let retryCount: Int
    
    var isSuccess: Bool {
        status == .success
    }
    
    var isFailed: Bool {
        status == .failed
    }
}

struct CriterionResult: Codable, Identifiable {
    let id = UUID()
    let criterionId: UUID
    let description: String
    let type: CriterionType
    let expectedValue: String
    let actualValue: String
    let passed: Bool
    let message: String
}

struct PlanExecutionResult: Codable {
    let planId: UUID
    let status: ExecutionStatus
    let startTime: Date
    let endTime: Date?
    let totalDuration: TimeInterval
    let stepResults: [StepExecutionResult]
    let globalSuccessResults: [CriterionResult]
    let globalFailureResults: [CriterionResult]
    let finalMessage: String
    let error: String?
    
    var isSuccess: Bool {
        status == .completed
    }
    
    var isFailed: Bool {
        status == .failed
    }
    
    var successRate: Double {
        let successfulSteps = stepResults.filter { $0.isSuccess }.count
        return stepResults.isEmpty ? 0.0 : Double(successfulSteps) / Double(stepResults.count)
    }
}

// MARK: - Extensions

extension ExecutionPlan {
    static let example = ExecutionPlan(
        title: "System Information Gathering",
        description: "Gather comprehensive system information including memory, disk, and process details",
        steps: [
            PlanStep(
                id: "memory_info",
                title: "Memory Information",
                description: "Get detailed memory usage information",
                command: "free -h",
                successCriteria: [
                    SuccessCriterion(
                        description: "Command should return memory information",
                        type: .containsText,
                        value: "Mem:"
                    ),
                    SuccessCriterion(
                        description: "Output should not be empty",
                        type: .outputNotEmpty,
                        value: ""
                    )
                ],
                failureCriteria: [
                    FailureCriterion(
                        description: "Should not contain error messages",
                        type: .notContainsText,
                        value: "error"
                    )
                ]
            ),
            PlanStep(
                id: "disk_info",
                title: "Disk Information",
                description: "Get disk usage information",
                command: "df -h",
                successCriteria: [
                    SuccessCriterion(
                        description: "Command should return disk information",
                        type: .containsText,
                        value: "Filesystem"
                    )
                ]
            ),
            PlanStep(
                id: "process_info",
                title: "Process Information",
                description: "Get top processes by memory usage",
                command: "ps aux --sort=-%mem | head -10",
                successCriteria: [
                    SuccessCriterion(
                        description: "Should show process list",
                        type: .containsText,
                        value: "PID"
                    )
                ]
            )
        ],
        globalSuccessCriteria: [
            SuccessCriterion(
                description: "All steps should complete successfully",
                type: .containsText,
                value: "success"
            )
        ],
        maxTotalTime: 120,
        maxRetries: 2
    )
}
