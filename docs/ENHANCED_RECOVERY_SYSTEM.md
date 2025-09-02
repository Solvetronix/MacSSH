# Enhanced Recovery System

## Overview

The Enhanced Recovery System is a sophisticated error handling and recovery mechanism that automatically analyzes failures and applies intelligent recovery strategies to ensure successful task execution.

## Key Features

### 1. Automatic Error Pattern Recognition

The system automatically detects common error patterns:

- **Command Not Found**: `command not found`, `no such file or directory`
- **Permission Denied**: `permission denied`, `access denied`
- **File Not Found**: `no such file`, `file not found`
- **Directory Not Found**: `directory not found`, `no such directory`
- **Timeout**: `timeout`, `timed out`
- **Connection Failed**: `connection refused`, `connection failed`
- **Insufficient Space**: `insufficient space`, `no space left`
- **Already Exists**: `already exists`, `file exists`
- **Invalid Argument**: `invalid argument`, `bad option`
- **Resource Busy**: `busy`, `device or resource busy`

### 2. Intelligent Recovery Strategies

For each error pattern, the system automatically tries multiple recovery strategies:

#### Command Not Found
- Try alternative commands (e.g., `ls` → `dir`, `cat` → `type`)
- Discover available paths using `which`, `type`, `command -v`
- Suggest package installation for missing tools

#### Permission Denied
- Elevate privileges with `sudo` or `su`
- Change working directory to user's home
- Fix file permissions

#### File/Directory Not Found
- Convert relative paths to absolute paths
- Expand home directory references (`~` → `$HOME`)
- Create missing directories automatically
- Discover available files/directories

#### Timeout Issues
- Increase timeout values
- Retry with delays
- Simplify operations

#### Connection Issues
- Add retry mechanisms with `ConnectTimeout` and `ConnectionAttempts`
- Check network connectivity
- Try alternative endpoints

#### Space Issues
- Clean up temporary files
- Check disk quotas
- Use alternative locations

#### Resource Conflicts
- Wait and retry
- Kill blocking processes
- Use alternative resources

### 3. Enhanced Step Alternatives

Steps can now define enhanced alternatives with recovery strategies:

```swift
PlanStep(
    id: "memory_info",
    title: "Memory Information",
    command: "free -h",
    enhancedAlternatives: [
        EnhancedStepAlternative(
            whenRegex: "command not found",
            recoveryStrategies: [.commandAlternatives, .packageInstallation],
            fallbackCommands: ["cat /proc/meminfo", "vm_stat"],
            maxAttempts: 3,
            retryDelay: 2.0
        )
    ]
)
```

### 4. Recovery Attempt Tracking

The system tracks all recovery attempts:

```swift
struct RecoveryAttempt: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let strategy: RecoveryStrategy
    let command: String
    let success: Bool
    let output: String?
    let error: String?
    let duration: TimeInterval
}
```

## Configuration

### Step-Level Configuration

```swift
struct PlanStep {
    // ... existing fields ...
    
    // Recovery configuration
    let enableAutoRecovery: Bool?        // Default: true
    let maxRecoveryAttempts: Int?        // Default: 3
    let recoveryTimeout: TimeInterval?   // Default: 60 seconds
}
```

### Global Recovery Settings

```swift
struct ExecutionPlan {
    // ... existing fields ...
    
    let maxRetries: Int                  // Maximum retry attempts per step
    let maxTotalTime: Int               // Maximum total execution time
}
```

## Usage Examples

### Basic Usage

```swift
// The system automatically enables recovery for all steps
let step = PlanStep(
    id: "example",
    title: "Example Step",
    command: "some_command",
    // Recovery is enabled by default
)
```

### Custom Recovery Configuration

```swift
let step = PlanStep(
    id: "custom_recovery",
    title: "Custom Recovery Step",
    command: "complex_command",
    enableAutoRecovery: true,
    maxRecoveryAttempts: 5,
    recoveryTimeout: 120.0,
    enhancedAlternatives: [
        EnhancedStepAlternative(
            whenRegex: "permission denied",
            recoveryStrategies: [.elevatePrivileges, .changeDirectory],
            maxAttempts: 2
        )
    ]
)
```

### Disabling Auto-Recovery

```swift
let step = PlanStep(
    id: "no_recovery",
    title: "No Recovery Step",
    command: "critical_command",
    enableAutoRecovery: false  // Disable automatic recovery
)
```

## Recovery Flow

1. **Step Execution**: Execute the original step
2. **Failure Detection**: If step fails, analyze error patterns
3. **Recovery Strategy Selection**: Choose appropriate recovery strategies
4. **Strategy Execution**: Try each strategy in order of likelihood
5. **Success Check**: If any strategy succeeds, return success
6. **Fallback**: If all strategies fail, fall back to original alternatives
7. **Final Retry**: If still no success, retry with increased attempts

## Benefits

### 1. Increased Success Rate
- Automatic handling of common errors
- Multiple recovery strategies per error type
- Intelligent fallback mechanisms

### 2. Reduced Manual Intervention
- No need to manually diagnose common issues
- Automatic retry with different approaches
- Self-healing system

### 3. Better User Experience
- Faster task completion
- Less frustration from common failures
- Transparent recovery process

### 4. Learning and Adaptation
- Tracks successful recovery strategies
- Can be extended with new patterns
- Integrates with GPT for intelligent suggestions

## Future Enhancements

### 1. GPT Integration
- Use GPT to analyze error context
- Generate custom recovery strategies
- Learn from successful recoveries

### 2. Machine Learning
- Pattern recognition from historical data
- Predictive error prevention
- Adaptive strategy selection

### 3. Community Strategies
- Share successful recovery strategies
- Import strategies from other users
- Collaborative improvement

### 4. Advanced Discovery
- Environment-aware recovery
- Cross-platform compatibility
- Dependency resolution

## Best Practices

### 1. Define Clear Success Criteria
```swift
successCriteria: [
    SuccessCriterion(
        description: "Command should return expected output",
        type: .containsText,
        value: "expected_text"
    )
]
```

### 2. Use Specific Failure Criteria
```swift
failureCriteria: [
    FailureCriterion(
        description: "Should not contain error messages",
        type: .notContainsText,
        value: "error"
    )
]
```

### 3. Set Appropriate Timeouts
```swift
timeoutSeconds: 30  // Reasonable timeout for the operation
```

### 4. Enable Auto-Recovery
```swift
enableAutoRecovery: true  // Enable automatic recovery
```

### 5. Test Recovery Strategies
- Test with common failure scenarios
- Verify recovery strategies work
- Monitor recovery success rates

## Monitoring and Debugging

### Recovery Status
```swift
@Published var isRecovering: Bool
@Published var currentRecoveryStrategy: RecoveryStrategy?
@Published var recoveryAttempts: [RecoveryAttempt]
@Published var lastRecoveryError: String?
```

### Logging
The system provides detailed logging for all recovery attempts:
- Recovery strategy selection
- Strategy execution results
- Success/failure tracking
- Performance metrics

### Debugging Tips
1. Check `recoveryAttempts` for detailed recovery history
2. Monitor `currentRecoveryStrategy` for active recovery
3. Review `lastRecoveryError` for failed recovery attempts
4. Use logging to trace recovery flow

## Conclusion

The Enhanced Recovery System significantly improves the reliability and user experience of task execution by automatically handling common failures and applying intelligent recovery strategies. It reduces manual intervention, increases success rates, and provides a robust foundation for complex automation workflows.
