import Foundation

struct CalendarSetDefaultTool: AgentTool {
    let name = "calendar_set_default"
    let description = "Set the default calendar to use when scheduling events without a specific calendar name."
    let requiresConfirmation = false
    
    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "calendar_name": .init(type: "string", description: "The name of the calendar to set as default (e.g., 'Life', 'Work').", enumValues: nil, items: nil)
        ],
        required: ["calendar_name"]
    )
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let calendarName = arguments["calendar_name"] as? String else {
            throw ToolError.invalidArguments("Missing required parameter: calendar_name")
        }
        
        await MainActor.run {
            SettingsManager.shared.defaultCalendarName = calendarName
        }
        
        return "Default calendar set to '\(calendarName)'."
    }
}
