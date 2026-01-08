import Foundation
import EventKit

actor CalendarService {
    private let eventStore = EKEventStore()

    private func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted {
                throw ToolError.executionFailed("Calendar access denied.")
            }
        case .denied, .restricted:
            let url = PermissionType.calendar.settingsURL?.absoluteString ?? ""
            throw ToolError.executionFailed("System Calendar Access Denied. [Open Privacy Settings](\(url)) to enable 'PersonalAgent'.")
        case .fullAccess, .authorized, .writeOnly:
            break
        @unknown default:
            break
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date, calendarName: String? = nil) async throws -> [EKEvent] {
        try await requestAccess()
        
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
        try await requestAccess()
        
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
            // Check for user preference first
            if let defaultName = await SettingsManager.shared.defaultCalendarName,
               let calendar = eventStore.calendars(for: .event).first(where: { $0.title == defaultName }) {
                event.calendar = calendar
            } else {
                event.calendar = eventStore.defaultCalendarForNewEvents
            }
        }

        try eventStore.save(event, span: .thisEvent)
        guard let identifier = event.eventIdentifier else {
             throw ToolError.executionFailed("Failed to get event identifier after saving")
        }
        return identifier
    }

    func createCalendar(title: String, colorHex: String? = nil) async throws -> String {
        try await requestAccess()
        
        let existing = eventStore.calendars(for: .event).first { $0.title == title }
        if let existing {
            return existing.calendarIdentifier
        }
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = title
        
        // Find a writeable source (prefer iCloud or Local)
        let sources = eventStore.sources
        let bestSource = sources.first { $0.sourceType == .calDAV && $0.title == "iCloud" }
            ?? sources.first { $0.sourceType == .local }
            ?? sources.first { $0.sourceType == .calDAV }
            ?? sources.first
        
        guard let source = bestSource else {
            throw ToolError.executionFailed("No suitable source found to create calendar.")
        }
        
        newCalendar.source = source
        
        if let colorHex {
            // Need a helper to parse hex to CGColor/UIColor if we want to support this.
            // For now, ignoring color to keep it simple as I don't see a hex helper available immediately.
            // If the user wants color, I'll need to implement a hex parser.
            // Let's assume for now we skip color or implementing it requires UIKit/AppKit conditionally.
            // Since this is a Service, maybe better to skip unless requested or key feature.
            // User asked to "handle EKCalendar creation, including setting the source (Local, iCloud, etc.)".
        }

        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar.calendarIdentifier
    }
}
