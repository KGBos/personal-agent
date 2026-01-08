//
//  Message.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation

enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

enum MessageContent: Codable, Sendable, Equatable {
    case text(String)
    case toolCall(ToolCall)
    case toolResult(ToolResult)

    var textValue: String? {
        if case .text(let text) = self {
            return text
        }
        return nil
    }
}

struct ToolCall: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let arguments: [String: AnyCodable]

    nonisolated init(id: String, name: String, arguments: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    nonisolated init(id: String, name: String, argumentsDict: [String: Any]) {
        self.id = id
        self.name = name
        self.arguments = argumentsDict.mapValues { AnyCodable($0) }
    }
}

struct ToolResult: Codable, Sendable, Equatable {
    let toolCallId: String
    let content: String
    let isError: Bool

    init(toolCallId: String, content: String, isError: Bool = false) {
        self.toolCallId = toolCallId
        self.content = content
        self.isError = isError
    }
}

struct Message: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: MessageContent
    let timestamp: Date
    var isStreaming: Bool

    init(id: UUID = UUID(), role: MessageRole, content: MessageContent, timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    init(role: MessageRole, text: String) {
        self.id = UUID()
        self.role = role
        self.content = .text(text)
        self.timestamp = Date()
        self.isStreaming = false
    }

    static func user(_ text: String) -> Message {
        Message(role: .user, text: text)
    }

    static func assistant(_ text: String) -> Message {
        Message(role: .assistant, text: text)
    }

    static func system(_ text: String) -> Message {
        Message(role: .system, text: text)
    }
}
