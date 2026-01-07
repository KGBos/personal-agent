import Foundation
import EventKit

struct CalendarGetEventsTool: AgentTool {
    let name = "calendar_get_events"
    let description = "Get calendar events within a date range. Returns event titles, times, and locations."
    let requiresConfirmation = false  // Read-only

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "start_date": .init(type: "string", description: "Start date in ISO8601 format (e.g., 2026-01-07T00:00:00Z)", enumValues: nil, items: nil),
            "end_date": .init(type: "string", description: "End date in ISO8601 format", enumValues: nil, items: nil),
            "calendar_name": .init(type: "string", description: "Optional: specific calendar name to search", enumValues: nil, items: nil)
        ],
        required: ["start_date", "end_date"]
    )

    private let calendarService = CalendarService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let startDateString = arguments["start_date"] as? String,
              let endDateString = arguments["end_date"] as? String else {
            throw ToolError.invalidArguments("Missing required date parameters")
        }

        let formatter = ISO8601DateFormatter()
        guard let startDate = formatter.date(from: startDateString),
              let endDate = formatter.date(from: endDateString) else {
            throw ToolError.invalidArguments("Invalid date format. Use ISO8601 (e.g., 2026-01-07T09:00:00Z)")
        }

        let calendarName = arguments["calendar_name"] as? String
        let events = try await calendarService.fetchEvents(from: startDate, to: endDate, calendarName: calendarName)

        if events.isEmpty {
            return "No events found in the specified date range."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let eventDescriptions = events.map { event in
            var desc = "- \(event.title ?? "Untitled")"
            desc += " | \(dateFormatter.string(from: event.startDate)) - \(dateFormatter.string(from: event.endDate))"
            if let location = event.location, !location.isEmpty {
                desc += " | Location: \(location)"
            }
            return desc
        }

        return "Found \(events.count) events:\n\(eventDescriptions.joined(separator: "\n"))"
    }
}
