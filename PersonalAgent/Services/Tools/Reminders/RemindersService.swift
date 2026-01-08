import Foundation
import EventKit

actor RemindersService {
    private let eventStore = EKEventStore()

    func fetchReminders(completed: Bool = false) async throws -> [EKReminder] {
        try await ensureAccess()
        let predicate = eventStore.predicateForReminders(in: nil)
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    let filtered = completed ? reminders : reminders.filter { !$0.isCompleted }
                    continuation.resume(returning: filtered)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Int = 0
    ) async throws -> String {
        try await ensureAccess()
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority
        
        if let dueDate = dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        try eventStore.save(reminder, commit: true)
        let identifier = reminder.calendarItemIdentifier
        if identifier.isEmpty {
            throw ToolError.executionFailed("Failed to get reminder identifier after saving")
        }
        return identifier
    }
    func completeReminder(identifier: String) async throws {
        try await ensureAccess()
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ToolError.notFound("Reminder not found")
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }

    func deleteReminder(identifier: String) async throws {
        try await ensureAccess()
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ToolError.notFound("Reminder not found")
        }
        try eventStore.remove(reminder, commit: true)
    }

    private func ensureAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToReminders()
            if !granted {
                throw ToolError.permissionDenied("Reminders access denied by user")
            }
        case .denied, .restricted, .writeOnly:
            throw ToolError.permissionDenied("Reminders access is restricted or denied")
        case .authorized, .fullAccess:
            return
        @unknown default:
            return
        }
    }
}
