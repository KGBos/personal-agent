//
//  ErrorBanner.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct ErrorBanner: View {
    let error: AIError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

#Preview {
    VStack {
        ErrorBanner(error: .invalidAPIKey, onDismiss: {})
        ErrorBanner(error: .networkError(URLError(.notConnectedToInternet)), onDismiss: {})
        ErrorBanner(error: .rateLimited(retryAfter: 30), onDismiss: {})
    }
    .padding()
}
