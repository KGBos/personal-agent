import Foundation

struct CalendarCreateEventTool: AgentTool {
    let name = "calendar_create_event"
    let description = "Create a new calendar event with title, start time, end time, and optional location."
    let requiresConfirmation = true  // Modifies data

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "title": .init(type: "string", description: "Event title", enumValues: nil, items: nil),
            "start_date": .init(type: "string", description: "Start date/time in ISO8601 format", enumValues: nil, items: nil),
            "end_date": .init(type: "string", description: "End date/time in ISO8601 format", enumValues: nil, items: nil),
            "location": .init(type: "string", description: "Optional event location", enumValues: nil, items: nil),
            "notes": .init(type: "string", description: "Optional event notes", enumValues: nil, items: nil),
            "calendar_name": .init(type: "string", description: "Optional calendar name (uses default if not specified)", enumValues: nil, items: nil)
        ],
        required: ["title", "start_date", "end_date"]
    )

    private let calendarService = CalendarService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let title = arguments["title"] as? String,
              let startDateString = arguments["start_date"] as? String,
              let endDateString = arguments["end_date"] as? String else {
            throw ToolError.invalidArguments("Missing required parameters: title, start_date, end_date")
        }

        let formatter = ISO8601DateFormatter()
        guard let startDate = formatter.date(from: startDateString),
              let endDate = formatter.date(from: endDateString) else {
            throw ToolError.invalidArguments("Invalid date format. Use ISO8601.")
        }

        let eventId = try await calendarService.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: arguments["location"] as? String,
            notes: arguments["notes"] as? String,
            calendarName: arguments["calendar_name"] as? String
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return "Created event '\(title)' on \(dateFormatter.string(from: startDate)). Event ID: \(eventId)"
    }
}
