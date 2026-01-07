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
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit {
                    if !isLoading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }
                .submitLabel(.send)

            // Send/Cancel Button
            Button {
                if isLoading {
                    onCancel()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(buttonColor)
            }
            .buttonStyle(.plain)
            .disabled(!isLoading && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(12)
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }

    private var buttonColor: Color {
        if isLoading {
            return .red
        } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .gray
        } else {
            return .accentColor
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
