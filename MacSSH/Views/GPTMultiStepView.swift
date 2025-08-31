import SwiftUI

struct GPTMultiStepView: View {
    @ObservedObject var gptService: GPTTerminalService
    @State private var taskInput: String = ""
    @State private var showingTaskInput = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("AI Multi-Step Terminal")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if gptService.isMultiStepMode {
                    Button("Stop") {
                        Task {
                            await gptService.stopMultiStepExecution()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.horizontal)
            
            if !gptService.isMultiStepMode {
                // Task input section
                VStack(spacing: 12) {
                    Text("Describe what you want the AI to do:")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    TextField("e.g., Check system status, find large files, update packages...", text: $taskInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    Button("Start AI Task") {
                        guard !taskInput.isEmpty else { return }
                        Task {
                            await gptService.startMultiStepExecution(task: taskInput)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(taskInput.isEmpty || gptService.isProcessing)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Multi-step execution UI
                VStack(spacing: 16) {
                    // Current task
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Task:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(gptService.currentTask)
                            .font(.body)
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                    
                    // Progress indicator
                    HStack {
                        Text("Step \(gptService.currentStep) of \(gptService.totalSteps > 0 ? String(gptService.totalSteps) : "?")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if gptService.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    // Pending command confirmation
                    if gptService.isWaitingForConfirmation {
                        VStack(spacing: 12) {
                            Text("Next Step:")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            if let explanation = gptService.pendingExplanation {
                                Text(explanation)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.systemBlue).opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            if let command = (gptService.pendingCommandDisplay ?? gptService.pendingCommand) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Command to execute:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(command)
                                        .font(.system(.body, design: .monospaced))
                                        .padding()
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(8)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    Task {
                                        await gptService.cancelStep()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                
                                Button("Execute") {
                                    Task {
                                        await gptService.confirmNextStep()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemYellow).opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Execution history
                    if !gptService.executionHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Execution History:")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(gptService.executionHistory) { step in
                                        ExecutionStepView(step: step)
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
}

#Preview {
    GPTMultiStepView(gptService: GPTTerminalService(

        terminalService: SwiftTermProfessionalService()
    ))
}
