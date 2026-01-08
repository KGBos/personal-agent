//
//  ChatView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI
#if canImport(ImagePlayground)
import ImagePlayground
#endif

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground

    var body: some View {
        @Bindable var imageGenHandler = viewModel.imageGenerationHandler

        return VStack(spacing: 0) {
            // Messages List
            messagesScrollView

            // Error Banner
            if let error = viewModel.error {
                ErrorBanner(
                    error: error,
                    onDismiss: { viewModel.dismissError() },
                    onRetry: { viewModel.retryLastAction() }
                )
            }

            Divider()

            // Input Area
            if viewModel.hasAPIKey {
                MessageInputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    onSend: { viewModel.sendMessage() },
                    onCancel: { viewModel.cancelGeneration() }
                )
                .focused($isInputFocused)
                .padding()
            } else {
                apiKeyPrompt
            }
        }
        .onAppear {
            isInputFocused = true
        }
        #if canImport(ImagePlayground)
        .imagePlaygroundSheet(
            isPresented: $imageGenHandler.isPresented,
            concepts: [.text(imageGenHandler.prompt)]
        ) { url in
            imageGenHandler.handleResult(url)
        }
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                ModelSelectorView(settingsManager: viewModel.settingsManager)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.clearConversation()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .disabled(viewModel.messages.isEmpty && !viewModel.isLoading)
            }
        }
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                onRegenerate: (message.id == viewModel.messages.last?.id && message.role == .assistant) ? {
                                    viewModel.retryLastAction()
                                } : nil
                            )
                            .id(message.id)
                        }

                        // Streaming text
                        if !viewModel.streamingText.isEmpty {
                            StreamingMessageView(text: viewModel.streamingText)
                                .id("streaming")
                        }

                        // Pending tool calls
                        ForEach(viewModel.pendingToolCalls) { toolCall in
                            ToolConfirmationView(
                                toolCall: toolCall,
                                onConfirm: {
                                    Task { await viewModel.confirmToolExecution(toolCall) }
                                },
                                onReject: {
                                    viewModel.rejectToolExecution(toolCall)
                                }
                            )
                            .id(toolCall.id)
                        }

                        // Loading indicator
                        if viewModel.isLoading && viewModel.streamingText.isEmpty && viewModel.pendingToolCalls.isEmpty {
                            TypingIndicatorView()
                                .id("loading")
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                scrollToBottom(proxy: proxy, anchor: .bottom)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, anchor: UnitPoint = .bottom) {
        withAnimation(.easeOut(duration: 0.2)) {
            if !viewModel.streamingText.isEmpty {
                proxy.scrollTo("streaming", anchor: anchor)
            } else if viewModel.isLoading {
                proxy.scrollTo("loading", anchor: anchor)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: anchor)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Start a conversation")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Ask me anything or tell me to help you with tasks.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - API Key Prompt

    private var apiKeyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title)
                .foregroundStyle(.orange)

            Text("OpenAI API Key Required")
                .font(.headline)

            Text("Please add your API key in Settings to start chatting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Previews

#Preview {
    let settingsManager = SettingsManager()
    let tokenTracker = TokenTracker()
    let dataController = DataController.preview
    let store = ConversationStore(modelContext: dataController.modelContext)
    let toolRegistry = ToolRegistry()
    let permissionsManager = PermissionsManager()
    let toolExecutor = ToolExecutor(registry: toolRegistry, permissionsManager: permissionsManager)

    ChatView(viewModel: ChatViewModel(
        aiServiceFactory: AIServiceFactory(settingsManager: settingsManager),
        settingsManager: settingsManager,
        conversationStore: store,
        toolRegistry: toolRegistry,
        toolExecutor: toolExecutor,
        tokenTracker: tokenTracker
    ))
}
