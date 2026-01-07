//
//  MarkdownMessageView.swift
//  PersonalAgent
//
//  Created by Jules on 1/7/26.
//

import SwiftUI

struct MarkdownMessageView: View {
    let content: String
    let role: MessageRole

    private var segments: [MessageSegment] {
        MarkdownParser.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(segments) { segment in
                switch segment.type {
                case .text(let text):
                    Text(LocalizedStringKey(text))
                        .textSelection(.enabled)
                        .foregroundStyle(role == .user ? .white : .primary)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var isCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(language?.capitalized ?? "Code")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2)) // Slightly darker header

            // Code content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white) // Always light text for code
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.8)) // Dark theme for code blocks
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)

        withAnimation {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Parser Models

struct MessageSegment: Identifiable {
    let id = UUID()
    let type: SegmentType

    enum SegmentType {
        case text(String)
        case code(language: String?, code: String)
    }
}

enum MarkdownParser {
    static func parse(_ text: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        let lines = text.components(separatedBy: .newlines)

        var currentText = ""
        var isInCodeBlock = false
        var codeBlockLanguage: String?
        var currentCode = ""

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if isInCodeBlock {
                    // End of code block
                    if !currentCode.isEmpty {
                        // Remove trailing newline
                        if currentCode.hasSuffix("\n") {
                            currentCode.removeLast()
                        }
                        segments.append(MessageSegment(type: .code(language: codeBlockLanguage, code: currentCode)))
                    }
                    currentCode = ""
                    codeBlockLanguage = nil
                    isInCodeBlock = false
                } else {
                    // Start of code block
                    if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        segments.append(MessageSegment(type: .text(currentText)))
                        currentText = ""
                    }

                    let components = line.components(separatedBy: "```")
                    if components.count > 1 {
                        codeBlockLanguage = components[1].trimmingCharacters(in: .whitespaces)
                        if codeBlockLanguage?.isEmpty == true { codeBlockLanguage = nil }
                    }
                    isInCodeBlock = true
                }
            } else {
                if isInCodeBlock {
                    currentCode += line + "\n"
                } else {
                    currentText += line + "\n"
                }
            }
        }

        if isInCodeBlock && !currentCode.isEmpty {
             // Handle unclosed code block
             segments.append(MessageSegment(type: .code(language: codeBlockLanguage, code: currentCode)))
        } else if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Trim trailing newlines from text
            segments.append(MessageSegment(type: .text(currentText.trimmingCharacters(in: .whitespacesAndNewlines))))
        }

        return segments
    }
}
