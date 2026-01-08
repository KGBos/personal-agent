//
//  ChatViewModel.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [Message] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var streamingText: String = ""
    var error: AIError?
    var pendingToolCalls: [ToolCall] = []

    // Image Playground state
    var showingImagePlayground: Bool = false
    var imagePlaygroundPrompt: String = ""

    // Internal state for tool call assembly
    private var toolCallDeltas: [Int: (id: String?, name: String?, arguments: String)] = [:]

    // MARK: - Conversation State

    private(set) var currentConversation: ConversationModel?

    // MARK: - Dependencies

    private let aiServiceFactory: AIServiceFactory
    let settingsManager: SettingsManager
    private let conversationStore: ConversationStore
    private let toolRegistry: ToolRegistry
    private let toolExecutor: ToolExecutor
    let tokenTracker: TokenTracker

    // MARK: - Private State

    private var streamingTask: Task<Void, Never>?
    private var autoSaveTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        aiServiceFactory: AIServiceFactory,
        settingsManager: SettingsManager,
        conversationStore: ConversationStore,
        toolRegistry: ToolRegistry,
        toolExecutor: ToolExecutor,
        tokenTracker: TokenTracker
    ) {
        self.aiServiceFactory = aiServiceFactory
        self.settingsManager = settingsManager
        self.conversationStore = conversationStore
        self.toolRegistry = toolRegistry
        self.toolExecutor = toolExecutor
        self.tokenTracker = tokenTracker
    }

    // MARK: - Computed Properties

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var hasAPIKey: Bool {
        settingsManager.hasOpenAIAPIKey
    }

    var currentProvider: AIProvider {
        settingsManager.selectedProvider
    }

    var conversationTitle: String {
        currentConversation?.title ?? "New Conversation"
    }

    // MARK: - Conversation Management

    func loadConversation(_ conversation: ConversationModel) {
        cancelGeneration()
        currentConversation = conversation
        messages = conversationStore.loadMessages(for: conversation)
        error = nil
    }

    func startNewConversation() {
        cancelGeneration()
        saveCurrentConversation()

        currentConversation = nil
        messages.removeAll()
        error = nil
    }

    // MARK: - Actions

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        error = nil

        // Create conversation if needed
        if currentConversation == nil {
            currentConversation = conversationStore.createConversation(
                provider: settingsManager.selectedProvider
            )
        }

        let userMessage = Message.user(text)
        messages.append(userMessage)

        // Save after adding user message
        saveCurrentConversation()

        generateResponse()
    }

    func cancelGeneration() {
        streamingTask?.cancel()
        streamingTask = nil
        isLoading = false

        if !streamingText.isEmpty {
            messages.append(Message.assistant(streamingText))
            streamingText = ""
            saveCurrentConversation()
        }
    }

    func clearConversation() {
        cancelGeneration()

        if let conversation = currentConversation {
            conversationStore.deleteConversation(conversation)
        }

        currentConversation = nil
        messages.removeAll()
        error = nil
    }

    func dismissError() {
        error = nil
    }

    func regenerateLastResponse() {
        guard !isLoading, let lastMessage = messages.last, lastMessage.role == .assistant else { return }

        // Remove last assistant message
        messages.removeLast()
        saveCurrentConversation()

        // Re-generate response
        generateResponse()
    }

    // MARK: - Persistence

    func saveCurrentConversation() {
        guard let conversation = currentConversation, !messages.isEmpty else { return }
        conversationStore.updateConversation(conversation, with: messages)
    }

    // MARK: - Response Generation

    private func generateResponse() {
        isLoading = true
        streamingText = ""
        error = nil

        let aiService = aiServiceFactory.currentService()
        var systemPrompt = settingsManager.systemPrompt
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        systemPrompt += "\n\nCurrent Date: \(dateFormatter.string(from: Date()))"

        streamingTask = Task {
            do {
                let tools = await toolRegistry.tools
                var lastUsage: ResponseUsage?

                for try await chunk in aiService.stream(messages: messages, tools: tools, systemPrompt: systemPrompt) {
                    if Task.isCancelled { break }

                    if let delta = chunk.delta {
                        streamingText += delta
                    }

                    if let toolDelta = chunk.toolCallDelta {
                        processToolCallDelta(toolDelta)
                    }

                    // Capture usage from final chunk
                    if let usage = chunk.usage {
                        lastUsage = usage
                    }

                    if chunk.isComplete {
                        // Record token usage if available
                        if let usage = lastUsage {
                            tokenTracker.record(
                                promptTokens: usage.promptTokens,
                                completionTokens: usage.completionTokens,
                                model: usage.model.isEmpty ? settingsManager.openAIModel : usage.model
                            )
                        }
                        finalizeResponse()
                        break
                    }
                }
            } catch {
                handleError(error)
            }

            isLoading = false
        }
    }

    private func processToolCallDelta(_ delta: ToolCallDelta) {
        var current = toolCallDeltas[delta.index] ?? (id: nil, name: nil, arguments: "")
        
        if let id = delta.id { current.id = id }
        if let name = delta.name { current.name = name }
        current.arguments += delta.argumentsDelta
        
        toolCallDeltas[delta.index] = current
    }

    private func finalizeResponse() {
        // Assemble tool calls
        let assembledToolCalls = toolCallDeltas.values.compactMap { delta -> ToolCall? in
            guard let id = delta.id, let name = delta.name else { return nil }
            return ToolCall(id: id, name: name, argumentsDict: decodeArguments(delta.arguments))
        }
        
        toolCallDeltas = [:]

        if !assembledToolCalls.isEmpty {
            let assistantMessage = Message(
                role: .assistant,
                content: assembledToolCalls.count == 1 && (streamingText.isEmpty) ? 
                    .toolCall(assembledToolCalls[0]) : 
                    .text(streamingText) // Simplify: If multiple or mixed, we might need a richer message type, but roadmap says one tool call at a time mostly
            )
            
            // For now, if we have tool calls, we add them
            if assembledToolCalls.count == 1 {
                messages.append(Message(role: .assistant, content: .toolCall(assembledToolCalls[0])))
                processAssembledToolCall(assembledToolCalls[0])
            } else {
                // Handle multiple tool calls if needed, but OpenAI usually sends them one by one or in a batch
                for call in assembledToolCalls {
                    messages.append(Message(role: .assistant, content: .toolCall(call)))
                    processAssembledToolCall(call)
                }
            }
            
            streamingText = ""
            saveCurrentConversation()
            return
        }

        guard !streamingText.isEmpty else { return }
        messages.append(Message.assistant(streamingText))
        streamingText = ""
        saveCurrentConversation()
    }

    private func decodeArguments(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func processAssembledToolCall(_ toolCall: ToolCall) {
        Task {
            let tool = await toolRegistry.tool(named: toolCall.name)
            if tool?.requiresConfirmation == true {
                pendingToolCalls.append(toolCall)
            } else {
                await executeTool(toolCall)
            }
        }
    }

    func confirmToolExecution(_ toolCall: ToolCall) async {
        pendingToolCalls.removeAll { $0.id == toolCall.id }
        await executeTool(toolCall)
    }

    func rejectToolExecution(_ toolCall: ToolCall) {
        pendingToolCalls.removeAll { $0.id == toolCall.id }
        
        let toolResultMessage = Message(
            role: .tool,
            content: .toolResult(ToolResult(
                toolCallId: toolCall.id,
                content: "Tool execution was rejected by the user.",
                isError: true
            ))
        )
        messages.append(toolResultMessage)
        saveCurrentConversation()
        
        // Re-generate to let AI respond to the rejection
        generateResponse()
    }

    private func executeTool(_ toolCall: ToolCall) async {
        // Special handling for image generation tool
        if toolCall.name == "generate_image" {
            if let prompt = toolCall.arguments["prompt"]?.value as? String {
                imagePlaygroundPrompt = prompt
                showingImagePlayground = true

                // Add a message indicating Image Playground is opening
                let toolResultMessage = Message(
                    role: .tool,
                    content: .toolResult(ToolResult(
                        toolCallId: toolCall.id,
                        content: "Opening Image Playground with prompt: \"\(prompt)\". Please generate and save your image.",
                        isError: false
                    ))
                )
                messages.append(toolResultMessage)
                saveCurrentConversation()
                return
            }
        }

        let result = await toolExecutor.execute(toolCall: toolCall)

        let toolResultMessage = Message(
            role: .tool,
            content: .toolResult(ToolResult(
                toolCallId: result.toolCallId,
                content: result.result,
                isError: result.isError
            ))
        )

        messages.append(toolResultMessage)
        saveCurrentConversation()

        // Continue generation after tool execution
        generateResponse()
    }

    // MARK: - Image Playground

    func handleImagePlaygroundResult(_ imageURL: URL?) {
        showingImagePlayground = false

        if let imageURL = imageURL {
            // Add message about saved image
            let message = Message.assistant("Image saved to: \(imageURL.path)")
            messages.append(message)
            saveCurrentConversation()
        }

        // Continue the conversation
        generateResponse()
    }

    private func handleError(_ error: Error) {
        if let aiError = error as? AIError {
            self.error = aiError
        } else {
            self.error = .unknown(error)
        }

        // If we have partial streaming text, save it
        if !streamingText.isEmpty {
            messages.append(Message.assistant(streamingText))
            streamingText = ""
            saveCurrentConversation()
        }
    }
}
