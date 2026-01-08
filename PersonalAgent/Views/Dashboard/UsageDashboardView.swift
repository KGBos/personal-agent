import SwiftUI
import Charts

struct UsageDashboardView: View {
    @Bindable var tokenTracker: TokenTracker

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Stats
                headerStatsSection

                // Chart Section
                chartSection

                // Breakdown Section
                breakdownSection

                // Recent Activity
                recentActivitySection
            }
            .padding()
        }
        .navigationTitle("Usage Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset Stats") {
                    tokenTracker.resetStats()
                }
                .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Header Stats

    private var headerStatsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Tokens",
                value: TokenTracker.formatTokenCount(tokenTracker.stats.totalTokens),
                subtitle: "\(tokenTracker.stats.totalRequests) requests",
                icon: "text.word.spacing",
                color: .blue
            )

            StatCard(
                title: "Total Cost",
                value: TokenTracker.formatCost(tokenTracker.stats.totalCost),
                subtitle: "Since \(formattedResetDate)",
                icon: "dollarsign.circle",
                color: .green
            )

            StatCard(
                title: "Avg per Request",
                value: TokenTracker.formatTokenCount(tokenTracker.stats.averageTokensPerRequest),
                subtitle: TokenTracker.formatCost(tokenTracker.stats.averageCostPerRequest),
                icon: "chart.bar",
                color: .orange
            )
        }
    }

    private var formattedResetDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: tokenTracker.stats.lastResetDate)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Usage")
                .font(.headline)

            if tokenTracker.stats.dailyStats.isEmpty {
                Text("No usage data yet")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(tokenTracker.stats.dailyStats) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Tokens", day.totalTokens)
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Breakdown")
                .font(.headline)

            HStack(spacing: 16) {
                BreakdownItem(
                    title: "Input Tokens",
                    value: tokenTracker.stats.totalPromptTokens,
                    percentage: inputPercentage,
                    color: .blue
                )

                BreakdownItem(
                    title: "Output Tokens",
                    value: tokenTracker.stats.totalCompletionTokens,
                    percentage: outputPercentage,
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var inputPercentage: Double {
        guard tokenTracker.stats.totalTokens > 0 else { return 0 }
        return Double(tokenTracker.stats.totalPromptTokens) / Double(tokenTracker.stats.totalTokens) * 100
    }

    private var outputPercentage: Double {
        guard tokenTracker.stats.totalTokens > 0 else { return 0 }
        return Double(tokenTracker.stats.totalCompletionTokens) / Double(tokenTracker.stats.totalTokens) * 100
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            if tokenTracker.recentUsage.isEmpty {
                Text("No recent activity")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tokenTracker.recentUsage.suffix(10).reversed(), id: \.timestamp) { usage in
                    RecentUsageRow(usage: usage)
                }
            }
        }
        .padding()
        .background(Color(.systemGray).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BreakdownItem: View {
    let title: String
    let value: Int
    let percentage: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(TokenTracker.formatTokenCount(value))
                .font(.title3)
                .fontWeight(.semibold)

            ProgressView(value: percentage, total: 100)
                .tint(color)

            Text(String(format: "%.1f%%", percentage))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecentUsageRow: View {
    let usage: TokenUsage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(usage.model)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(usage.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(usage.totalTokens) tokens")
                    .font(.caption)

                Text(TokenTracker.formatCost(usage.estimatedCost))
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UsageDashboardView(tokenTracker: TokenTracker())
    }
}
