import Foundation
import EventKit

actor CalendarService {
    private let eventStore = EKEventStore()

    func fetchEvents(from startDate: Date, to endDate: Date, calendarName: String? = nil) async throws -> [EKEvent] {
        try await ensureAccess()

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
        try await ensureAccess()

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
        guard let identifier = event.eventIdentifier else {
             throw ToolError.executionFailed("Failed to get event identifier after saving")
        }
        return identifier
    }

    func createCalendar(name: String, colorHex: String? = nil) async throws -> String {
        try await ensureAccess()

        // Find a source that allows creating calendars (usually iCloud or Local)
        guard let source = findBestSource() else {
            throw ToolError.executionFailed("No suitable account found to create calendar")
        }

        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = name
        newCalendar.source = source

        // Set color if provided (hex string)
        if let colorHex, let color = PlatformColor(hex: colorHex) {
            newCalendar.cgColor = color.cgColor
        }

        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar.calendarIdentifier
    }

    private func ensureAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted {
                throw ToolError.permissionDenied("Calendar access denied by user")
            }
        case .denied, .restricted, .writeOnly:
            throw ToolError.permissionDenied("Calendar access is restricted or denied")
        case .authorized, .fullAccess:
            return
        @unknown default:
            return
        }
    }

    private func findBestSource() -> EKSource? {
        let sources = eventStore.sources
        // Prefer iCloud or Local
        return sources.first { $0.sourceType == .calDAV && $0.title == "iCloud" }
            ?? sources.first { $0.sourceType == .local }
            ?? sources.first { $0.sourceType == .calDAV }
    }
}

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

extension PlatformColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
