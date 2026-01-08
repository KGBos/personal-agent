//
//  ContentView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var settingsManager: SettingsManager
    @Bindable var chatViewModel: ChatViewModel
    @Bindable var conversationStore: ConversationStore
    @Bindable var tokenTracker: TokenTracker

    var body: some View {
        MainSplitView(
            settingsManager: settingsManager,
            chatViewModel: chatViewModel,
            conversationStore: conversationStore,
            tokenTracker: tokenTracker
        )
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView(settingsManager: settingsManager)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        #endif
    }
}

#Preview {
    let settingsManager = SettingsManager()
    let tokenTracker = TokenTracker()
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
        toolExecutor: toolExecutor,
        tokenTracker: tokenTracker
    )

    ContentView(
        settingsManager: settingsManager,
        chatViewModel: chatViewModel,
        conversationStore: store,
        tokenTracker: tokenTracker
    )
}
