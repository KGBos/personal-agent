//
//  ToolResultBubble.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
        .overlay(alignment: .bottomTrailing) {
            if result.isPermissionDenied {
                Button {
                    #if os(iOS) || os(visionOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #elseif os(macOS)
                    // Open System Settings > Privacy & Security
                    if result.content.contains("Calendar") {
                         if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                             if NSWorkspace.shared.open(url) { return }
                         }
                    } else if result.content.contains("Reminders") {
                         if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                             if NSWorkspace.shared.open(url) { return }
                         }
                    } else if result.content.contains("Contacts") {
                         if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                             if NSWorkspace.shared.open(url) { return }
                         }
                    }
                    
                     // Fallback to just Privacy
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                         NSWorkspace.shared.open(url)
                    }
                    #endif
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }
                .padding(8)
            }
        }
    }

    private var truncatedContent: String {
        if result.content.count > 150 {
            return String(result.content.prefix(147)) + "..."
        }
        return result.content
    }
}
