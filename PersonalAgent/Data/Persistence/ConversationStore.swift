//
//  ConversationStore.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ConversationStore {
    private let modelContext: ModelContext

    var conversations: [ConversationModel] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchConversations()
    }

    // MARK: - Fetch

    func fetchConversations() {
        let descriptor = FetchDescriptor<ConversationModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            conversations = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch conversations: \(error)")
            conversations = []
        }
    }

    // MARK: - Create

    func createConversation(provider: AIProvider = .openAI) -> ConversationModel {
        let conversation = ConversationModel(provider: provider)
        modelContext.insert(conversation)
        save()
        fetchConversations()
        return conversation
    }

    // MARK: - Update

    func updateConversation(_ conversation: ConversationModel, with messages: [Message]) {
        // Clear existing messages
        for existingMessage in conversation.messages {
            modelContext.delete(existingMessage)
        }

        // Add new messages
        for (index, message) in messages.enumerated() {
            let messageModel = MessageModel(from: message, sortOrder: index)
            messageModel.conversation = conversation
            modelContext.insert(messageModel)
        }

        // Update title if needed
        if conversation.title == "New Conversation" {
            conversation.generateTitle(from: messages)
        }

        conversation.updateTimestamp()
        save()
        fetchConversations()
    }

    func renameConversation(_ conversation: ConversationModel, to title: String) {
        conversation.title = title
        conversation.updateTimestamp()
        save()
        fetchConversations()
    }

    // MARK: - Delete

    func deleteConversation(_ conversation: ConversationModel) {
        modelContext.delete(conversation)
        save()
        fetchConversations()
    }

    func deleteAllConversations() {
        for conversation in conversations {
            modelContext.delete(conversation)
        }
        save()
        fetchConversations()
    }

    // MARK: - Load Messages

    func loadMessages(for conversation: ConversationModel) -> [Message] {
        let sortedMessages = conversation.messages.sorted { $0.sortOrder < $1.sortOrder }
        return sortedMessages.compactMap { $0.toMessage() }
    }

    // MARK: - Save

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
