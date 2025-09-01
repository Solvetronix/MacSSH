import Foundation
import SwiftTerm

/// Надежный метод определения завершения команд
/// Использует комбинацию Event-Driven + Process Monitoring + Output Stability
class ReliableCommandCompletion {
    
    private weak var terminalService: SwiftTermProfessionalService?
    
    init(terminalService: SwiftTermProfessionalService) {
        self.terminalService = terminalService
    }
    
    /// Основной метод ожидания завершения команды
    func waitForCommandCompletion(command: String) async -> String {
        LoggingService.shared.info("⏳ [Reliable] Waiting for command completion: '\(command)'", source: "ReliableCommandCompletion")
        
        return await withCheckedContinuation { continuation in
            let completionHandler = ReliableCompletionHandler(
                command: command,
                terminalService: terminalService,
                onComplete: { output in
                    continuation.resume(returning: output)
                }
            )
            
            completionHandler.startMonitoring()
        }
    }
}

/// Надежный обработчик завершения команд
private class ReliableCompletionHandler {
    
    private let command: String
    private let onComplete: (String) -> Void
    private weak var terminalService: SwiftTermProfessionalService?
    
    // Output stability tracking
    private var lastOutputLength = 0
    private var stableCount = 0
    private let requiredStableChecks = 3
    private let stabilityDelay: TimeInterval = 0.3
    
    // Monitoring components
    private var monitoringTimer: Timer?
    private var dataReceivedObserver: NSObjectProtocol?
    private var isCompleted = false
    
    init(command: String, terminalService: SwiftTermProfessionalService?, onComplete: @escaping (String) -> Void) {
        self.command = command
        self.terminalService = terminalService
        self.onComplete = onComplete
    }
    
    func startMonitoring() {
        LoggingService.shared.info("🔍 [Reliable] Starting monitoring for: '\(command)'", source: "ReliableCommandCompletion")
        
        // 1. Monitor data received events
        setupDataReceivedMonitoring()
        
        // 2. Monitor output stability
        startStabilityMonitoring()

        // 3. Stop monitoring if terminal session is closing
        NotificationCenter.default.addObserver(forName: .terminalSessionWillClose, object: nil, queue: .main) { [weak self] _ in
            self?.cleanupAndComplete()
        }
    }
    
    // MARK: - Data Received Monitoring
    
    private func setupDataReceivedMonitoring() {
        // Monitor for new data received in terminal
        dataReceivedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TerminalDataReceived"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDataReceived()
        }
        
        LoggingService.shared.debug("🔍 [Reliable] Data received monitoring enabled", source: "ReliableCommandCompletion")
    }
    
    private func handleDataReceived() {
        // Reset stability counter when new data arrives
        stableCount = 0
        LoggingService.shared.debug("📊 [Reliable] New data received, resetting stability counter", source: "ReliableCommandCompletion")
    }
    
    // MARK: - Output Stability Monitoring
    
    private func startStabilityMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: stabilityDelay, repeats: true) { [weak self] _ in
            self?.checkOutputStability()
        }
        
        LoggingService.shared.debug("🔍 [Reliable] Output stability monitoring enabled", source: "ReliableCommandCompletion")
    }
    
    private func checkOutputStability() {
        Task { @MainActor in
            guard !isCompleted else { return }
            let currentOutput = await terminalService?.getCurrentOutput() ?? ""
            
            if currentOutput.count == lastOutputLength {
                stableCount += 1
                LoggingService.shared.debug("📊 [Reliable] Output stable: \(stableCount)/\(requiredStableChecks)", source: "ReliableCommandCompletion")
                
                if stableCount >= requiredStableChecks {
                    LoggingService.shared.info("✅ [Reliable] Command completed (output stable): '\(command)'", source: "ReliableCommandCompletion")
                    cleanupAndComplete()
                }
            } else {
                stableCount = 0
                lastOutputLength = currentOutput.count
                LoggingService.shared.debug("📊 [Reliable] Output changed, resetting stability counter", source: "ReliableCommandCompletion")
            }
        }
    }
    
    // MARK: - Completion and Cleanup
    
    private func cleanupAndComplete() {
        LoggingService.shared.info("🧹 [Reliable] Cleaning up monitoring for: '\(command)'", source: "ReliableCommandCompletion")
        isCompleted = true
        
        // Cleanup timer
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Cleanup observers
        if let observer = dataReceivedObserver {
            NotificationCenter.default.removeObserver(observer)
            dataReceivedObserver = nil
        }
        
        // Get final output and complete
        Task { @MainActor in
            let finalOutput = await terminalService?.getCurrentOutput() ?? ""
            LoggingService.shared.info("✅ [Reliable] Command completed successfully: '\(command)'", source: "ReliableCommandCompletion")
            onComplete(finalOutput)
        }
    }
}
