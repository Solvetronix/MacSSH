import SwiftUI

struct MultiStepAITabView: View {
    @ObservedObject var gptService: GPTTerminalService
    
    var body: some View {
        MultiStepAIChatView(gptService: gptService)
    }
}

#Preview {
    MultiStepAITabView(gptService: GPTTerminalService(
        apiKey: "test",
        terminalService: SwiftTermProfessionalService()
    ))
}
