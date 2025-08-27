
import SwiftUI

struct StructuredPlanView: View {
    @StateObject private var planExecutor: PlanExecutor
    @StateObject private var planGenerator: PlanGenerator
    
    @State private var userRequest = ""
    @State private var currentPlan: ExecutionPlan?
    @State private var isGeneratingPlan = false
    @State private var planGenerationError: String?
    @State private var showingPlanDetails = false
    @State private var executionResult: PlanExecutionResult?
    
    init(terminalService: SwiftTermProfessionalService, gptService: GPTTerminalService) {
        self._planExecutor = StateObject(wrappedValue: PlanExecutor(terminalService: terminalService, gptService: gptService))
        self._planGenerator = StateObject(wrappedValue: PlanGenerator(gptService: gptService))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Планирование и выполнение задач")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            
            // User Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Опишите задачу для выполнения:")
                    .font(.headline)
                
                TextField("Например: собери информацию о системе, проверь свободное место на диске", text: $userRequest, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                HStack {
                    Button("Создать план") {
                        Task {
                            await generatePlan()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userRequest.isEmpty || isGeneratingPlan)
                    
                    Button("Загрузить пример") {
                        currentPlan = ExecutionPlan.example
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
            
            // Plan Generation Status
            if isGeneratingPlan {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Создание плана выполнения...")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            if let error = planGenerationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
            
            // Current Plan Display
            if let plan = currentPlan {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("План: \(plan.title)")
                            .font(.headline)
                        Spacer()
                        Button("Детали") {
                            showingPlanDetails = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Plan Summary
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "number")
                            Text("\(plan.steps.count) шагов")
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                            Text("Макс. время: \(plan.maxTotalTime)с")
                        }
                        
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Макс. повторы: \(plan.maxRetries)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Execution Controls
                    HStack {
                        Button(planExecutor.isExecuting ? "Остановить" : "Выполнить план") {
                            if planExecutor.isExecuting {
                                // TODO: Implement stop functionality
                            } else {
                                Task {
                                    await executePlan(plan)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(planExecutor.isExecuting)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Execution Status
            if planExecutor.isExecuting {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.green)
                        Text("Выполнение плана")
                            .font(.headline)
                        Spacer()
                        Text(planExecutor.currentStatus.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    // Progress
                    ProgressView(value: planExecutor.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    // Step Results
                    if !planExecutor.stepResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Прогресс выполнения:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(planExecutor.stepResults) { result in
                                HStack {
                                    Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.isSuccess ? .green : .red)
                                    Text(result.stepId)
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1fs", result.duration))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Execution Results
            if let result = executionResult {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.isSuccess ? .green : .red)
                        Text(result.isSuccess ? "План выполнен успешно" : "План выполнен с ошибками")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.1fs", result.totalDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(result.finalMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    if let error = result.error {
                        Text("Ошибка: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Success Rate
                    HStack {
                        Text("Успешность: \(Int(result.successRate * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(result.stepResults.filter { $0.isSuccess }.count)/\(result.stepResults.count) шагов")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Error Display
            if let error = planExecutor.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingPlanDetails) {
            if let plan = currentPlan {
                PlanDetailsView(plan: plan)
            }
        }
    }
    
    private func generatePlan() async {
        isGeneratingPlan = true
        planGenerationError = nil
        
        do {
            currentPlan = try await planGenerator.generatePlan(from: userRequest)
        } catch {
            planGenerationError = error.localizedDescription
        }
        
        isGeneratingPlan = false
    }
    
    private func executePlan(_ plan: ExecutionPlan) async {
        executionResult = await planExecutor.executePlan(plan)
    }
}

// MARK: - Plan Details View

struct PlanDetailsView: View {
    let plan: ExecutionPlan
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Plan Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(plan.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("\(plan.steps.count) шагов", systemImage: "list.bullet")
                            Spacer()
                            Label("\(plan.maxTotalTime)с", systemImage: "clock")
                            Label("\(plan.maxRetries) повторов", systemImage: "arrow.clockwise")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Шаги выполнения:")
                            .font(.headline)
                        
                        ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(index + 1). \(step.title)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                
                                Text(step.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Команда: \(step.command)")
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(6)
                                    
                                    if !step.successCriteria.isEmpty {
                                        Text("Критерии успеха:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        ForEach(step.successCriteria) { criterion in
                                            Text("• \(criterion.description)")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    
                                    if !step.failureCriteria.isEmpty {
                                        Text("Критерии неудачи:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        ForEach(step.failureCriteria) { criterion in
                                            Text("• \(criterion.description)")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    
                                    if let expectedOutput = step.expectedOutput {
                                        Text("Ожидаемый вывод: \(expectedOutput)")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Global Criteria
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Глобальные критерии:")
                            .font(.headline)
                        
                        if !plan.globalSuccessCriteria.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Критерии успеха:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                ForEach(plan.globalSuccessCriteria) { criterion in
                                    Text("• \(criterion.description)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        if !plan.globalFailureCriteria.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Критерии неудачи:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                ForEach(plan.globalFailureCriteria) { criterion in
                                    Text("• \(criterion.description)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Детали плана")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    StructuredPlanView(
        terminalService: SwiftTermProfessionalService(),
                    gptService: GPTTerminalService(terminalService: SwiftTermProfessionalService())
    )
}
