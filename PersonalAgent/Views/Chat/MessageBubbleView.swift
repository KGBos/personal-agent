//
//  MessageBubbleView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    var onRegenerate: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role != .user {
                avatarView
            } else {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                contentView

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if message.role == .user {
                avatarView
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var avatarView: some View {
        if message.role == .user {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        } else if message.role == .assistant {
            Image(systemName: "sparkles")
                .symbolRenderingMode(.hierarchical)
                .font(.title2)
                .foregroundStyle(.orange)
                .padding(6)
                .background(Color.orange.opacity(0.1))
                .clipShape(Circle())
        } else if message.role == .tool {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundStyle(.gray)
        } else {
            // System
            Image(systemName: "desktopcomputer")
                .font(.title2)
                .foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            switch message.content {
            case .text(let text):
                MarkdownMessageView(content: text, role: message.role)
                    .padding(12)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

            case .toolCall(let call):
                ToolCallBubble(toolCall: call)

            case .toolResult(let result):
                ToolResultBubble(result: result)
            }
        }
        .contextMenu {
            Button {
                copyToClipboard(content: message.content)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if message.role == .assistant {
                Button {
                    onRegenerate?()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func copyToClipboard(content: MessageContent) {
        let text: String
        switch content {
        case .text(let str): text = str
        case .toolCall(let call): text = "Tool Call: \(call.name)\nArguments: \(call.arguments)"
        case .toolResult(let res): text = "Tool Result: \(res.content)"
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return .accentColor
        case .assistant:
            return Color(.systemGray).opacity(0.15)
        case .tool:
            return Color.orange.opacity(0.15)
        case .system:
            return Color.purple.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }
}

// MARK: - Tool Call Bubble

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

// MARK: - Tool Result Bubble

struct ToolResultBubble: View {
    let result: ToolResult
    @State private var isExpanded = false

    private var isLongContent: Bool {
        result.content.count > 200 || result.content.contains("\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: result.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(result.isError ? .red : .green)

                Text(result.isError ? "Error" : "Result")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if isLongContent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Content
            if isExpanded || !isLongContent {
                Text(result.content)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            } else {
                Text(truncatedContent)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((result.isError ? Color.red : Color.green).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder((result.isError ? Color.red : Color.green).opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var truncatedContent: String {
        if result.content.count > 150 {
            return String(result.content.prefix(147)) + "..."
        }
        return result.content
    }
}

// MARK: - Streaming Message View

struct StreamingMessageView: View {
    let text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(text)
                        .textSelection(.enabled)

                    // Cursor indicator
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 16)
                        .opacity(0.8)
                }
                .padding(12)
                .background(Color(.systemGray).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 60)
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Previews

#Preview("User Message") {
    MessageBubbleView(message: .user("Hello, how are you?"))
        .padding()
}

#Preview("Assistant Message") {
    MessageBubbleView(message: .assistant("I'm doing great! How can I help you today?"))
        .padding()
}

#Preview("Streaming") {
    StreamingMessageView(text: "This is a streaming response that is still being generated...")
        .padding()
}

#Preview("Typing") {
    TypingIndicatorView()
        .padding()
}
