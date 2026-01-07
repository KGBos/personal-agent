//
//  SettingsManager.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsManager {
    // MARK: - Keys
    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let openAIModel = "openAIModel"
        static let systemPrompt = "systemPrompt"
        static let openAIAPIKey = "openai_api_key"
        static let appleIntelligenceMode = "appleIntelligenceMode"
    }

    // MARK: - Storage
    private let defaults = UserDefaults.standard
    private let keychain = SecureStorage()

    // MARK: - AI Provider Settings

    var selectedProvider: AIProvider {
        get {
            guard let rawValue = defaults.string(forKey: Keys.selectedProvider),
                  let provider = AIProvider(rawValue: rawValue) else {
                return .openAI
            }
            return provider
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.selectedProvider)
        }
    }

    enum AppleIntelligenceMode: String, CaseIterable, Identifiable {
        case onDevice = "onDevice"
        case cloud = "cloud"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .onDevice: return "On-Device"
            case .cloud: return "Cloud Compute"
            }
        }
    }

    var appleIntelligenceMode: AppleIntelligenceMode {
        get {
            guard let rawValue = defaults.string(forKey: Keys.appleIntelligenceMode),
                  let mode = AppleIntelligenceMode(rawValue: rawValue) else {
                return .onDevice
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.appleIntelligenceMode)
        }
    }

    var openAIModel: String {
        get {
            defaults.string(forKey: Keys.openAIModel) ?? "gpt-4o"
        }
        set {
            defaults.set(newValue, forKey: Keys.openAIModel)
        }
    }

    var systemPrompt: String {
        get {
            defaults.string(forKey: Keys.systemPrompt) ?? defaultSystemPrompt
        }
        set {
            defaults.set(newValue, forKey: Keys.systemPrompt)
        }
    }

    // MARK: - Secure Storage (API Keys)

    var openAIAPIKey: String = "" {
        didSet {
            if openAIAPIKey.isEmpty {
                keychain.delete(Keys.openAIAPIKey)
            } else {
                keychain.set(openAIAPIKey, for: Keys.openAIAPIKey)
            }
        }
    }

    init() {
        self.openAIAPIKey = keychain.get(Keys.openAIAPIKey) ?? ""
    }

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.isEmpty
    }

    // MARK: - Defaults

    var defaultSystemPrompt: String {
        """
        You are a helpful personal assistant. You can help the user manage their calendar, \
        reminders, contacts, files, and perform system tasks. Be concise and helpful.
        """
    }

    // MARK: - Available Models

    static let openAIModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4-turbo",
        "gpt-4",
        "gpt-3.5-turbo"
    ]
}
