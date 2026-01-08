import Foundation
import Contacts

actor ContactsService {
    private let store = CNContactStore()

    func searchContacts(query: String) async throws -> [CNContact] {
        try await ensureAccess()

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(matchingName: query)
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                continuation.resume(returning: contacts)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func getContact(identifier: String) async throws -> CNContact {
        try await ensureAccess()

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
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
                continuation.resume(returning: contact)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func createContact(
        givenName: String,
        familyName: String?,
        email: String?,
        phone: String?,
        organization: String?
    ) async throws -> String {
        try await ensureAccess()

        let contact = CNMutableContact()
        contact.givenName = givenName
        if let familyName { contact.familyName = familyName }
        if let email { contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)] }
        if let phone { contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))] }
        if let organization { contact.organizationName = organization }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try store.execute(saveRequest)
                continuation.resume(returning: contact.identifier)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func ensureAccess() async throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            if !granted {
                throw ToolError.permissionDenied("Contacts access denied by user")
            }
        case .denied, .restricted:
            throw ToolError.permissionDenied("Contacts access is restricted or denied")
        case .authorized, .limited:
            return
        @unknown default:
            return
        }
    }
}
