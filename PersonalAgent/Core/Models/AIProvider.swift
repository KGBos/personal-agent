//
//  AIProvider.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation

enum AIProvider: String, Codable, CaseIterable, Sendable {
    case openAI = "openai"
    case appleFoundationModels = "apple"

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .appleFoundationModels: return "Apple Intelligence"
        }
    }

    var iconName: String {
        switch self {
        case .openAI: return "brain"
        case .appleFoundationModels: return "apple.logo"
        }
    }
}
