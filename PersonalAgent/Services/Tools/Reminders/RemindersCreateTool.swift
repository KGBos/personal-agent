import Foundation

struct RemindersCreateTool: AgentTool {
    let name = "reminders_create"
    let description = "Create a new reminder."
    let requiresConfirmation = true

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "title": .init(type: "string", description: "Reminder title", enumValues: nil, items: nil),
            "notes": .init(type: "string", description: "Optional notes", enumValues: nil, items: nil),
            "due_date": .init(type: "string", description: "Optional due date in ISO8601 format", enumValues: nil, items: nil)
        ],
        required: ["title"]
    )

    private let remindersService = RemindersService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let title = arguments["title"] as? String else {
            throw ToolError.invalidArguments("Missing required parameter: title")
        }
        
        let dueDate: Date?
        if let dueDateString = arguments["due_date"] as? String {
            let formatter = ISO8601DateFormatter()
            dueDate = formatter.date(from: dueDateString)
        } else {
            dueDate = nil
        }
        
        let id = try await remindersService.createReminder(
            title: title,
            notes: arguments["notes"] as? String,
            dueDate: dueDate
        )
        
        return "Created reminder '\(title)'. ID: \(id)"
    }
}
