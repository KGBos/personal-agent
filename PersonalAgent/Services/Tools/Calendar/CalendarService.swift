import Foundation
import EventKit

actor CalendarService {
    private let eventStore = EKEventStore()

    func fetchEvents(from startDate: Date, to endDate: Date, calendarName: String? = nil) async throws -> [EKEvent] {
        try await PermissionsManager.shared.ensureAccess(for: .calendar)
        
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
        try await PermissionsManager.shared.ensureAccess(for: .calendar)
        
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
        try await PermissionsManager.shared.ensureAccess(for: .calendar)
        
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
            /* 
             TODO: Implement color parsing helper for PlatformColor/CGColor if needed.
             Master branch introduced this but left it as TODO/Comment.
             For now, we leave it as is to match Master's intent (feature stub).
            */
        }

        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar.calendarIdentifier
    }
}
