import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @AppStorage("autoExportAppleNotes") private var autoExportAppleNotes = false
    @AppStorage("autoExportNotion") private var autoExportNotion = false
    @AppStorage("preferredLLMProvider") private var preferredLLMProviderRaw = "ollama"
    @AppStorage("preferredLLMModel") private var preferredLLMModelID = ""

    private var currentProvider: LLMProvider {
        LLMProvider(rawValue: preferredLLMProviderRaw) ?? .ollama
    }

    private var currentModel: LLMModel {
        currentProvider.availableModels.first(where: { $0.id == preferredLLMModelID })
            ?? currentProvider.defaultModel
    }

    var body: some View {
        Form {
            Section("Default Providers") {
                Picker("LLM Provider", selection: $viewModel.preferredLLMProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: viewModel.preferredLLMProvider) { _, newValue in
                    preferredLLMProviderRaw = newValue.rawValue
                    // Reset model to the new provider's default
                    preferredLLMModelID = newValue.defaultModel.id
                }

                Picker("Model", selection: $preferredLLMModelID) {
                    ForEach(currentProvider.availableModels) { model in
                        HStack {
                            Text(model.displayName)
                            Text(model.tierLabel)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model.id)
                    }
                }
                .onChange(of: preferredLLMModelID) { _, _ in
                    // Ensure the model stays in sync
                }

                ModelTierInfo(model: currentModel)

                Picker("Transcription", selection: $viewModel.preferredTranscriptionSource) {
                    Text("Local (Whisper.cpp)").tag(TranscriptionSource.local)
                    Text("OpenAI Whisper API").tag(TranscriptionSource.openAIWhisper)
                }
            }

            Section("After Recording") {
                Text("When a recording ends, Clio will automatically generate a summary and export to your chosen destinations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Export to Apple Notes", isOn: $autoExportAppleNotes)
                Toggle("Export to Notion", isOn: $autoExportNotion)
            }

            Section("Data") {
                LabeledContent("Storage Location") {
                    Text("~/Library/Application Support/com.willscuderi.Clio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // Initialize model ID if empty
            if preferredLLMModelID.isEmpty {
                preferredLLMModelID = currentProvider.defaultModel.id
            }
        }
    }
}

struct ModelTierInfo: View {
    let model: LLMModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tierIcon)
                .foregroundStyle(tierColor)
                .font(.system(size: 12))
            Text(model.tier.description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var tierIcon: String {
        switch model.tier {
        case .fast: "hare"
        case .balanced: "scale.3d"
        case .best: "star.fill"
        }
    }

    private var tierColor: Color {
        switch model.tier {
        case .fast: .green
        case .balanced: .blue
        case .best: .purple
        }
    }
}
