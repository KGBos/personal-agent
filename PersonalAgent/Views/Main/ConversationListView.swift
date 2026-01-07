//
//  ConversationListView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct ConversationListView: View {
    @Bindable var conversationStore: ConversationStore
    @Bindable var chatViewModel: ChatViewModel
    @Bindable var settingsManager: SettingsManager
    @State private var searchText = ""
    @State private var showSettings = false

    var body: some View {
        List(selection: Binding(
            get: { chatViewModel.currentConversation?.id },
            set: { id in
                if let id, let conversation = conversationStore.conversations.first(where: { $0.id == id }) {
                    chatViewModel.loadConversation(conversation)
                }
            }
        )) {
            ForEach(filteredConversations) { conversation in
                ConversationRow(conversation: conversation)
                    .tag(conversation.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deleteConversation(conversation)
                        }
                    }
            }
            .onDelete(perform: deleteConversations)
        }
        .searchable(text: $searchText, prompt: "Search conversations")
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    
                    Button {
                        chatViewModel.startNewConversation()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settingsManager: settingsManager)
        }
        .overlay {
            if conversationStore.conversations.isEmpty {
                ContentUnavailableView {
                    Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Start a new conversation to get started.")
                }
            }
        }
    }

    private var filteredConversations: [ConversationModel] {
        if searchText.isEmpty {
            return conversationStore.conversations
        }
        return conversationStore.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func deleteConversation(_ conversation: ConversationModel) {
        if chatViewModel.currentConversation?.id == conversation.id {
            chatViewModel.startNewConversation()
        }
        conversationStore.deleteConversation(conversation)
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = filteredConversations[index]
            deleteConversation(conversation)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: conversation.provider.iconName)
                    .font(.caption2)

                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let settingsManager = SettingsManager()
    let dataController = DataController.preview
    let store = ConversationStore(modelContext: dataController.modelContext)
    let toolRegistry = ToolRegistry()
    let permissionsManager = PermissionsManager()
    let toolExecutor = ToolExecutor(registry: toolRegistry, permissionsManager: permissionsManager)
    
    ConversationListView(
        conversationStore: store,
        chatViewModel: ChatViewModel(
            aiServiceFactory: AIServiceFactory(settingsManager: settingsManager),
            settingsManager: settingsManager,
            conversationStore: store,
            toolRegistry: toolRegistry,
            toolExecutor: toolExecutor
        ),
        settingsManager: settingsManager
    )
}
