import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Default Providers") {
                Picker("LLM Provider", selection: $viewModel.preferredLLMProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                Picker("Transcription", selection: $viewModel.preferredTranscriptionSource) {
                    Text("Local (Whisper.cpp)").tag(TranscriptionSource.local)
                    Text("OpenAI Whisper API").tag(TranscriptionSource.openAIWhisper)
                }
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
    }
}
