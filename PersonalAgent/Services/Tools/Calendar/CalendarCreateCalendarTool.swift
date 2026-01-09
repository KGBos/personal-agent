import Foundation

struct CalendarCreateCalendarTool: AgentTool {
    let name = "calendar_create_calendar"
    let description = "Creates a new calendar in the user's default event store (e.g. iCloud or Local)."
    let requiresConfirmation = false
    
    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "title": .init(type: "string", description: "The title of the new calendar.", enumValues: nil, items: nil),
            "color": .init(type: "string", description: "Optional. A hex color string (e.g. '#FF0000').", enumValues: nil, items: nil)
        ],
        required: ["title"]
    )
    
    private let calendarService = CalendarService()
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let title = arguments["title"] as? String else {
            throw ToolError.invalidArguments("Missing required argument: title")
        }
        
        // Color support is optional in service for now
        let color = arguments["color"] as? String
        
        let calendarID = try await calendarService.createCalendar(title: title, colorHex: color)
        
        return "Successfully created calendar '\(title)' with ID: \(calendarID)"
    }
}
