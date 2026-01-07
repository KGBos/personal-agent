//
//  AIService.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation

/// Response from AI that may include text and/or tool calls
struct AIResponse: Sendable {
    let text: String?
    let toolCalls: [ToolCall]
    let finishReason: FinishReason

    enum FinishReason: Sendable {
        case complete
        case toolCall
        case maxTokens
        case cancelled
    }

    init(text: String?, toolCalls: [ToolCall] = [], finishReason: FinishReason = .complete) {
        self.text = text
        self.toolCalls = toolCalls
        self.finishReason = finishReason
    }
}

/// Streaming chunk during response generation
struct StreamingChunk: Sendable {
    let delta: String?
    let toolCallDelta: ToolCallDelta?
    let isComplete: Bool

    init(delta: String? = nil, toolCallDelta: ToolCallDelta? = nil, isComplete: Bool = false) {
        self.delta = delta
        self.toolCallDelta = toolCallDelta
        self.isComplete = isComplete
    }

    static var complete: StreamingChunk {
        StreamingChunk(isComplete: true)
    }
}

/// Partial tool call data during streaming
struct ToolCallDelta: Sendable {
    let index: Int
    let id: String?
    let name: String?
    let argumentsDelta: String

    init(index: Int, id: String? = nil, name: String? = nil, argumentsDelta: String = "") {
        self.index = index
        self.id = id
        self.name = name
        self.argumentsDelta = argumentsDelta
    }
}

/// Main protocol for AI service providers
protocol AIService: Sendable {
    /// Provider identifier
    var provider: AIProvider { get }

    /// Check if the service is available and configured
    var isAvailable: Bool { get async }

    /// Send messages and get a complete response
    func complete(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) async throws -> AIResponse

    /// Stream response chunks
    func stream(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamingChunk, Error>
}

/// Factory for creating AI services
@MainActor
protocol AIServiceFactoryProtocol {
    func createService(for provider: AIProvider) -> any AIService
    func currentService() -> any AIService
}
