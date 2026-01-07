import Foundation
import Contacts

struct ContactsSearchTool: AgentTool {
    let name = "contacts_search"
    let description = "Search contacts by name. Returns matching contacts with their details."
    let requiresConfirmation = false

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "query": .init(type: "string", description: "Name to search for", enumValues: nil, items: nil)
        ],
        required: ["query"]
    )

    private let service = ContactsService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("Missing query")
        }

        let contacts = try await service.searchContacts(query: query)

        if contacts.isEmpty {
            return "No contacts found matching '\(query)'."
        }

        let descriptions = contacts.prefix(10).map { contact -> String in
            var desc = "- \(contact.givenName) \(contact.familyName)"
            if !contact.organizationName.isEmpty {
                desc += " (\(contact.organizationName))"
            }
            if let email = contact.emailAddresses.first?.value as String? {
                desc += " | \(email)"
            }
            if let phone = contact.phoneNumbers.first?.value.stringValue {
                desc += " | \(phone)"
            }
            desc += " [ID: \(contact.identifier)]"
            return desc
        }

        var result = "Found \(contacts.count) contacts"
        if contacts.count > 10 { result += " (showing first 10)" }
        result += ":\n\(descriptions.joined(separator: "\n"))"
        return result
    }
}
