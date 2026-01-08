import Foundation

// MARK: - Token Usage

struct TokenUsage: Codable, Sendable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let model: String
    let timestamp: Date

    var estimatedCost: Double {
        // Pricing per 1M tokens (as of 2025)
        let pricing: (input: Double, output: Double) = switch model {
        case "gpt-4o":
            (5.0, 15.0)
        case "gpt-4o-mini":
            (0.15, 0.60)
        case "gpt-4-turbo":
            (10.0, 30.0)
        case "gpt-4":
            (30.0, 60.0)
        case "gpt-3.5-turbo":
            (0.50, 1.50)
        default:
            (5.0, 15.0) // Default to gpt-4o pricing
        }

        let inputCost = Double(promptTokens) / 1_000_000 * pricing.input
        let outputCost = Double(completionTokens) / 1_000_000 * pricing.output
        return inputCost + outputCost
    }
}

// MARK: - Daily Stats

struct DailyUsageStats: Codable, Sendable, Identifiable {
    let date: Date
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int
    var estimatedCost: Double
    var requestCount: Int

    var id: Date { date }

    static func empty(for date: Date) -> DailyUsageStats {
        DailyUsageStats(
            date: Calendar.current.startOfDay(for: date),
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0,
            estimatedCost: 0,
            requestCount: 0
        )
    }

    mutating func add(_ usage: TokenUsage) {
        promptTokens += usage.promptTokens
        completionTokens += usage.completionTokens
        totalTokens += usage.totalTokens
        estimatedCost += usage.estimatedCost
        requestCount += 1
    }
}

// MARK: - Aggregate Stats

struct AggregateUsageStats: Codable, Sendable {
    var totalPromptTokens: Int = 0
    var totalCompletionTokens: Int = 0
    var totalTokens: Int = 0
    var totalCost: Double = 0
    var totalRequests: Int = 0
    var dailyStats: [DailyUsageStats] = []
    var lastResetDate: Date = Date()

    mutating func add(_ usage: TokenUsage) {
        totalPromptTokens += usage.promptTokens
        totalCompletionTokens += usage.completionTokens
        totalTokens += usage.totalTokens
        totalCost += usage.estimatedCost
        totalRequests += 1

        // Update daily stats
        let today = Calendar.current.startOfDay(for: Date())
        if let index = dailyStats.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            dailyStats[index].add(usage)
        } else {
            var newDay = DailyUsageStats.empty(for: today)
            newDay.add(usage)
            dailyStats.append(newDay)

            // Keep only last 30 days
            if dailyStats.count > 30 {
                dailyStats.removeFirst(dailyStats.count - 30)
            }
        }
    }

    mutating func reset() {
        totalPromptTokens = 0
        totalCompletionTokens = 0
        totalTokens = 0
        totalCost = 0
        totalRequests = 0
        dailyStats = []
        lastResetDate = Date()
    }

    var averageTokensPerRequest: Int {
        totalRequests > 0 ? totalTokens / totalRequests : 0
    }

    var averageCostPerRequest: Double {
        totalRequests > 0 ? totalCost / Double(totalRequests) : 0
    }
}

// MARK: - Model Info

struct ModelInfo {
    let id: String
    let displayName: String
    let inputPricePerMillion: Double
    let outputPricePerMillion: Double
    let contextWindow: Int

    static let models: [ModelInfo] = [
        ModelInfo(id: "gpt-4o", displayName: "GPT-4o", inputPricePerMillion: 5.0, outputPricePerMillion: 15.0, contextWindow: 128000),
        ModelInfo(id: "gpt-4o-mini", displayName: "GPT-4o Mini", inputPricePerMillion: 0.15, outputPricePerMillion: 0.60, contextWindow: 128000),
        ModelInfo(id: "gpt-4-turbo", displayName: "GPT-4 Turbo", inputPricePerMillion: 10.0, outputPricePerMillion: 30.0, contextWindow: 128000),
        ModelInfo(id: "gpt-4", displayName: "GPT-4", inputPricePerMillion: 30.0, outputPricePerMillion: 60.0, contextWindow: 8192),
        ModelInfo(id: "gpt-3.5-turbo", displayName: "GPT-3.5 Turbo", inputPricePerMillion: 0.50, outputPricePerMillion: 1.50, contextWindow: 16385)
    ]

    static func info(for modelId: String) -> ModelInfo? {
        models.first { $0.id == modelId }
    }
}
