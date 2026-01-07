import Foundation
import Observation

@MainActor
@Observable
final class ToolRegistry {
    private var _tools: [String: any AgentTool] = [:]

    var tools: [any AgentTool] {
        Array(_tools.values)
    }

    var definitions: [ToolDefinition] {
        tools.map(\.definition)
    }

    func register(_ tool: any AgentTool) {
        _tools[tool.name] = tool
    }

    func unregister(_ name: String) {
        _tools.removeValue(forKey: name)
    }

    func tool(named name: String) -> (any AgentTool)? {
        _tools[name]
    }

    func registerDefaults() {
        // Calendar
        register(CalendarGetEventsTool())
        register(CalendarCreateEventTool())

        // Reminders
        register(RemindersGetTool())
        register(RemindersCreateTool())
        register(RemindersCompleteTool())

        // Contacts
        register(ContactsSearchTool())

        // Files
        register(FilesListTool())
        register(FilesReadTool())
        register(FilesWriteTool())

        // System
        register(ShellTool())
        register(AppleScriptTool())
    }
}
