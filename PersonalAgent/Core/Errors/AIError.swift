//
//  AIError.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import Foundation

enum AIError: Error, LocalizedError, Sendable {
    case invalidAPIKey
    case invalidRequest(String)
    case invalidResponse
    case apiError(statusCode: Int, message: String?)
    case networkError(Error)
    case rateLimited(retryAfter: TimeInterval?)
    case contextLengthExceeded
    case serviceUnavailable
    case cancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your settings."
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .apiError(let statusCode, let message):
            if let message {
                return "API error (\(statusCode)): \(message)"
            }
            return "API error with status code \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited. Please try again in \(Int(retryAfter)) seconds."
            }
            return "Rate limited. Please try again later."
        case .contextLengthExceeded:
            return "The conversation is too long. Please start a new conversation."
        case .serviceUnavailable:
            return "The AI service is currently unavailable. Please try again later."
        case .cancelled:
            return "The request was cancelled."
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
