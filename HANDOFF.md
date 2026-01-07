# PersonalAgent - Agent Handoff Document

This document provides complete context for continuing development of the PersonalAgent app.

## Project Overview

**PersonalAgent** is a macOS-first SwiftUI app that allows users to chat with AI (OpenAI, Apple Foundation Models) and have the AI take actions on their behalf via tool/function calling.

- **Bundle ID**: `com.leon.PersonalAgent`
- **Platforms**: macOS 26.2 (primary), iOS 26.2, visionOS 26.2
- **Swift Version**: 6.2.3
- **Xcode Version**: 26.2

## Current Implementation Status

### ✅ Phase 1: Foundation (COMPLETE)
- Core models (Message, AIProvider, ToolCall, ToolResult, AnyCodable)
- AIService protocol with streaming support
- OpenAIService with full SSE streaming implementation
- ChatViewModel with streaming state management
- Chat UI (ChatView, MessageBubbleView, MessageInputView)
- Settings UI with API key management (Keychain storage)
- Error handling with AIError enum

### ✅ Phase 2: Persistence & Sidebar (COMPLETE)
- SwiftData models (ConversationModel, MessageModel)
- DataController with ModelContainer
- ConversationStore for CRUD operations
- ConversationListView sidebar with search
- MainSplitView for split navigation
- Auto-save conversations
- Auto-title from first message

### ⏳ Phase 3: Tool Framework (NEXT)
- AgentTool protocol
- ToolRegistry for registration
- ToolExecutor for safe execution
- OpenAI function calling integration
- First tools: Calendar, Reminders (read-only)
- Tool confirmation UI
- PermissionsManager

### 📋 Phase 4: Full Tool Suite (PENDING)
- Calendar tools (create, update, delete events)
- Reminders tools (create, complete, delete)
- Contacts tools (search, get details, create)
- Files tools (list, read, search, write)
- System tools (shell, AppleScript, Shortcuts)

### 📋 Phase 5: Apple Foundation Models (PENDING)
- AppleAIService using LanguageModelSession
- Tool adapter for Apple's Tool protocol
- Provider switching with availability detection

---

## Project Structure

```
PersonalAgent/
├── PersonalAgentApp.swift              # @main entry, dependency setup
├── ContentView.swift                   # Root view, wraps MainSplitView
├── Core/
│   ├── Models/
│   │   ├── AIProvider.swift            # enum: openAI, appleFoundationModels
│   │   ├── Message.swift               # Message, MessageRole, MessageContent, ToolCall, ToolResult
│   │   └── AnyCodable.swift            # Type-erased Codable wrapper
│   ├── Protocols/
│   │   └── AIService.swift             # AIService protocol, AIResponse, StreamingChunk
│   └── Errors/
│       └── AIError.swift               # Comprehensive AI error enum
├── Services/
│   └── AI/
│       ├── AIServiceFactory.swift      # Creates AIService instances
│       └── OpenAI/
│           └── OpenAIService.swift     # Full OpenAI implementation with SSE
├── ViewModels/
│   └── ChatViewModel.swift             # Chat state, streaming, persistence
├── Views/
│   ├── Main/
│   │   ├── MainSplitView.swift         # NavigationSplitView layout
│   │   └── ConversationListView.swift  # Sidebar with conversation list
│   ├── Chat/
│   │   ├── ChatView.swift              # Main chat interface
│   │   ├── MessageBubbleView.swift     # Message bubbles, streaming indicator
│   │   └── MessageInputView.swift      # Text input with send/cancel
│   ├── Settings/
│   │   └── SettingsView.swift          # Settings with API key, model selection
│   └── Components/
│       └── ErrorBanner.swift           # Error display banner
├── Data/
│   ├── Persistence/
│   │   ├── DataController.swift        # SwiftData ModelContainer
│   │   ├── ConversationModel.swift     # @Model for conversations
│   │   ├── MessageModel.swift          # @Model for messages
│   │   └── ConversationStore.swift     # CRUD operations
│   └── Settings/
│       ├── SettingsManager.swift       # @Observable settings
│       └── SecureStorage.swift         # Keychain wrapper
├── PersonalAgent.entitlements          # App entitlements
└── Assets.xcassets/                    # App icons, colors
```

---

## Key Code Patterns

### 1. AIService Protocol

```swift
// Core/Protocols/AIService.swift
protocol AIService: Sendable {
    var provider: AIProvider { get }
    var isAvailable: Bool { get async }

    func complete(messages: [Message], systemPrompt: String?) async throws -> AIResponse
    func stream(messages: [Message], systemPrompt: String?) -> AsyncThrowingStream<StreamingChunk, Error>
}
```

### 2. Message Model

```swift
// Core/Models/Message.swift
enum MessageRole: String, Codable, Sendable {
    case system, user, assistant, tool
}

enum MessageContent: Codable, Sendable, Equatable {
    case text(String)
    case toolCall(ToolCall)
    case toolResult(ToolResult)
}

struct ToolCall: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let arguments: [String: AnyCodable]
}

struct ToolResult: Codable, Sendable, Equatable {
    let toolCallId: String
    let content: String
    let isError: Bool
}
```

### 3. Observable Pattern

All ViewModels and managers use `@Observable` macro:

```swift
@MainActor
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var isLoading: Bool = false
    // ...
}
```

### 4. Actor-Based Services

Network services use `actor` for thread safety:

```swift
actor OpenAIService: AIService {
    // All methods are isolated
}
```

### 5. Dependency Injection

Dependencies are created in `PersonalAgentApp` and passed down:

```swift
@main
struct PersonalAgentApp: App {
    private let dataController = DataController.shared
    @State private var settingsManager = SettingsManager()
    @State private var conversationStore: ConversationStore?
    @State private var chatViewModel: ChatViewModel?

    // Initialize in onAppear, pass to ContentView
}
```

---

## Phase 3 Implementation Guide: Tool Framework

### Step 1: Create AgentTool Protocol

Create `Core/Protocols/Tool.swift`:

```swift
import Foundation

/// Schema for tool parameters (JSON Schema subset)
struct ToolParameterSchema: Codable, Sendable {
    let type: String  // "object"
    let description: String?
    let properties: [String: PropertySchema]?
    let required: [String]?

    struct PropertySchema: Codable, Sendable {
        let type: String  // "string", "number", "boolean", "array", "object"
        let description: String?
        let enumValues: [String]?
        let items: PropertySchema?  // For arrays

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
                return p
            }
        }
        if let required { dict["required"] = required }
        return dict
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
```

### Step 2: Create ToolError

Create `Core/Errors/ToolError.swift`:

```swift
import Foundation

enum ToolError: Error, LocalizedError {
    case invalidArguments(String)
    case notAllowed(String)
    case executionFailed(String)
    case permissionDenied(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return "Invalid arguments: \(msg)"
        case .notAllowed(let msg): return "Not allowed: \(msg)"
        case .executionFailed(let msg): return "Execution failed: \(msg)"
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .notFound(let msg): return "Not found: \(msg)"
        }
    }
}
```

### Step 3: Create ToolRegistry

Create `Services/Tools/ToolRegistry.swift`:

```swift
import Foundation

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
        // Register all default tools here
        register(CalendarGetEventsTool())
        register(CalendarCreateEventTool())
        register(RemindersGetTool())
        register(RemindersCreateTool())
        // Add more as implemented
    }
}
```

### Step 4: Create ToolExecutor

Create `Services/Tools/ToolExecutor.swift`:

```swift
import Foundation

actor ToolExecutor {
    private let registry: ToolRegistry
    private let permissionsManager: PermissionsManager

    init(registry: ToolRegistry, permissionsManager: PermissionsManager) {
        self.registry = registry
        self.permissionsManager = permissionsManager
    }

    struct ExecutionResult: Sendable {
        let toolCallId: String
        let toolName: String
        let result: String
        let isError: Bool
        let executionTime: TimeInterval
    }

    func execute(toolCall: ToolCall) async -> ExecutionResult {
        let startTime = Date()

        guard let tool = await MainActor.run(body: { registry.tool(named: toolCall.name) }) else {
            return ExecutionResult(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                result: "Error: Unknown tool '\(toolCall.name)'",
                isError: true,
                executionTime: Date().timeIntervalSince(startTime)
            )
        }

        do {
            let args = toolCall.arguments.mapValues { $0.value }
            let result = try await tool.execute(arguments: args)

            return ExecutionResult(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                result: result,
                isError: false,
                executionTime: Date().timeIntervalSince(startTime)
            )
        } catch {
            return ExecutionResult(
                toolCallId: toolCall.id,
                toolName: toolCall.name,
                result: "Error: \(error.localizedDescription)",
                isError: true,
                executionTime: Date().timeIntervalSince(startTime)
            )
        }
    }
}
```

### Step 5: Create PermissionsManager

Create `Services/Permissions/PermissionsManager.swift`:

```swift
import Foundation
import EventKit
import Contacts

enum PermissionType: String, CaseIterable, Sendable {
    case calendar
    case reminders
    case contacts
    case automation

    var displayName: String {
        switch self {
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .contacts: return "Contacts"
        case .automation: return "System Automation"
        }
    }
}

enum PermissionStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
@Observable
final class PermissionsManager {
    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    var calendarStatus: PermissionStatus = .notDetermined
    var remindersStatus: PermissionStatus = .notDetermined
    var contactsStatus: PermissionStatus = .notDetermined

    init() {
        Task { await refreshAllStatuses() }
    }

    func refreshAllStatuses() async {
        calendarStatus = mapEKStatus(EKEventStore.authorizationStatus(for: .event))
        remindersStatus = mapEKStatus(EKEventStore.authorizationStatus(for: .reminder))
        contactsStatus = mapCNStatus(CNContactStore.authorizationStatus(for: .contacts))
    }

    func requestCalendarAccess() async throws -> Bool {
        let granted = try await eventStore.requestFullAccessToEvents()
        calendarStatus = granted ? .authorized : .denied
        return granted
    }

    func requestRemindersAccess() async throws -> Bool {
        let granted = try await eventStore.requestFullAccessToReminders()
        remindersStatus = granted ? .authorized : .denied
        return granted
    }

    func requestContactsAccess() async throws -> Bool {
        let granted = try await contactStore.requestAccess(for: .contacts)
        contactsStatus = granted ? .authorized : .denied
        return granted
    }

    private func mapEKStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .fullAccess, .authorized: return .authorized
        case .denied, .writeOnly: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private func mapCNStatus(_ status: CNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized, .limited: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }
}
```

### Step 6: Create Calendar Tools

Create directory `Services/Tools/Calendar/` and add:

**CalendarService.swift:**
```swift
import Foundation
import EventKit

actor CalendarService {
    private let eventStore = EKEventStore()

    func fetchEvents(from startDate: Date, to endDate: Date, calendarName: String? = nil) async throws -> [EKEvent] {
        let calendars: [EKCalendar]?
        if let calendarName {
            calendars = eventStore.calendars(for: .event).filter { $0.title == calendarName }
        } else {
            calendars = nil
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        return eventStore.events(matching: predicate)
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarName: String? = nil
    ) async throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes

        if let calendarName {
            if let calendar = eventStore.calendars(for: .event).first(where: { $0.title == calendarName }) {
                event.calendar = calendar
            }
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
}
```

**CalendarGetEventsTool.swift:**
```swift
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
```

**CalendarCreateEventTool.swift:**
```swift
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
```

### Step 7: Update OpenAIService for Function Calling

Modify `Services/AI/OpenAI/OpenAIService.swift`:

1. Add tools parameter to `complete` and `stream` methods
2. Update `buildRequest` to include tools in JSON
3. Parse tool_calls from responses

Key changes to `buildRequest`:

```swift
private func buildRequest(
    messages: [Message],
    tools: [any AgentTool],  // ADD THIS
    systemPrompt: String?,
    stream: Bool
) throws -> URLRequest {
    // ... existing code ...

    var body: [String: Any] = [
        "model": model,
        "messages": buildMessages(messages, systemPrompt: systemPrompt),
        "stream": stream
    ]

    // ADD: Include tools if any
    if !tools.isEmpty {
        body["tools"] = tools.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameterSchema.toDictionary()
                ]
            ]
        }
    }

    // ... rest of method
}
```

### Step 8: Update AIService Protocol

Add tools parameter:

```swift
protocol AIService: Sendable {
    var provider: AIProvider { get }
    var isAvailable: Bool { get async }

    func complete(
        messages: [Message],
        tools: [any AgentTool],  // ADD
        systemPrompt: String?
    ) async throws -> AIResponse

    func stream(
        messages: [Message],
        tools: [any AgentTool],  // ADD
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamingChunk, Error>
}
```

### Step 9: Update ChatViewModel for Tool Execution

Add to `ChatViewModel`:

```swift
// Add properties
private let toolRegistry: ToolRegistry
private let toolExecutor: ToolExecutor
var pendingToolCalls: [ToolCall] = []

// Add methods
func confirmToolExecution(_ toolCall: ToolCall) async {
    pendingToolCalls.removeAll { $0.id == toolCall.id }

    let result = await toolExecutor.execute(toolCall: toolCall)

    let toolResultMessage = Message(
        role: .tool,
        content: .toolResult(ToolResult(
            toolCallId: result.toolCallId,
            content: result.result,
            isError: result.isError
        ))
    )
    messages.append(toolResultMessage)
    saveCurrentConversation()

    // Continue generation after tool execution
    generateResponse()
}

func rejectToolExecution(_ toolCall: ToolCall) {
    pendingToolCalls.removeAll { $0.id == toolCall.id }

    let toolResultMessage = Message(
        role: .tool,
        content: .toolResult(ToolResult(
            toolCallId: toolCall.id,
            content: "Tool execution was rejected by the user.",
            isError: true
        ))
    )
    messages.append(toolResultMessage)
    saveCurrentConversation()
}
```

### Step 10: Create Tool Confirmation UI

Create `Views/Chat/ToolConfirmationView.swift`:

```swift
import SwiftUI

struct ToolConfirmationView: View {
    let toolCall: ToolCall
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear.badge.questionmark")
                    .foregroundStyle(.orange)
                Text("Tool Request")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("The assistant wants to run:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(toolCall.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                if !toolCall.arguments.isEmpty {
                    Text("Arguments:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Array(toolCall.arguments.keys.sorted()), id: \.self) { key in
                        Text("  \(key): \(String(describing: toolCall.arguments[key]?.value ?? "nil"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Reject", role: .destructive) {
                    onReject()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Allow") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
```

### Step 11: Update Entitlements

Update `PersonalAgent.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.personal-information.calendars</key>
    <true/>
    <key>com.apple.security.personal-information.addressbook</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### Step 12: Update Info.plist

Add usage descriptions (via Xcode Info tab or directly):

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>PersonalAgent needs access to your calendar to help manage events and appointments.</string>

<key>NSRemindersFullAccessUsageDescription</key>
<string>PersonalAgent needs access to your reminders to help you manage tasks.</string>

<key>NSContactsUsageDescription</key>
<string>PersonalAgent needs access to your contacts to help you find and manage contact information.</string>

<key>NSAppleEventsUsageDescription</key>
<string>PersonalAgent uses automation to control other apps and perform system tasks.</string>
```

---

## Phase 4: Full Tool Suite

After Phase 3's framework is working, implement remaining tools:

### Reminders Tools

Create `Services/Tools/Reminders/`:

**RemindersService.swift:**
```swift
import Foundation
import EventKit

actor RemindersService {
    private let eventStore = EKEventStore()

    func fetchReminders(from startDate: Date? = nil, to endDate: Date? = nil, listName: String? = nil) async throws -> [EKReminder] {
        let calendars: [EKCalendar]?
        if let listName {
            calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        let predicate: NSPredicate
        if let startDate, let endDate {
            predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: startDate,
                ending: endDate,
                calendars: calendars
            )
        } else {
            predicate = eventStore.predicateForReminders(in: calendars)
        }

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func createReminder(
        title: String,
        dueDate: Date? = nil,
        notes: String? = nil,
        priority: Int = 0,
        listName: String? = nil
    ) async throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority

        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        if let listName, let calendar = eventStore.calendars(for: .reminder).first(where: { $0.title == listName }) {
            reminder.calendar = calendar
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }

        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    func completeReminder(identifier: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ToolError.notFound("Reminder not found")
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }

    func deleteReminder(identifier: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ToolError.notFound("Reminder not found")
        }
        try eventStore.remove(reminder, commit: true)
    }
}
```

**RemindersGetTool.swift:**
```swift
import Foundation

struct RemindersGetTool: AgentTool {
    let name = "reminders_get"
    let description = "Get reminders, optionally filtered by list name or date range."
    let requiresConfirmation = false

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "list_name": .init(type: "string", description: "Optional: specific reminders list", enumValues: nil, items: nil),
            "include_completed": .init(type: "boolean", description: "Include completed reminders (default: false)", enumValues: nil, items: nil)
        ],
        required: nil
    )

    private let service = RemindersService()

    func execute(arguments: [String: Any]) async throws -> String {
        let listName = arguments["list_name"] as? String
        let reminders = try await service.fetchReminders(listName: listName)

        let includeCompleted = arguments["include_completed"] as? Bool ?? false
        let filtered = includeCompleted ? reminders : reminders.filter { !$0.isCompleted }

        if filtered.isEmpty {
            return "No reminders found."
        }

        let descriptions = filtered.map { reminder -> String in
            var desc = "- [\(reminder.isCompleted ? "x" : " ")] \(reminder.title ?? "Untitled")"
            if let due = reminder.dueDateComponents?.date {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                desc += " (due: \(formatter.string(from: due)))"
            }
            desc += " [ID: \(reminder.calendarItemIdentifier)]"
            return desc
        }

        return "Found \(filtered.count) reminders:\n\(descriptions.joined(separator: "\n"))"
    }
}
```

**RemindersCreateTool.swift:**
```swift
import Foundation

struct RemindersCreateTool: AgentTool {
    let name = "reminders_create"
    let description = "Create a new reminder with optional due date."
    let requiresConfirmation = true

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "title": .init(type: "string", description: "Reminder title", enumValues: nil, items: nil),
            "due_date": .init(type: "string", description: "Optional due date in ISO8601 format", enumValues: nil, items: nil),
            "notes": .init(type: "string", description: "Optional notes", enumValues: nil, items: nil),
            "list_name": .init(type: "string", description: "Optional list name", enumValues: nil, items: nil),
            "priority": .init(type: "number", description: "Priority 0-9 (0=none, 1=high, 5=medium, 9=low)", enumValues: nil, items: nil)
        ],
        required: ["title"]
    )

    private let service = RemindersService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let title = arguments["title"] as? String else {
            throw ToolError.invalidArguments("Missing title")
        }

        var dueDate: Date?
        if let dueDateString = arguments["due_date"] as? String {
            dueDate = ISO8601DateFormatter().date(from: dueDateString)
        }

        let id = try await service.createReminder(
            title: title,
            dueDate: dueDate,
            notes: arguments["notes"] as? String,
            priority: arguments["priority"] as? Int ?? 0,
            listName: arguments["list_name"] as? String
        )

        return "Created reminder '\(title)'. ID: \(id)"
    }
}
```

**RemindersCompleteTool.swift:**
```swift
import Foundation

struct RemindersCompleteTool: AgentTool {
    let name = "reminders_complete"
    let description = "Mark a reminder as completed."
    let requiresConfirmation = true

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "identifier": .init(type: "string", description: "Reminder identifier from reminders_get", enumValues: nil, items: nil)
        ],
        required: ["identifier"]
    )

    private let service = RemindersService()

    func execute(arguments: [String: Any]) async throws -> String {
        guard let identifier = arguments["identifier"] as? String else {
            throw ToolError.invalidArguments("Missing identifier")
        }

        try await service.completeReminder(identifier: identifier)
        return "Reminder marked as completed."
    }
}
```

### Contacts Tools

Create `Services/Tools/Contacts/`:

**ContactsService.swift:**
```swift
import Foundation
import Contacts

actor ContactsService {
    private let store = CNContactStore()

    func searchContacts(query: String) async throws -> [CNContact] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(matchingName: query)
        return try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
    }

    func getContact(identifier: String) async throws -> CNContact {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]

        return try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
    }

    func createContact(
        givenName: String,
        familyName: String?,
        email: String?,
        phone: String?,
        organization: String?
    ) async throws -> String {
        let contact = CNMutableContact()
        contact.givenName = givenName
        if let familyName { contact.familyName = familyName }
        if let email { contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)] }
        if let phone { contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))] }
        if let organization { contact.organizationName = organization }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

        return contact.identifier
    }
}
```

**ContactsSearchTool.swift:**
```swift
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
```

### Files Tools

Create `Services/Tools/Files/`:

**FilesTool.swift:**
```swift
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
            fileHandle.write(content.data(using: .utf8)!)
            fileHandle.closeFile()
            return "Appended \(content.count) characters to \(path)"
        } else {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return "Wrote \(content.count) characters to \(path)"
        }
    }
}
```

### System Tools

Create `Services/Tools/System/`:

**ShellTool.swift:**
```swift
import Foundation

struct ShellTool: AgentTool {
    let name = "shell_execute"
    let description = "Execute a shell command. Only allowed commands: ls, pwd, date, whoami, echo, cat, head, tail, wc, which, env, hostname"
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
```

**AppleScriptTool.swift:**
```swift
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

        let result = script.executeAndReturnError(&error)

        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw ToolError.executionFailed(message)
        }

        return result.stringValue ?? "Script executed successfully."
    }
}
```

### Register All Tools

Update `ToolRegistry.registerDefaults()`:

```swift
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
```

---

## Phase 5: Apple Foundation Models

When implementing Apple Intelligence:

```swift
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
actor AppleAIService: AIService {
    let provider: AIProvider = .appleFoundationModels

    private var session: LanguageModelSession?

    var isAvailable: Bool {
        get async {
            do {
                let _ = try await LanguageModelSession()
                return true
            } catch {
                return false
            }
        }
    }

    func stream(
        messages: [Message],
        tools: [any AgentTool],
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = try await LanguageModelSession()

                    guard let lastUserMessage = messages.last(where: { $0.role == .user }),
                          case .text(let prompt) = lastUserMessage.content else {
                        throw AIError.invalidRequest("No user message")
                    }

                    let stream = session.streamResponse(to: prompt)

                    for try await partial in stream {
                        continuation.yield(StreamingChunk(delta: partial.content))
                    }

                    continuation.yield(.complete)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

---

## Testing Checklist

### Phase 3 Testing
- [ ] Tools register correctly in ToolRegistry
- [ ] Calendar permission request works
- [ ] CalendarGetEventsTool returns events correctly
- [ ] CalendarCreateEventTool creates events
- [ ] Tool confirmation dialog appears for write operations
- [ ] Reject button prevents tool execution
- [ ] Confirm button executes tool and continues conversation
- [ ] Tool results display correctly in chat
- [ ] Error cases handled gracefully

---

## Important Notes

1. **All ViewModels are `@MainActor`** - UI-related code runs on main thread
2. **Services are `actor`** - Network/IO code is isolated for thread safety
3. **Use `@Bindable`** for observable objects in views
4. **API key is in Keychain** - Already configured by user
5. **Streaming is SSE-based** - OpenAI uses Server-Sent Events
6. **Save after each message** - Conversations auto-persist

---

## Contact

Original developer: Leon Kuzmin
Created: January 7, 2026
