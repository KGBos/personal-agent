import Foundation
import EventKit

struct RemindersCompleteTool: AgentTool {
    let name = "reminders_complete"
    let description = "Mark a reminder as completed."
    let requiresConfirmation = true

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "identifier": .init(type: "string", description: "Reminder identifier from reminders_get", enumValues: nil, items: nil)
        ],
        required: ["identifier"]
    )

    private let service = RemindersService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let identifier = arguments["identifier"] as? String else {
            throw ToolError.invalidArguments("Missing identifier")
        }

        try await service.completeReminder(identifier: identifier)
        return "Reminder marked as completed."
    }
}
