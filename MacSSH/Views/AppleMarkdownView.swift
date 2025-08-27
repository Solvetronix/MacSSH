import SwiftUI
import Foundation
import AppKit

struct AppleMarkdownView: View {
    let text: String
    let language: String?
    
    init(_ text: String, language: String? = nil) {
        self.text = text
        self.language = language
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let language = language, isCodeBlock() {
                // Code block with syntax highlighting using NSTextView
                CodeBlockView(code: extractCodeContent(), language: language)
            } else {
                // Regular markdown text using AttributedString
                MarkdownTextView(text: text)
            }
        }
    }
    
    private func isCodeBlock() -> Bool {
        return text.hasPrefix("```") && text.hasSuffix("```")
    }
    
    private func extractCodeContent() -> String {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 2 else { return text }
        
        // Remove first and last lines (``` markers)
        let contentLines = Array(lines.dropFirst().dropLast())
        return contentLines.joined(separator: "\n")
    }
}

struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        // Ensure proper line breaks are preserved
        let processedText = preserveLineBreaks(text)
        
        // Check if text contains markdown formatting
        let hasMarkdown = processedText.contains("**") || processedText.contains("*") || 
                         processedText.contains("`") || processedText.contains("#") ||
                         processedText.contains("```") || processedText.contains(">")
        
        if hasMarkdown {
            // Use AttributedString for markdown parsing (force hard line breaks)
            if let attributedString = try? AttributedString(markdown: processedText) {
                Text(attributedString)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Fallback to plain text if markdown parsing fails
                Text(processedText)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            // For plain text, use simple Text view with preserved line breaks
            Text(processedText)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func preserveLineBreaks(_ text: String) -> String {
        // Normalize real CRLF/CR to LF first
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        // Replace single newlines with double newlines to ensure proper paragraph breaks
        // This ensures that line breaks are preserved in markdown rendering
        let lines = normalized.components(separatedBy: .newlines)
        let processedLines = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "" : line
        }
        
        // Join with double newlines to ensure proper paragraph separation
        let result = processedLines.joined(separator: "\n\n")
        
        // Additional processing for special characters that might interfere with markdown
        // Force hard line breaks for Markdown by adding two spaces before newline
        let hardBreaks = result.replacingOccurrences(of: "\n", with: "  \n")
        return hardBreaks
            .replacingOccurrences(of: "\\n", with: "\n") // Handle escaped newlines
            .replacingOccurrences(of: "\\t", with: "    ") // Handle tabs
            .replacingOccurrences(of: "\\r", with: "\n") // Handle carriage returns (escaped)
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Language indicator
            HStack {
                Text(language.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Code content with syntax highlighting using NSTextView
            CodeSyntaxHighlightView(code: code, language: language)
                .frame(maxHeight: 400)
        }
    }
}

struct CodeSyntaxHighlightView: NSViewRepresentable {
    let code: String
    let language: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view for code display
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        
        // Enable syntax highlighting
        textView.isRichText = true
        textView.allowsUndo = false
        
        // Set the text with syntax highlighting
        let attributedString = createHighlightedCode(code: code, language: language)
        textView.textStorage?.setAttributedString(attributedString)
        
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            let attributedString = createHighlightedCode(code: code, language: language)
            textView.textStorage?.setAttributedString(attributedString)
        }
    }
    
    private func createHighlightedCode(code: String, language: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: code)
        
        // Apply basic styling
        let fullRange = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        
        // Apply syntax highlighting based on language
        if language.lowercased() == "bash" || language.lowercased() == "shell" {
            highlightBashSyntax(attributedString)
        }
        
        return attributedString
    }
    
    private func highlightBashSyntax(_ attributedString: NSMutableAttributedString) {
        let string = attributedString.string
        
        // Commands (words at the beginning of line)
        let commandPattern = try? NSRegularExpression(pattern: #"^\w+"#, options: [.anchorsMatchLines])
        if let regex = commandPattern {
            let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold), range: match.range)
            }
        }
        
        // Options (starting with - or --)
        let optionPattern = try? NSRegularExpression(pattern: #"\s-[a-zA-Z]|--[a-zA-Z][a-zA-Z0-9-]*"#, options: [])
        if let regex = optionPattern {
            let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: match.range)
            }
        }
        
        // Paths (containing /)
        let pathPattern = try? NSRegularExpression(pattern: #"\/[^\s]+"#, options: [])
        if let regex = pathPattern {
            let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
            }
        }
        
        // Strings (quoted)
        let stringPattern = try? NSRegularExpression(pattern: #""[^"]*""#, options: [])
        if let regex = stringPattern {
            let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match.range)
            }
        }
        
        // Comments (starting with #)
        let commentPattern = try? NSRegularExpression(pattern: #"#.*"#, options: [])
        if let regex = commentPattern {
            let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range)
                attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .light), range: match.range)
            }
        }
        
        // Redirections
        let redirectPattern = try? NSRegularExpression(pattern: #"[><|]"#, options: [])
        if let regex = redirectPattern {
            let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemRed, range: match.range)
                attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .bold), range: match.range)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        AppleMarkdownView("**Задача завершена!** Успешно перешли в папку www")
        
        AppleMarkdownView("""
        ```bash
        # Find all large files
        find / -type f -size +100M 2>/dev/null | head -10
        
        # Check disk usage
        df -h | grep -E "^/dev"
        
        # List processes
        ps aux | grep "nginx"
        ```
        """, language: "bash")
        
        AppleMarkdownView("Команда `ls -la` покажет все файлы")
    }
    .padding()
}
