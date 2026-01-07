//
//  ConversationModel.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation
import SwiftData

@Model
final class ConversationModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var providerRawValue: String

    @Relationship(deleteRule: .cascade, inverse: \MessageModel.conversation)
    var messages: [MessageModel] = []

    var provider: AIProvider {
        get { AIProvider(rawValue: providerRawValue) ?? .openAI }
        set { providerRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        provider: AIProvider = .openAI
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.providerRawValue = provider.rawValue
    }

    func updateTimestamp() {
        updatedAt = Date()
    }

    func generateTitle(from messages: [Message]) {
        // Use first user message as title, truncated
        if let firstUserMessage = messages.first(where: { $0.role == .user }),
           case .text(let text) = firstUserMessage.content {
            let truncated = String(text.prefix(50))
            title = truncated.count < text.count ? "\(truncated)..." : truncated
        }
    }
}
