//
//  MessageInputView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text Input
            TextField("Message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .focused($isFocused)
                .onSubmit {
                    if !isLoading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }
                .submitLabel(.send)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

            // Send/Cancel Button
            Button {
                if isLoading {
                    onCancel()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(buttonColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isLoading && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    private var buttonColor: Color {
        if isLoading {
            return .primary
        } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Color(nsColor: .disabledControlTextColor)
        } else {
            return .primary
        }
    }
}

// MARK: - Previews

#Preview("Empty") {
    MessageInputView(text: .constant(""), isLoading: false, onSend: {}, onCancel: {})
        .padding()
}

#Preview("With Text") {
    MessageInputView(text: .constant("Hello, how are you?"), isLoading: false, onSend: {}, onCancel: {})
        .padding()
}

#Preview("Loading") {
    MessageInputView(text: .constant(""), isLoading: true, onSend: {}, onCancel: {})
        .padding()
}
