import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    // Callback to toggle inclusion of this message into next prompt context
    var onToggleInclude: ((UUID, Bool) -> Void)? = nil
    @State private var isExpanded = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar/Icon
            VStack {
                Image(systemName: message.icon)
                    .font(.title2)
                    .foregroundColor(message.textColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(message.backgroundColor)
                    )
                
                if message.type == .user {
                    Spacer()
                }
            }
            
            // Message content
            VStack(alignment: .leading, spacing: 8) {
                // Header with timestamp
                HStack {
                    Text(message.type == .user ? "You" : "AI Assistant")
                        .font(.headline)
                        .foregroundColor(message.textColor)
                    
                    Spacer()
                    
                    Text(message.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Main content
                VStack(alignment: .leading, spacing: 8) {
                    if message.content.count > 600 {
                        // Collapsed long content with Show more
                        VStack(alignment: .leading, spacing: 6) {
                            if isExpanded {
                                GPTMarkdownView(normalizeOutput(message.content))
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                let preview = String(message.content.prefix(600)) + "…"
                                GPTMarkdownView(normalizeOutput(preview))
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Button(isExpanded ? "Скрыть" : "Показать полностью") {
                                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    } else {
                        GPTMarkdownView(normalizeOutput(message.content))
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Show pin only for final summary messages (even without output)
                    if let onToggleInclude, message.type == .summary {
                        Toggle(isOn: Binding(
                            get: { message.includeInNextPrompt },
                            set: { newVal in onToggleInclude(message.id, newVal) }
                        )) {
                            Text("В контекст следующего шага")
                        }
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Command section (if exists)
                    if let command = message.command {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "terminal")
                                    .foregroundColor(.orange)
                                Text("Command:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if message.isDangerous {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .help("This command may be dangerous")
                                }
                                
                                Spacer()
                                
                                if message.stepNumber != nil {
                                    Text("Step \(message.stepNumber!)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                // Do not show pin for command messages anymore (context only from summary)
                                if false, let onToggleInclude, message.output == nil {
                                    Toggle(isOn: Binding(
                                        get: { message.includeInNextPrompt },
                                        set: { newVal in onToggleInclude(message.id, newVal) }
                                    )) {
                                        Text("В контекст следующего шага")
                                    }
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(command)
                                .font(.system(.body, design: .monospaced))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(message.isDangerous ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(message.isDangerous ? Color.red.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(message.isDangerous ? .red : .orange)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // Output section (if exists)
                    if let output = message.output {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.purple)
                                Text("Output:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                // Show pin only for final summary messages
                                if let onToggleInclude, message.type == .summary {
                                    Toggle(isOn: Binding(
                                        get: { message.includeInNextPrompt },
                                        set: { newVal in onToggleInclude(message.id, newVal) }
                                    )) {
                                        Text("В контекст следующего шага")
                                    }
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                
                                Button(isExpanded ? "Hide" : "Show") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded.toggle()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            if isExpanded {
                                // Show full output without nested ScrollView to avoid scroll conflicts
                                Text(normalizeOutput(output))
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.purple.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.purple)
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                // Optimize: take preview slice before normalization to reduce cost
                                let rawPreview = output.prefix(120)
                                let fullPreview = String(rawPreview)
                                let displayText = normalizeOutput(fullPreview) + (output.count > rawPreview.count ? "..." : "")
                                
                                Text(displayText)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.purple.opacity(0.1))
                                    )
                                    .foregroundColor(.purple)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isExpanded.toggle()
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(message.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(message.textColor.opacity(0.2), lineWidth: 1)
                    )
            )
            
            if message.type != .user {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatMessageView(message: ChatMessage(
            type: .user,
            content: "Найди большие файлы на сервере"
        ))
        
        ChatMessageView(message: ChatMessage(
            type: .assistant,
            content: "Я помогу найти большие файлы. Сначала выполню поиск файлов больше 100MB.",
            command: "find / -type f -size +100M 2>/dev/null",
            stepNumber: 1
        ))
        
        ChatMessageView(message: ChatMessage(
            type: .output,
            content: "Найдены следующие большие файлы:",
            output: "/home/xioneer/mongodb-linux-x86_64-ubuntu2204-8.0.10/bin/mongod\n/home/xioneer/mongodb-linux-x86_64-ubuntu2204-8.0.10/bin/mongos\n/home/xioneer/.pm2/logs/logger-out.log\n/usr/local/bin/mongod\n/usr/local/bin/mongos\n/usr/bin/dockerd"
        ))
        
        ChatMessageView(message: ChatMessage(
            type: .command,
            content: "Теперь проверю размер каждого файла",
            command: "rm -rf /",
            isDangerous: true,
            stepNumber: 2
        ))
    }
    .padding()
}

private func normalizeOutput(_ text: String) -> String {
    // Remove ANSI escape sequences
    let ansiPattern = "\\u001B\\[[0-9;?]*[ -/]*[@-~]"
    let regex = try? NSRegularExpression(pattern: ansiPattern, options: [])
    var clean = text
    if let regex = regex {
        let range = NSRange(location: 0, length: (clean as NSString).length)
        clean = regex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
    }
    // Normalize CRLF/CR to LF
    clean = clean.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    return clean
}
