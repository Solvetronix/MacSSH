import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
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
                    AppleMarkdownView(message.content)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                    
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
                                
                                Button(isExpanded ? "Hide" : "Show") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded.toggle()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            if isExpanded {
                                ScrollView {
                                    Text(output)
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
                                }
                                .frame(maxHeight: 300)
                            } else {
                                Text(output.prefix(100) + (output.count > 100 ? "..." : ""))
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.purple.opacity(0.1))
                                    )
                                    .foregroundColor(.purple)
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
