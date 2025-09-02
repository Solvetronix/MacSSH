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
    // Optional environment variables and pre-commands for this step
    let env: [String: String]?
    let pre: [String]?
    // Optional alternatives to apply on failure
    let alternatives: [StepAlternative]?
    // Enhanced alternatives with recovery strategies
    let enhancedAlternatives: [EnhancedStepAlternative]?
    // Optional manual testing checkpoint
    let checkpoint: Bool?
    let testInstructions: String?
    let testPrompts: [String]?
    // Recovery configuration
    let enableAutoRecovery: Bool?
    let maxRecoveryAttempts: Int?
    let recoveryTimeout: TimeInterval?
    
    init(id: String, title: String, description: String, command: String, 
         successCriteria: [SuccessCriterion] = [], failureCriteria: [FailureCriterion] = [],
         expectedOutput: String? = nil, timeoutSeconds: Int = 30,
         env: [String: String]? = nil, pre: [String]? = nil, alternatives: [StepAlternative]? = nil,
         enhancedAlternatives: [EnhancedStepAlternative]? = nil, checkpoint: Bool? = nil, 
         testInstructions: String? = nil, testPrompts: [String]? = nil,
         enableAutoRecovery: Bool? = true, maxRecoveryAttempts: Int? = 3, recoveryTimeout: TimeInterval? = 60) {
        self.id = id
        self.title = title
        self.description = description
        self.command = command
        self.successCriteria = successCriteria
        self.failureCriteria = failureCriteria
        self.expectedOutput = expectedOutput
        self.timeoutSeconds = timeoutSeconds
        self.env = env
        self.pre = pre
        self.alternatives = alternatives
        self.enhancedAlternatives = enhancedAlternatives
        self.checkpoint = checkpoint
        self.testInstructions = testInstructions
        self.testPrompts = testPrompts
        self.enableAutoRecovery = enableAutoRecovery
        self.maxRecoveryAttempts = maxRecoveryAttempts
        self.recoveryTimeout = recoveryTimeout
    }
}

// MARK: - Step Alternatives

struct StepAlternative: Codable, Identifiable {
    let id = UUID()
    /// Regex pattern to match in combined output to trigger this alternative
    let whenRegex: String?
    /// Commands to apply (like mkdir -p, export, etc.) before retrying original command
    let apply: [String]?
    /// Replacement commands to execute instead of the original command
    let replaceCommands: [String]?
    /// Whether to retry the original command after apply
    let retry: Bool?
    
    init(whenRegex: String? = nil, apply: [String]? = nil, replaceCommands: [String]? = nil, retry: Bool? = nil) {
        self.whenRegex = whenRegex
        self.apply = apply
        self.replaceCommands = replaceCommands
        self.retry = retry
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
    // New criteria for better success detection
    case commandSucceeded = "command_succeeded"
    case fileCreated = "file_created"
    case fileModified = "file_modified"
    case contentAdded = "content_added"
    case processCompleted = "process_completed"
    case noErrors = "no_errors"
    case expectedPattern = "expected_pattern"
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
    // Plan-level environment and pre-commands
    let planEnv: [String: String]?
    let planPre: [String]?
    
    init(title: String, description: String, steps: [PlanStep], 
         globalSuccessCriteria: [SuccessCriterion] = [], globalFailureCriteria: [FailureCriterion] = [],
         maxTotalTime: Int = 300, maxRetries: Int = 3,
         planEnv: [String: String]? = nil, planPre: [String]? = nil) {
        self.title = title
        self.description = description
        self.steps = steps
        self.globalSuccessCriteria = globalSuccessCriteria
        self.globalFailureCriteria = globalFailureCriteria
        self.maxTotalTime = maxTotalTime
        self.maxRetries = maxRetries
        self.planEnv = planEnv
        self.planPre = planPre
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
    let exitCode: Int
    let rawStdout: String
    let rawStderr: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let successCriteriaResults: [CriterionResult]
    let failureCriteriaResults: [CriterionResult]
    let retryCount: Int
    let notes: String?
    let matchedAlternativeRegex: String?
    let appliedAlternativeType: String? // apply|replace|retry|none
    // Enhanced recovery tracking
    let recoveryAttempts: [RecoveryAttempt]?
    let autoRecoveryEnabled: Bool?
    let finalRecoveryStrategy: RecoveryStrategy?
    
    var isSuccess: Bool {
        status == .success
    }
    
    var isFailed: Bool {
        status == .failed
    }
    
    var recoveryAttemptsCount: Int {
        return recoveryAttempts?.count ?? 0
    }
    
    var successfulRecovery: Bool {
        return finalRecoveryStrategy != nil && status == .success
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

// MARK: - Error Analysis Models

enum ErrorPattern: String, Codable, CaseIterable {
    case commandNotFound = "command_not_found"
    case permissionDenied = "permission_denied"
    case fileNotFound = "file_not_found"
    case directoryNotFound = "directory_not_found"
    case timeout = "timeout"
    case connectionFailed = "connection_failed"
    case insufficientSpace = "insufficient_space"
    case alreadyExists = "already_exists"
    case invalidArgument = "invalid_argument"
    case resourceBusy = "resource_busy"
    
    var description: String {
        switch self {
        case .commandNotFound:
            return "Command not found"
        case .permissionDenied:
            return "Permission denied"
        case .fileNotFound:
            return "File not found"
        case .directoryNotFound:
            return "Directory not found"
        case .timeout:
            return "Operation timed out"
        case .connectionFailed:
            return "Connection failed"
        case .insufficientSpace:
            return "Insufficient disk space"
        case .alreadyExists:
            return "Resource already exists"
        case .invalidArgument:
            return "Invalid argument"
        case .resourceBusy:
            return "Resource is busy"
        }
    }
    
    var recoveryStrategies: [RecoveryStrategy] {
        switch self {
        case .commandNotFound:
            return [.commandAlternatives, .pathDiscovery, .packageInstallation]
        case .permissionDenied:
            return [.elevatePrivileges, .changeDirectory, .fixPermissions]
        case .fileNotFound:
            return [.pathFix, .fileDiscovery, .createFile]
        case .directoryNotFound:
            return [.createDirectory, .pathFix, .directoryDiscovery]
        case .timeout:
            return [.increaseTimeout, .retryWithDelay, .simplifyOperation]
        case .connectionFailed:
            return [.retryConnection, .checkNetwork, .alternativeEndpoint]
        case .insufficientSpace:
            return [.cleanupSpace, .checkQuota, .alternativeLocation]
        case .alreadyExists:
            return [.forceOperation, .skipOperation, .backupAndReplace]
        case .invalidArgument:
            return [.simplifyArguments, .getHelp, .alternativeSyntax]
        case .resourceBusy:
            return [.waitAndRetry, .killProcess, .alternativeResource]
        }
    }
}

enum RecoveryStrategy: String, Codable, CaseIterable {
    case commandAlternatives = "command_alternatives"
    case pathDiscovery = "path_discovery"
    case packageInstallation = "package_installation"
    case elevatePrivileges = "elevate_privileges"
    case changeDirectory = "change_directory"
    case fixPermissions = "fix_permissions"
    case pathFix = "path_fix"
    case fileDiscovery = "file_discovery"
    case createFile = "create_file"
    case createDirectory = "create_directory"
    case directoryDiscovery = "directory_discovery"
    case increaseTimeout = "increase_timeout"
    case retryWithDelay = "retry_with_delay"
    case simplifyOperation = "simplify_operation"
    case retryConnection = "retry_connection"
    case checkNetwork = "check_network"
    case alternativeEndpoint = "alternative_endpoint"
    case cleanupSpace = "cleanup_space"
    case checkQuota = "check_quota"
    case alternativeLocation = "alternative_location"
    case forceOperation = "force_operation"
    case skipOperation = "skip_operation"
    case backupAndReplace = "backup_and_replace"
    case simplifyArguments = "simplify_arguments"
    case getHelp = "get_help"
    case alternativeSyntax = "alternative_syntax"
    case waitAndRetry = "wait_and_retry"
    case killProcess = "kill_process"
    case alternativeResource = "alternative_resource"
    
    var description: String {
        switch self {
        case .commandAlternatives:
            return "Try alternative commands"
        case .pathDiscovery:
            return "Discover available paths"
        case .packageInstallation:
            return "Install required packages"
        case .elevatePrivileges:
            return "Elevate privileges"
        case .changeDirectory:
            return "Change working directory"
        case .fixPermissions:
            return "Fix file permissions"
        case .pathFix:
            return "Fix file paths"
        case .fileDiscovery:
            return "Discover available files"
        case .createFile:
            return "Create required file"
        case .createDirectory:
            return "Create required directory"
        case .directoryDiscovery:
            return "Discover available directories"
        case .increaseTimeout:
            return "Increase operation timeout"
        case .retryWithDelay:
            return "Retry with delay"
        case .simplifyOperation:
            return "Simplify operation"
        case .retryConnection:
            return "Retry connection"
        case .checkNetwork:
            return "Check network status"
        case .alternativeEndpoint:
            return "Try alternative endpoint"
        case .cleanupSpace:
            return "Clean up disk space"
        case .checkQuota:
            return "Check disk quota"
        case .alternativeLocation:
            return "Use alternative location"
        case .forceOperation:
            return "Force operation"
        case .skipOperation:
            return "Skip operation"
        case .backupAndReplace:
            return "Backup and replace"
        case .simplifyArguments:
            return "Simplify command arguments"
        case .getHelp:
            return "Get command help"
        case .alternativeSyntax:
            return "Use alternative syntax"
        case .waitAndRetry:
            return "Wait and retry"
        case .killProcess:
            return "Kill blocking process"
        case .alternativeResource:
            return "Use alternative resource"
        }
    }
}

struct ErrorAnalysis: Codable {
    let patterns: [ErrorPattern]
    let output: String
    let error: String?
    let exitCode: Int
    
    var primaryPattern: ErrorPattern? {
        return patterns.first
    }
    
    var hasRecoveryStrategies: Bool {
        return !patterns.isEmpty
    }
    
    var suggestedStrategies: [RecoveryStrategy] {
        return patterns.flatMap { $0.recoveryStrategies }
    }
}

struct RecoveryAttempt: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let strategy: RecoveryStrategy
    let command: String
    let success: Bool
    let output: String?
    let error: String?
    let duration: TimeInterval
    
    init(strategy: RecoveryStrategy, command: String, success: Bool, output: String? = nil, error: String? = nil, duration: TimeInterval = 0) {
        self.timestamp = Date()
        self.strategy = strategy
        self.command = command
        self.success = success
        self.output = output
        self.error = error
        self.duration = duration
    }
}

// MARK: - Enhanced Step Alternatives

struct EnhancedStepAlternative: Codable, Identifiable {
    let id = UUID()
    /// Regex pattern to match in combined output to trigger this alternative
    let whenRegex: String?
    /// Commands to apply (like mkdir -p, export, etc.) before retrying original command
    let apply: [String]?
    /// Replacement commands to execute instead of the original command
    let replaceCommands: [String]?
    /// Whether to retry the original command after apply
    let retry: Bool?
    /// Recovery strategies to try if this alternative fails
    let recoveryStrategies: [RecoveryStrategy]?
    /// Fallback commands if recovery strategies fail
    let fallbackCommands: [String]?
    /// Maximum attempts for this alternative
    let maxAttempts: Int?
    /// Delay between attempts in seconds
    let retryDelay: TimeInterval?
    
    init(whenRegex: String? = nil, apply: [String]? = nil, replaceCommands: [String]? = nil, retry: Bool? = nil, 
         recoveryStrategies: [RecoveryStrategy]? = nil, fallbackCommands: [String]? = nil, 
         maxAttempts: Int? = nil, retryDelay: TimeInterval? = nil) {
        self.whenRegex = whenRegex
        self.apply = apply
        self.replaceCommands = replaceCommands
        self.retry = retry
        self.recoveryStrategies = recoveryStrategies
        self.fallbackCommands = fallbackCommands
        self.maxAttempts = maxAttempts
        self.retryDelay = retryDelay
    }
}
