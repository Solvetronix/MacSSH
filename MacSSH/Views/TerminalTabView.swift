import SwiftUI
import SwiftTerm

struct TerminalTabView: View {
    let terminalService: SwiftTermProfessionalService
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal content
            SwiftTerminalView(terminalService: terminalService)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, 4)
                .background(Color.white, alignment: .leading)
        }
    }
}

#Preview {
    TerminalTabView(terminalService: SwiftTermProfessionalService())
}
