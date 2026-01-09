//
//  OpenAIService.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation

actor OpenAIService: AIService {
    let provider: AIProvider = .openAI

    private let apiKey: String
    private let baseURL: URL
    private let model: String
    private let urlSession: URLSession

    init(apiKey: String, model: String = "gpt-4o", baseURL: URL? = nil) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL ?? URL(string: "https://api.openai.com/v1")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config)
    }

    var isAvailable: Bool {
        get async { !apiKey.isEmpty }
    }

    // MARK: - Complete (Non-Streaming)

    func complete(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) async throws -> AIResponse {
        let request = try buildRequest(messages: messages, tools: tools, systemPrompt: systemPrompt, stream: false)
        let (data, response) = try await urlSession.data(for: request)

        try validateResponse(response, data: data)

        return try parseCompletionResponse(data)
    }

    // MARK: - Stream

    nonisolated func stream(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try await buildRequest(messages: messages, tools: tools, systemPrompt: systemPrompt, stream: true)
                    let (bytes, response) = try await urlSession.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIError.invalidResponse
                    }

                    guard httpResponse.statusCode == 200 else {
                        throw AIError.apiError(statusCode: httpResponse.statusCode, message: nil)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.yield(StreamingChunk(isComplete: true))
                            break
                        }

                        if let chunk = try await parseSSELine(line) {
                            continuation.yield(chunk)
                            if chunk.isComplete {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    if Task.isCancelled {
                        continuation.finish(throwing: AIError.cancelled)
                    } else {
                        continuation.finish(throwing: mapError(error))
                    }
                }
            }
        }
    }

    // MARK: - Request Building

    private func buildRequest(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "messages": buildMessages(messages, systemPrompt: systemPrompt),
            "stream": stream
        ]

        // Request usage info for streaming responses
        if stream {
            body["stream_options"] = ["include_usage": true]
        }

        if !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.definition.name,
                        "description": tool.definition.description,
                        "parameters": tool.definition.parameters.toDictionary()
                    ]
                ]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildMessages(_ messages: [Message], systemPrompt: String?) -> [[String: Any]] {
        var result: [[String: Any]] = []

        if let systemPrompt, !systemPrompt.isEmpty {
            result.append(["role": "system", "content": systemPrompt])
        }

        for message in messages {
            switch message.content {
            case .text(let text):
                result.append(["role": message.role.rawValue, "content": text])

            case .toolCall(let call):
                let argumentsJSON: String
                if let data = try? JSONSerialization.data(withJSONObject: call.arguments.mapValues(\.value)),
                   let str = String(data: data, encoding: .utf8) {
                    argumentsJSON = str
                } else {
                    argumentsJSON = "{}"
                }

                result.append([
                    "role": "assistant",
                    "tool_calls": [[
                        "id": call.id,
                        "type": "function",
                        "function": [
                            "name": call.name,
                            "arguments": argumentsJSON
                        ]
                    ]]
                ])

            case .toolResult(let toolResult):
                result.append([
                    "role": "tool",
                    "tool_call_id": toolResult.toolCallId,
                    "content": toolResult.content
                ])
            }
        }

        return result
    }

    // MARK: - Response Parsing

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data)
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return String(data: data, encoding: .utf8)
        }
        return message
    }

    private func parseCompletionResponse(_ data: Data) throws -> AIResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AIError.invalidResponse
        }

        let text = message["content"] as? String
        let finishReason = parseFinishReason(firstChoice["finish_reason"] as? String)

        var toolCalls: [ToolCall] = []
        if let toolCallsArray = message["tool_calls"] as? [[String: Any]] {
            toolCalls = toolCallsArray.compactMap { parseToolCall($0) }
        }

        // Parse usage info
        let usage = parseUsage(from: json)

        return AIResponse(text: text, toolCalls: toolCalls, finishReason: finishReason, usage: usage)
    }

    private func parseUsage(from json: [String: Any]) -> ResponseUsage? {
        guard let usage = json["usage"] as? [String: Any],
              let promptTokens = usage["prompt_tokens"] as? Int,
              let completionTokens = usage["completion_tokens"] as? Int else {
            return nil
        }

        let totalTokens = usage["total_tokens"] as? Int ?? (promptTokens + completionTokens)
        return ResponseUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            model: model
        )
    }

    private func parseToolCall(_ dict: [String: Any]) -> ToolCall? {
        guard let id = dict["id"] as? String,
              let function = dict["function"] as? [String: Any],
              let name = function["name"] as? String else {
            return nil
        }

        let argumentsString = function["arguments"] as? String ?? "{}"
        guard let argumentsData = argumentsString.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            return ToolCall(id: id, name: name, argumentsDict: [:])
        }

        return ToolCall(id: id, name: name, argumentsDict: arguments)
    }

    private func parseFinishReason(_ reason: String?) -> AIResponse.FinishReason {
        switch reason {
        case "stop": return .complete
        case "tool_calls": return .toolCall
        case "length": return .maxTokens
        default: return .complete
        }
    }

    // MARK: - SSE Parsing

    private func parseSSELine(_ line: String) throws -> StreamingChunk? {
        // Skip empty lines and comments
        guard !line.isEmpty, !line.hasPrefix(":") else {
            return nil
        }

        // Handle "data: " prefix
        guard line.hasPrefix("data: ") else {
            return nil
        }

        let jsonString = String(line.dropFirst(6))

        // Handle stream end marker
        if jsonString == "[DONE]" {
            return .complete
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Check for usage-only chunk (sent at end with stream_options.include_usage)
        if let usage = parseUsage(from: json) {
            return .complete(with: usage)
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            return nil
        }

        // Check for finish reason
        if let finishReason = firstChoice["finish_reason"] as? String, !finishReason.isEmpty {
            // Parse usage if included in this chunk
            let usage = parseUsage(from: json)
            return .complete(with: usage)
        }

        guard let delta = firstChoice["delta"] as? [String: Any] else {
            return nil
        }

        // Parse text delta
        let textDelta = delta["content"] as? String

        // Parse tool call delta
        var toolCallDelta: ToolCallDelta?
        if let toolCalls = delta["tool_calls"] as? [[String: Any]],
           let firstToolCall = toolCalls.first {
            let index = firstToolCall["index"] as? Int ?? 0
            let id = firstToolCall["id"] as? String
            var name: String?
            var argumentsDelta = ""

            if let function = firstToolCall["function"] as? [String: Any] {
                name = function["name"] as? String
                argumentsDelta = function["arguments"] as? String ?? ""
            }

            toolCallDelta = ToolCallDelta(index: index, id: id, name: name, argumentsDelta: argumentsDelta)
        }

        return StreamingChunk(delta: textDelta, toolCallDelta: toolCallDelta)
    }

    // MARK: - Error Mapping

    private nonisolated func mapError(_ error: Error) -> AIError {
        if let aiError = error as? AIError {
            return aiError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCancelled:
                return .cancelled
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkError(error)
            default:
                return .networkError(error)
            }
        }

        return .unknown(error)
    }
}
