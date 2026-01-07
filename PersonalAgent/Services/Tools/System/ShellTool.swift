import Foundation

struct ShellTool: AgentTool {
    let name = "shell_execute"
    let description = "Execute a shell command. Only allowed commands: ls, pwd, date, whoami, echo, cat, head, tail, wc, which, env, hostname, uptime, df, du"
    let requiresConfirmation = true

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "command": .init(type: "string", description: "Shell command to execute", enumValues: nil, items: nil),
            "working_directory": .init(type: "string", description: "Optional working directory", enumValues: nil, items: nil)
        ],
        required: ["command"]
    )

    private let allowedCommands: Set<String> = [
        "ls", "pwd", "date", "whoami", "echo", "cat", "head", "tail",
        "wc", "which", "env", "hostname", "uptime", "df", "du"
    ]

    func execute(arguments: [String: Any]) async throws -> String {
        guard let command = arguments["command"] as? String else {
            throw ToolError.invalidArguments("Missing command")
        }

        // Security: validate command
        let baseCommand = command.split(separator: " ").first.map(String.init) ?? command
        guard allowedCommands.contains(baseCommand) else {
            throw ToolError.notAllowed("Command '\(baseCommand)' is not allowed. Allowed: \(allowedCommands.sorted().joined(separator: ", "))")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        if let workingDir = arguments["working_directory"] as? String {
            process.currentDirectoryURL = URL(fileURLWithPath: (workingDir as NSString).expandingTildeInPath)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            return "Command failed (exit \(process.terminationStatus)):\n\(error.isEmpty ? output : error)"
        }

        return output.isEmpty ? "Command completed with no output." : output
    }
}
