import SwiftUI

struct ToolConfirmationView: View {
    let toolCall: ToolCall
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear.badge.questionmark")
                    .foregroundStyle(.orange)
                Text("Tool Request")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("The assistant wants to run:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(toolCall.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                if !toolCall.arguments.isEmpty {
                    Text("Arguments:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    
                    ScrollView {
                        Text(formatArguments(toolCall.arguments))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(maxHeight: 100)
                }
            }

            HStack {
                Button(role: .destructive, action: onReject) {
                    Text("Reject")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onConfirm) {
                    Text("Approve")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: 400)
    }

    private func formatArguments(_ arguments: [String: AnyCodable]) -> String {
        let dict = arguments.mapValues { $0.value }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
