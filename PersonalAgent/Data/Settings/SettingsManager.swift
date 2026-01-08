//
//  SettingsManager.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation
import SwiftUI
import Observation

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
        didSet {
            defaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
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
        didSet {
            defaults.set(appleIntelligenceMode.rawValue, forKey: Keys.appleIntelligenceMode)
        }
    }

    var openAIModel: String {
        didSet {
            defaults.set(openAIModel, forKey: Keys.openAIModel)
        }
    }

    var systemPrompt: String {
        didSet {
            defaults.set(systemPrompt, forKey: Keys.systemPrompt)
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
        // Load Selected Provider
        if let savedProvider = defaults.string(forKey: Keys.selectedProvider),
           let provider = AIProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .openAI
        }

        // Load Apple Intelligence Mode
        if let savedMode = defaults.string(forKey: Keys.appleIntelligenceMode),
           let mode = AppleIntelligenceMode(rawValue: savedMode) {
            self.appleIntelligenceMode = mode
        } else {
            self.appleIntelligenceMode = .onDevice
        }

        // Load OpenAI Model
        self.openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4o"

        // Load System Prompt
        self.systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt

        // Load API Key
        self.openAIAPIKey = keychain.get(Keys.openAIAPIKey) ?? ""
    }

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.isEmpty
    }

    // MARK: - Defaults

    static var defaultSystemPrompt: String {
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
