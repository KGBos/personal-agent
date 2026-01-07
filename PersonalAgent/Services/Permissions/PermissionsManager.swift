import Foundation
import Observation
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
