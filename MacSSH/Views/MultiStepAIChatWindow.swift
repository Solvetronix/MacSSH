import SwiftUI
import AppKit

struct MultiStepAIChatWindow: View {
    let profile: Profile
    let terminalService: SwiftTermProfessionalService
    @StateObject private var gptService: GPTTerminalService
    @Environment(\.dismiss) private var dismiss
    
    init(profile: Profile, terminalService: SwiftTermProfessionalService) {
        self.profile = profile
        self.terminalService = terminalService
        
        // Initialize GPT service with the provided terminal service
        self._gptService = StateObject(wrappedValue: GPTTerminalService(terminalService: terminalService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Multi-Step AI Assistant")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Connected to \(profile.host)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("✕") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .help("Close window")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Chat content
            MultiStepAIChatView(gptService: gptService)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // GPT service is already initialized in init
        }
    }
}

#Preview {
    MultiStepAIChatWindow(
        profile: Profile(
            name: "Sample",
            host: "example.com",
            port: 22,
            username: "user",
            password: "password",
            keyType: .password
        ),
        terminalService: SwiftTermProfessionalService()
    )
}
