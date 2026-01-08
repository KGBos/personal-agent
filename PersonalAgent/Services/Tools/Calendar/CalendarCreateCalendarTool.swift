import Foundation

struct CalendarCreateCalendarTool: AgentTool {
    let name = "calendar_create_calendar"
    let description = "Create a new calendar with a specified name and optional color."
    let requiresConfirmation = true

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "name": .init(type: "string", description: "Name of the new calendar", enumValues: nil, items: nil),
            "color": .init(type: "string", description: "Optional: Hex color code for the calendar (e.g., '#FF0000')", enumValues: nil, items: nil)
        ],
        required: ["name"]
    )

    private let calendarService = CalendarService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let name = arguments["name"] as? String else {
            throw ToolError.invalidArguments("Missing required parameter: name")
        }

        let color = arguments["color"] as? String

        let calendarId = try await calendarService.createCalendar(name: name, colorHex: color)

        return "Created new calendar '\(name)' with ID: \(calendarId)"
    }
}
