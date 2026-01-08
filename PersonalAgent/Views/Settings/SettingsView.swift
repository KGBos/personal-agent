//
//  SettingsView.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // AI Provider Section
                Section("AI Provider") {
                    Picker("Provider", selection: $settingsManager.selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Label(provider.displayName, systemImage: provider.iconName)
                                .tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    if settingsManager.selectedProvider == .openAI {
                        Picker("Model", selection: $settingsManager.openAIModel) {
                            ForEach(SettingsManager.openAIModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }

                    if settingsManager.selectedProvider == .appleFoundationModels {
                        Picker("Mode", selection: $settingsManager.appleIntelligenceMode) {
                            ForEach(SettingsManager.AppleIntelligenceMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        
                        Label {
                            Text("Uses on-device Apple Intelligence models. No data leaves your Mac.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // API Key Section
                Section("OpenAI API Key") {
                    HStack {
                        if showAPIKey {
                            TextField("sk-...", text: $apiKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-...", text: $apiKeyInput)
                                .textFieldStyle(.plain)
                        }

                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        if settingsManager.hasOpenAIAPIKey {
                            Label("API key saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("No API key configured", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }

                        Spacer()

                        if !apiKeyInput.isEmpty {
                            Button("Save") {
                                saveAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        if settingsManager.hasOpenAIAPIKey {
                            Button("Clear") {
                                clearAPIKey()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                // System Prompt Section
                Section("System Prompt") {
                    TextEditor(text: $settingsManager.systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)

                    Button("Reset to Default") {
                        settingsManager.systemPrompt = SettingsManager.defaultSystemPrompt
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // About Section
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 400)
        .onAppear {
            // Load current API key into input field (masked)
            if settingsManager.hasOpenAIAPIKey {
                apiKeyInput = settingsManager.openAIAPIKey
            }
        }
    }

    private func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            settingsManager.openAIAPIKey = trimmed
        }
    }

    private func clearAPIKey() {
        settingsManager.openAIAPIKey = ""
        apiKeyInput = ""
    }
}

#Preview {
    SettingsView(settingsManager: SettingsManager())
}
