import Foundation

struct FilesListTool: AgentTool {
    let name = "files_list"
    let description = "List files in a directory."
    let requiresConfirmation = false

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "path": .init(type: "string", description: "Directory path (use ~ for home)", enumValues: nil, items: nil),
            "show_hidden": .init(type: "boolean", description: "Include hidden files (default: false)", enumValues: nil, items: nil)
        ],
        required: ["path"]
    )

    func execute(arguments: [String: Any]) async throws -> String {
        guard var path = arguments["path"] as? String else {
            throw ToolError.invalidArguments("Missing path")
        }

        // Expand ~ to home directory
        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }

        let showHidden = arguments["show_hidden"] as? Bool ?? false
        let url = URL(fileURLWithPath: path)

        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: showHidden ? [] : .skipsHiddenFiles
        )

        if contents.isEmpty {
            return "Directory is empty."
        }

        let descriptions = try contents.prefix(50).map { fileURL -> String in
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDir = resourceValues.isDirectory ?? false
            let size = resourceValues.fileSize ?? 0
            let icon = isDir ? "📁" : "📄"
            let sizeStr = isDir ? "" : " (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))"
            return "\(icon) \(fileURL.lastPathComponent)\(sizeStr)"
        }

        var result = "Contents of \(path)"
        if contents.count > 50 { result += " (showing first 50)" }
        result += ":\n\(descriptions.joined(separator: "\n"))"
        return result
    }
}

struct FilesReadTool: AgentTool {
    let name = "files_read"
    let description = "Read contents of a text file."
    let requiresConfirmation = false

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "path": .init(type: "string", description: "File path", enumValues: nil, items: nil),
            "max_lines": .init(type: "number", description: "Maximum lines to read (default: 100)", enumValues: nil, items: nil)
        ],
        required: ["path"]
    )

    func execute(arguments: [String: Any]) async throws -> String {
        guard var path = arguments["path"] as? String else {
            throw ToolError.invalidArguments("Missing path")
        }

        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }

        let maxLines = arguments["max_lines"] as? Int ?? 100
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        if lines.count <= maxLines {
            return content
        }

        let truncated = lines.prefix(maxLines).joined(separator: "\n")
        return "\(truncated)\n\n... (truncated, \(lines.count - maxLines) more lines)"
    }
}

struct FilesWriteTool: AgentTool {
    let name = "files_write"
    let description = "Write content to a file. Creates file if it doesn't exist."
    let requiresConfirmation = true  // ALWAYS confirm writes

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "path": .init(type: "string", description: "File path", enumValues: nil, items: nil),
            "content": .init(type: "string", description: "Content to write", enumValues: nil, items: nil),
            "append": .init(type: "boolean", description: "Append instead of overwrite (default: false)", enumValues: nil, items: nil)
        ],
        required: ["path", "content"]
    )

    func execute(arguments: [String: Any]) async throws -> String {
        guard var path = arguments["path"] as? String,
              let content = arguments["content"] as? String else {
            throw ToolError.invalidArguments("Missing path or content")
        }

        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }

        let append = arguments["append"] as? Bool ?? false

        if append, FileManager.default.fileExists(atPath: path) {
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            fileHandle.seekToEndOfFile()
            if let data = content.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
            return "Appended \(content.count) characters to \(path)"
        } else {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return "Wrote \(content.count) characters to \(path)"
        }
    }
}
