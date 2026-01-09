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
    @Bindable var tokenTracker: TokenTracker

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingDashboard = false

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
                .toolbar {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            showingDashboard = true
                        } label: {
                            Label("Usage", systemImage: "chart.bar")
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingDashboard) {
            NavigationStack {
                UsageDashboardView(tokenTracker: tokenTracker)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingDashboard = false
                            }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }
}

#Preview {
    let settingsManager = SettingsManager()
    let tokenTracker = TokenTracker()
    let dataController = DataController.preview
    let store = ConversationStore(modelContext: dataController.modelContext)
    let toolRegistry = ToolRegistry()
    let permissionsManager = PermissionsManager.shared
    let toolExecutor = ToolExecutor(registry: toolRegistry, permissionsManager: permissionsManager)

    let chatViewModel = ChatViewModel(
        aiServiceFactory: AIServiceFactory(settingsManager: settingsManager),
        settingsManager: settingsManager,
        conversationStore: store,
        toolRegistry: toolRegistry,
        toolExecutor: toolExecutor,
        tokenTracker: tokenTracker
    )

    MainSplitView(
        settingsManager: settingsManager,
        chatViewModel: chatViewModel,
        conversationStore: store,
        tokenTracker: tokenTracker
    )
}
