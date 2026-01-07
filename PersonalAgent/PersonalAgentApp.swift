//
//  PersonalAgentApp.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI
import SwiftData

@main
struct PersonalAgentApp: App {
    // MARK: - Dependencies

    private let dataController = DataController.shared
    @State private var settingsManager = SettingsManager()
    @State private var conversationStore: ConversationStore?
    @State private var chatViewModel: ChatViewModel?

    var body: some Scene {
        WindowGroup {
            Group {
                if let conversationStore, let chatViewModel {
                    ContentView(
                        settingsManager: settingsManager,
                        chatViewModel: chatViewModel,
                        conversationStore: conversationStore
                    )
                } else {
                    ProgressView("Loading...")
                        .onAppear {
                            initializeDependencies()
                        }
                }
            }
        }
        .modelContainer(dataController.container)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    chatViewModel?.startNewConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView(settingsManager: settingsManager)
        }
        #endif
    }

    // MARK: - Initialization

    private func initializeDependencies() {
        let store = ConversationStore(modelContext: dataController.modelContext)
        self.conversationStore = store

        let toolRegistry = ToolRegistry()
        toolRegistry.registerDefaults()

        let permissionsManager = PermissionsManager()
        let toolExecutor = ToolExecutor(registry: toolRegistry, permissionsManager: permissionsManager)

        let aiServiceFactory = AIServiceFactory(settingsManager: settingsManager)
        let viewModel = ChatViewModel(
            aiServiceFactory: aiServiceFactory,
            settingsManager: settingsManager,
            conversationStore: store,
            toolRegistry: toolRegistry,
            toolExecutor: toolExecutor
        )

        self.chatViewModel = viewModel
    }
}
