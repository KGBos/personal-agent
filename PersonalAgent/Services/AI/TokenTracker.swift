import Foundation

/// Tracks token usage and costs across API calls
@MainActor
@Observable
final class TokenTracker {
    // MARK: - State

    private(set) var stats: AggregateUsageStats = .init()
    private(set) var recentUsage: [TokenUsage] = []

    // MARK: - Storage

    private let storageKey = "PersonalAgent.TokenUsageStats"
    private let recentUsageKey = "PersonalAgent.RecentTokenUsage"
    private let maxRecentUsage = 100

    // MARK: - Initialization

    init() {
        loadStats()
    }

    // MARK: - Recording

    func record(_ usage: TokenUsage) {
        stats.add(usage)
        recentUsage.append(usage)

        // Keep only recent entries
        if recentUsage.count > maxRecentUsage {
            recentUsage.removeFirst(recentUsage.count - maxRecentUsage)
        }

        saveStats()
    }

    func record(promptTokens: Int, completionTokens: Int, model: String) {
        let usage = TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: promptTokens + completionTokens,
            model: model,
            timestamp: Date()
        )
        record(usage)
    }

    // MARK: - Reset

    func resetStats() {
        stats.reset()
        recentUsage.removeAll()
        saveStats()
    }

    // MARK: - Computed Properties

    var todayStats: DailyUsageStats {
        let today = Calendar.current.startOfDay(for: Date())
        return stats.dailyStats.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
            ?? DailyUsageStats.empty(for: today)
    }

    var thisWeekStats: (tokens: Int, cost: Double, requests: Int) {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let weekStats = stats.dailyStats.filter { $0.date >= weekAgo }
        return (
            tokens: weekStats.reduce(0) { $0 + $1.totalTokens },
            cost: weekStats.reduce(0) { $0 + $1.estimatedCost },
            requests: weekStats.reduce(0) { $0 + $1.requestCount }
        )
    }

    var thisMonthStats: (tokens: Int, cost: Double, requests: Int) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!

        let monthStats = stats.dailyStats.filter { $0.date >= startOfMonth }
        return (
            tokens: monthStats.reduce(0) { $0 + $1.totalTokens },
            cost: monthStats.reduce(0) { $0 + $1.estimatedCost },
            requests: monthStats.reduce(0) { $0 + $1.requestCount }
        )
    }

    // MARK: - Persistence

    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AggregateUsageStats.self, from: data) {
            stats = decoded
        }

        if let data = UserDefaults.standard.data(forKey: recentUsageKey),
           let decoded = try? JSONDecoder().decode([TokenUsage].self, from: data) {
            recentUsage = decoded
        }
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        if let data = try? JSONEncoder().encode(recentUsage) {
            UserDefaults.standard.set(data, forKey: recentUsageKey)
        }
    }
}

// MARK: - Formatting Helpers

extension TokenTracker {
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    static func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else if cost < 1 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.2f", cost)
    }
}
