//
//  MainSplitView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct MainSplitView: View {
    @Bindable var settingsManager: SettingsManager
    @Bindable var chatViewModel: ChatViewModel
    @Bindable var conversationStore: ConversationStore

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            ConversationListView(
                conversationStore: conversationStore,
                chatViewModel: chatViewModel,
                settingsManager: settingsManager
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            // Main Content
            ChatView(viewModel: chatViewModel)
                .navigationTitle(chatViewModel.conversationTitle)
                #if os(macOS)
                .navigationSubtitle(settingsManager.selectedProvider.displayName)
                #endif
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    let settingsManager = SettingsManager()
    let dataController = DataController.preview
    let store = ConversationStore(modelContext: dataController.modelContext)
    let toolRegistry = ToolRegistry()
    let permissionsManager = PermissionsManager()
    let toolExecutor = ToolExecutor(registry: toolRegistry, permissionsManager: permissionsManager)
    
    let chatViewModel = ChatViewModel(
        aiServiceFactory: AIServiceFactory(settingsManager: settingsManager),
        settingsManager: settingsManager,
        conversationStore: store,
        toolRegistry: toolRegistry,
        toolExecutor: toolExecutor
    )

    MainSplitView(
        settingsManager: settingsManager,
        chatViewModel: chatViewModel,
        conversationStore: store
    )
}
