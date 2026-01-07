import Foundation

/// Schema for tool parameters (JSON Schema subset)
struct ToolParameterSchema: Codable, Sendable {
    let type: String  // "object"
    let description: String?
    let properties: [String: PropertySchema]?
    let required: [String]?

    final class PropertySchema: Codable, Sendable {
        let type: String
        let description: String?
        let enumValues: [String]?
        let items: PropertySchema?

        init(type: String, description: String? = nil, enumValues: [String]? = nil, items: PropertySchema? = nil) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
            self.items = items
        }

        enum CodingKeys: String, CodingKey {
            case type, description, items
            case enumValues = "enum"
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let description { dict["description"] = description }
        if let properties {
            dict["properties"] = properties.mapValues { prop -> [String: Any] in
                var p: [String: Any] = ["type": prop.type]
                if let desc = prop.description { p["description"] = desc }
                if let enumVals = prop.enumValues { p["enum"] = enumVals }
                if let items = prop.items {
                    p["items"] = items.toDictionary()
                }
                return p
            }
        }
        if let required { dict["required"] = required }
        return dict
    }
}

extension ToolParameterSchema.PropertySchema {
    func toDictionary() -> [String: Any] {
        var p: [String: Any] = ["type": type]
        if let description { p["description"] = description }
        if let enumValues { p["enum"] = enumValues }
        if let items { p["items"] = items.toDictionary() }
        return p
    }
}

/// Definition of a tool for AI providers
struct ToolDefinition: Sendable {
    let name: String
    let description: String
    let parameters: ToolParameterSchema
}

/// Protocol for executable agent tools
protocol AgentTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameterSchema: ToolParameterSchema { get }
    var requiresConfirmation: Bool { get }

    func execute(arguments: [String: Any]) async throws -> String
}

extension AgentTool {
    var definition: ToolDefinition {
        ToolDefinition(name: name, description: description, parameters: parameterSchema)
    }

    // Default: require confirmation for safety
    var requiresConfirmation: Bool { true }
}
