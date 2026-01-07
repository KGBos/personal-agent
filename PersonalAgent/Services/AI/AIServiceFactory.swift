//
//  AIServiceFactory.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation

@MainActor
final class AIServiceFactory: AIServiceFactoryProtocol {
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    func createService(for provider: AIProvider) -> any AIService {
        switch provider {
        case .openAI:
            return OpenAIService(
                apiKey: settingsManager.openAIAPIKey,
                model: settingsManager.openAIModel
            )

        case .appleFoundationModels:
            if #available(macOS 26.0, iOS 26.0, *) {
                return AppleAIService()
            } else {
                // Fallback for older OS versions
                return OpenAIService(
                    apiKey: settingsManager.openAIAPIKey,
                    model: settingsManager.openAIModel
                )
            }
        }
    }

    func currentService() -> any AIService {
        createService(for: settingsManager.selectedProvider)
    }
}
