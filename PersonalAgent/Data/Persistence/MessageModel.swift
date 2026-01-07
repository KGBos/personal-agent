//
//  MessageModel.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation
import SwiftData

@Model
final class MessageModel {
    @Attribute(.unique) var id: UUID
    var roleRawValue: String
    var contentType: String
    var textContent: String?
    var toolCallJSON: Data?
    var toolResultJSON: Data?
    var timestamp: Date
    var sortOrder: Int

    var conversation: ConversationModel?

    var role: MessageRole {
        get { MessageRole(rawValue: roleRawValue) ?? .user }
        set { roleRawValue = newValue.rawValue }
    }

    init(from message: Message, sortOrder: Int = 0) {
        self.id = message.id
        self.roleRawValue = message.role.rawValue
        self.timestamp = message.timestamp
        self.sortOrder = sortOrder

        switch message.content {
        case .text(let text):
            self.contentType = "text"
            self.textContent = text
        case .toolCall(let call):
            self.contentType = "toolCall"
            self.toolCallJSON = try? JSONEncoder().encode(call)
        case .toolResult(let result):
            self.contentType = "toolResult"
            self.toolResultJSON = try? JSONEncoder().encode(result)
        }
    }

    func toMessage() -> Message? {
        let content: MessageContent
        switch contentType {
        case "text":
            content = .text(textContent ?? "")
        case "toolCall":
            guard let data = toolCallJSON,
                  let call = try? JSONDecoder().decode(ToolCall.self, from: data) else {
                return nil
            }
            content = .toolCall(call)
        case "toolResult":
            guard let data = toolResultJSON,
                  let result = try? JSONDecoder().decode(ToolResult.self, from: data) else {
                return nil
            }
            content = .toolResult(result)
        default:
            return nil
        }

        return Message(
            id: id,
            role: role,
            content: content,
            timestamp: timestamp,
            isStreaming: false
        )
    }
}
