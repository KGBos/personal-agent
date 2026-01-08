//
//  ToolCallBubble.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct ToolCallBubble: View {
    let toolCall: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse.byLayer, options: .repeating)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tool Call")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(toolCall.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.monospaced)
                }

                Spacer()

                if !toolCall.arguments.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Arguments (expandable)
            if !toolCall.arguments.isEmpty {
                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(toolCall.arguments.keys.sorted()), id: \.self) { key in
                            HStack(alignment: .top, spacing: 4) {
                                Text("\(key):")
                                    .font(.caption2)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)

                                Text(formatValue(toolCall.arguments[key]?.value))
                                    .font(.caption2)
                                    .fontDesign(.monospaced)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(argumentsSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var argumentsSummary: String {
        let summary = toolCall.arguments.map { "\($0.key): \(formatValue($0.value.value))" }.joined(separator: ", ")
        return summary.count > 50 ? String(summary.prefix(47)) + "..." : summary
    }

    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "nil" }
        if let str = value as? String {
            return "\"\(str)\""
        }
        return String(describing: value)
    }
}
