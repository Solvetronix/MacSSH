import Foundation
import SwiftUI

enum ChatMessageType {
    case user
    case assistant
    case system
    case command
    case output
    case summary
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let type: ChatMessageType
    let content: String
    let timestamp: Date
    let command: String?
    let output: String?
    let isDangerous: Bool
    let stepNumber: Int?
    
    init(type: ChatMessageType, content: String, command: String? = nil, output: String? = nil, isDangerous: Bool = false, stepNumber: Int? = nil) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.command = command
        self.output = output
        self.isDangerous = isDangerous
        self.stepNumber = stepNumber
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var backgroundColor: Color {
        switch type {
        case .user:
            return .blue.opacity(0.1)
        case .assistant:
            return .green.opacity(0.1)
        case .system:
            return .gray.opacity(0.1)
        case .command:
            return isDangerous ? .red.opacity(0.1) : .orange.opacity(0.1)
        case .output:
            return .purple.opacity(0.1)
        case .summary:
            return .yellow.opacity(0.1)
        }
    }
    
    var textColor: Color {
        switch type {
        case .user:
            return .blue
        case .assistant:
            return .green
        case .system:
            return .gray
        case .command:
            return isDangerous ? .red : .orange
        case .output:
            return .purple
        case .summary:
            return .yellow
        }
    }
    
    var icon: String {
        switch type {
        case .user:
            return "person.circle.fill"
        case .assistant:
            return "brain.head.profile"
        case .system:
            return "gear"
        case .command:
            return isDangerous ? "exclamationmark.triangle.fill" : "terminal"
        case .output:
            return "text.alignleft"
        case .summary:
            return "checkmark.circle.fill"
        }
    }
}

// Codable conformance for ChatMessageType
extension ChatMessageType: Codable {
    enum CodingKeys: String, CodingKey {
        case user, assistant, system, command, output, summary
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .user:
            try container.encode("user")
        case .assistant:
            try container.encode("assistant")
        case .system:
            try container.encode("system")
        case .command:
            try container.encode("command")
        case .output:
            try container.encode("output")
        case .summary:
            try container.encode("summary")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "user":
            self = .user
        case "assistant":
            self = .assistant
        case "system":
            self = .system
        case "command":
            self = .command
        case "output":
            self = .output
        case "summary":
            self = .summary
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ChatMessageType")
        }
    }
}
