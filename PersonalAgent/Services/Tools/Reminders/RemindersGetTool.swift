import Foundation
import EventKit

struct RemindersGetTool: AgentTool {
    let name = "reminders_get"
    let description = "Get a list of incomplete reminders."
    let requiresConfirmation = false

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [:],
        required: []
    )

    private let remindersService = RemindersService()

    func execute(arguments: [String: Any]) async throws -> String {
        let reminders = try await remindersService.fetchReminders(completed: false)
        
        if reminders.isEmpty {
            return "No incomplete reminders found."
        }
        
        let descriptions = reminders.map { reminder in
            var desc = "- \(reminder.title ?? "Untitled")"
            if let dueDate = reminder.dueDateComponents?.date {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                desc += " (Due: \(formatter.string(from: dueDate)))"
            }
            return desc
        }
        
        return "Found \(reminders.count) reminders:\n\(descriptions.joined(separator: "\n"))"
    }
}
