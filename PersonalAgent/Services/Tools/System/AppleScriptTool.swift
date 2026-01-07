import Foundation

struct AppleScriptTool: AgentTool {
    let name = "applescript_run"
    let description = "Execute AppleScript code. Use for app automation."
    let requiresConfirmation = true

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "script": .init(type: "string", description: "AppleScript code to execute", enumValues: nil, items: nil)
        ],
        required: ["script"]
    )

    func execute(arguments: [String: Any]) async throws -> String {
        guard let scriptSource = arguments["script"] as? String else {
            throw ToolError.invalidArguments("Missing script")
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            throw ToolError.executionFailed("Failed to create AppleScript")
        }

        // AppleScript execution must happen on the main thread for many operations
        // especially if it interacts with UI elements of other apps.
        // However, NSAppleScript is generally thread-safe for execution if it doesn't touch UI.
        // For safety, we'll run it on the background but be aware it might need main thread dispatch 
        // depending on what the script handles.
        // Given we are in an agent context, let's keep it async.
        
        let result = script.executeAndReturnError(&error)

        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw ToolError.executionFailed(message)
        }

        return result.stringValue ?? "Script executed successfully."
    }
}
