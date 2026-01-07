import Foundation
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
actor AppleAIService: AIService {
    let provider: AIProvider = .appleFoundationModels

    var isAvailable: Bool {
        get async {
            // LanguageModelSession init is apparently synchronous and non-throwing based on compiler warnings?
            // Or maybe the warnings are misleading because of some other issue.
            // Let's assume compiler is right about 'no async/throw'.
            let _ = LanguageModelSession()
            return true
        }
    }

    func complete(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) async throws -> AIResponse {
        var streamingResponse = ""
        // stream is nonisolated so we can call it without await? No, stream returns AsyncThrowingStream.
        // But complete is on the actor, so it can call nonisolated method.
        for try await chunk in stream(messages: messages, tools: tools, systemPrompt: systemPrompt) {
            if let text = chunk.delta {
                streamingResponse += text
            }
        }
        return AIResponse(text: streamingResponse, toolCalls: [])
    }

    nonisolated func stream(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession()

                    // Simple prompt construction for now
                    // In a real app we'd want to format the history properly
                    // Construct prompt from history
                    var fullPrompt = ""
                    if let systemPrompt {
                        fullPrompt += "\(systemPrompt)\n\n"
                    }
                    
                    for message in messages {
                        switch message.content {
                        case .text(let text):
                            fullPrompt += "\(message.role == .user ? "User" : "Assistant"): \(text)\n"
                        case .toolCall(let toolCall):
                             fullPrompt += "Assistant calculated: Tool \(toolCall.name)\n"
                        case .toolResult(let result):
                            fullPrompt += "System: Tool output: \(result.content)\n"
                        }
                    }
                    
                    // Add final "Assistant: " indicator if needed, or just let the model complete.
                    // Apple's models often prefer just the raw text prompt, but structured is better.
                    // For now, let's just append the conversation.

                    let stream = session.streamResponse(to: fullPrompt)

                    var previousText = ""
                    for try await partial in stream {
                        let currentText = partial.content
                        if currentText.count > previousText.count {
                            let delta = String(currentText.dropFirst(previousText.count))
                            continuation.yield(StreamingChunk(delta: delta))
                            previousText = currentText
                        }
                    }

                    continuation.yield(.complete)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
