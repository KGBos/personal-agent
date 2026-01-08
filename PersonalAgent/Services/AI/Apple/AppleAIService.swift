import Foundation
import FoundationModels

// MARK: - Apple AI Service

/// AI Service implementation using Apple's Foundation Models framework.
/// Uses prompt-based tool calling where the model outputs JSON when it needs to use tools.
@available(macOS 26.0, iOS 26.0, *)
actor AppleAIService: AIService {
    let provider: AIProvider = .appleFoundationModels

    var isAvailable: Bool {
        get async {
            // Check if device supports Apple Intelligence
            do {
                _ = LanguageModelSession()
                return true
            } catch {
                return false
            }
        }
    }

    func complete(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) async throws -> AIResponse {
        var streamingResponse = ""
        var toolCalls: [ToolCall] = []

        for try await chunk in stream(messages: messages, tools: tools, systemPrompt: systemPrompt) {
            if let text = chunk.delta {
                streamingResponse += text
            }
            if let toolDelta = chunk.toolCallDelta, let id = toolDelta.id, let name = toolDelta.name {
                if toolCalls.firstIndex(where: { $0.id == id }) == nil {
                    var args: [String: AnyCodable] = [:]
                    if let data = toolDelta.argumentsDelta.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        for (key, value) in dict {
                            args[key] = AnyCodable(value)
                        }
                    }
                    let toolCall = ToolCall(id: id, name: name, argumentsDict: dict(from: args))
                    toolCalls.append(toolCall)
                }
            }
        }

        let finishReason: AIResponse.FinishReason = toolCalls.isEmpty ? .complete : .toolCall
        return AIResponse(text: streamingResponse, toolCalls: toolCalls, finishReason: finishReason)
    }

    private func dict(from args: [String: AnyCodable]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in args {
            result[key] = value.value
        }
        return result
    }

    nonisolated func stream(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build system instructions
                    var instructions = systemPrompt ?? ""

                    // Add tool instructions if tools are available
                    if !tools.isEmpty {
                        instructions += "\n\n" + buildToolInstructions(for: tools)
                    }

                    // Create session with instructions
                    let session = LanguageModelSession(instructions: instructions)

                    // Build the prompt from message history
                    let prompt = buildPrompt(from: messages)

                    // Stream the response
                    let responseStream = session.streamResponse(to: prompt)

                    var previousText = ""
                    var accumulatedText = ""

                    for try await partial in responseStream {
                        // Get the current text content
                        let currentText = String(describing: partial)

                        if currentText.count > previousText.count {
                            let delta = String(currentText.dropFirst(previousText.count))
                            accumulatedText += delta
                            continuation.yield(StreamingChunk(delta: delta))
                            previousText = currentText
                        }
                    }

                    // After streaming completes, check if the response contains tool calls
                    let toolCalls = Self.parseToolCalls(from: accumulatedText)
                    for toolCall in toolCalls {
                        let delta = ToolCallDelta(
                            index: 0,
                            id: toolCall.id,
                            name: toolCall.name,
                            argumentsDelta: formatArguments(toolCall.arguments)
                        )
                        continuation.yield(StreamingChunk(toolCallDelta: delta))
                    }

                    continuation.yield(StreamingChunk(isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapToAIError(error))
                }
            }
        }
    }

    // MARK: - Tool Instructions (Prompt-Based Tool Calling)

    private nonisolated func buildToolInstructions(for tools: [any AgentTool]) -> String {
        var instructions = """
        You have access to the following tools. To use a tool, output a JSON block in this exact format:

        ```tool
        {
          "tool": "tool_name",
          "arguments": { ... }
        }
        ```

        Available tools:

        """

        for tool in tools {
            instructions += "\n## \(tool.name)\n"
            instructions += "\(tool.description)\n"
            if let props = tool.parameterSchema.properties {
                instructions += "Parameters:\n"
                for (key, prop) in props {
                    let required = tool.parameterSchema.required?.contains(key) == true ? " (required)" : ""
                    instructions += "- \(key) (\(prop.type))\(required): \(prop.description ?? "")\n"
                }
            }
        }

        instructions += """

        IMPORTANT: Only output the tool JSON block when you need to use a tool.
        After receiving tool results, incorporate them into your response naturally.
        """

        return instructions
    }

    // MARK: - Tool Call Parsing

    static nonisolated func parseToolCalls(from text: String) -> [ToolCall] {
        var toolCalls: [ToolCall] = []
        let lines = text.components(separatedBy: .newlines)
        var insideBlock = false
        var currentBlock = ""
        var blockType: BlockType?
        
        enum BlockType {
            case tool
            case json
            case unknown
        }

        // Scan for potential tool blocks
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("```") {
                if insideBlock {
                    // End of block
                    if let type = blockType, (type == .tool || type == .json || type == .unknown) {
                        if let toolCall = tryParseToolCall(from: currentBlock) {
                            toolCalls.append(toolCall)
                        }
                    }
                    insideBlock = false
                    currentBlock = ""
                    blockType = nil
                } else {
                    // Start of block
                    insideBlock = true
                    if trimmed.contains("tool") {
                        blockType = .tool
                    } else if trimmed.contains("json") {
                        blockType = .json
                    } else {
                        blockType = .unknown
                    }
                }
                continue
            }
            
            if insideBlock {
                currentBlock += line + "\n"
            }
        }
        
        // If no markdown blocks were found, or we want to be very aggressive, 
        // we could try to find standalone JSON objects, but for now we'll stick to 
        // improving the markdown block parsing as per the plan.
        
        // Fallback: If no tools found, check if the entire text looks like a JSON object 
        // and contains "tool" key, in case model forgot markdown fences.
        if toolCalls.isEmpty {
            if let toolCall = tryParseToolCall(from: text) {
                toolCalls.append(toolCall)
            }
        }

        return toolCalls
    }
    
    private static func tryParseToolCall(from jsonString: String) -> ToolCall? {
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.hasPrefix("{") && cleaned.hasSuffix("}") else { return nil }
        
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Check for required fields
        guard let toolName = json["tool"] as? String else { return nil }
        
        // Arguments might be missing or empty
        let arguments = json["arguments"] as? [String: Any] ?? [:]
        
        return ToolCall(
            id: "apple-\(UUID().uuidString.prefix(8))",
            name: toolName,
            argumentsDict: arguments
        )
    }

    // MARK: - Private Helpers

    private nonisolated func buildPrompt(from messages: [Message]) -> String {
        var prompt = ""

        for message in messages {
            switch message.content {
            case .text(let text):
                switch message.role {
                case .user:
                    prompt += "User: \(text)\n\n"
                case .assistant:
                    prompt += "Assistant: \(text)\n\n"
                case .system:
                    prompt += "System: \(text)\n\n"
                case .tool:
                    prompt += "Tool Result: \(text)\n\n"
                }
            case .toolCall(let toolCall):
                prompt += "Assistant called tool: \(toolCall.name) with arguments: \(formatArguments(toolCall.arguments))\n\n"
            case .toolResult(let result):
                if result.isError {
                    prompt += "Tool Error: \(result.content)\n\n"
                } else {
                    prompt += "Tool Result: \(result.content)\n\n"
                }
            }
        }

        return prompt
    }

    private nonisolated func formatArguments(_ args: [String: AnyCodable]) -> String {
        var dict: [String: Any] = [:]
        for (key, value) in args {
            dict[key] = value.value
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return String(describing: args)
    }

    private nonisolated func mapToAIError(_ error: Error) -> AIError {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            return .networkError(error)
        }

        let errorDescription = error.localizedDescription.lowercased()
        if errorDescription.contains("not available") || errorDescription.contains("unavailable") {
            return .serviceUnavailable
        }
        if errorDescription.contains("cancel") {
            return .cancelled
        }

        return .unknown(error)
    }
}

// MARK: - Fallback for older OS versions

struct AppleAIServiceUnavailable: AIService {
    let provider: AIProvider = .appleFoundationModels

    var isAvailable: Bool {
        get async { false }
    }

    func complete(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) async throws -> AIResponse {
        throw AIError.serviceUnavailable
    }

    func stream(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.serviceUnavailable)
        }
    }
}
