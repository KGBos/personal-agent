import Foundation

actor ToolExecutor {
    private let registry: ToolRegistry
    private let permissionsManager: PermissionsManager

    init(registry: ToolRegistry, permissionsManager: PermissionsManager) {
        self.registry = registry
        self.permissionsManager = permissionsManager
    }

    struct ExecutionResult: Sendable {
        let toolCallId: String
        let toolName: String
        let result: String
        let isError: Bool
        let executionTime: TimeInterval
    }

    func execute(toolCall: ToolCall) async -> ExecutionResult {
        let startTime = Date()

        guard let tool = await MainActor.run(body: { registry.tool(named: toolCall.name) }) else {
            return ExecutionResult(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                result: "Error: Unknown tool '\(toolCall.name)'",
                isError: true,
                executionTime: Date().timeIntervalSince(startTime)
            )
        }

        do {
            let arguments = toolCall.arguments
            let args = arguments.mapValues { $0.value as Any }
            let result = try await tool.execute(arguments: args)

            return ExecutionResult(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                result: result,
                isError: false,
                executionTime: Date().timeIntervalSince(startTime)
            )
        } catch {
            return ExecutionResult(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                result: "Error: \(error.localizedDescription)",
                isError: true,
                executionTime: Date().timeIntervalSince(startTime)
            )
        }
    }
}
