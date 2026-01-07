//
//  MessageBubbleView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                contentView

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .textSelection(.enabled)
                .padding(12)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))

        case .toolCall(let call):
            ToolCallBubble(toolCall: call)

        case .toolResult(let result):
            ToolResultBubble(result: result)
        }
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gear")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Calling: \(toolCall.name)")
                    .font(.caption)
                    .fontWeight(.medium)

                if !toolCall.arguments.isEmpty {
                    Text(argumentsSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var argumentsSummary: String {
        toolCall.arguments.map { "\($0.key): \($0.value.value)" }.joined(separator: ", ")
    }
}

// MARK: - Tool Result Bubble

struct ToolResultBubble: View {
    let result: ToolResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.isError ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(result.isError ? .red : .green)

            Text(result.content)
                .font(.caption)
                .lineLimit(5)
        }
        .padding(10)
        .background((result.isError ? Color.red : Color.green).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
