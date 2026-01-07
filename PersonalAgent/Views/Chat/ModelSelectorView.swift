//
//  ModelSelectorView.swift
//  PersonalAgent
//
//  Created by Jules on 1/7/26.
//

import SwiftUI

struct ModelSelectorView: View {
    @Bindable var settingsManager: SettingsManager

    var body: some View {
        Menu {
            Picker("Provider", selection: $settingsManager.selectedProvider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Label(provider.displayName, systemImage: provider.iconName)
                        .tag(provider)
                }
            }

            if settingsManager.selectedProvider == .openAI {
                Picker("Model", selection: $settingsManager.openAIModel) {
                    ForEach(SettingsManager.openAIModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.inline)
            } else if settingsManager.selectedProvider == .appleFoundationModels {
                Picker("Processing", selection: $settingsManager.appleIntelligenceMode) {
                    ForEach(SettingsManager.AppleIntelligenceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentModelName)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .frame(width: 200) // Ensure it has some width area to grab, or rely on content
    }

    private var currentModelName: String {
        switch settingsManager.selectedProvider {
        case .openAI:
            return settingsManager.openAIModel
        case .appleFoundationModels:
            return "Apple Intelligence"
        }
    }
}
