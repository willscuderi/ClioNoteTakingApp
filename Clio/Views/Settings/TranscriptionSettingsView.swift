import SwiftUI

struct TranscriptionSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Transcription Engine") {
                Picker("Default Engine", selection: $viewModel.preferredTranscriptionSource) {
                    Text("Local (Whisper.cpp / Core ML)").tag(TranscriptionSource.local)
                    Text("OpenAI Whisper API").tag(TranscriptionSource.openAIWhisper)
                    Text("AssemblyAI (Speaker Diarization)").tag(TranscriptionSource.assemblyAI)
                }
                .pickerStyle(.radioGroup)

                if viewModel.preferredTranscriptionSource == .assemblyAI {
                    Text("AssemblyAI identifies different speakers in the audio. Ideal for podcasts, interviews, and meetings with multiple participants.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.assemblyAIKey.isEmpty {
                        Label("AssemblyAI API key not configured — set it in the API Keys tab.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Text("Note: Speaker labels (Speaker A, B, C...) are assigned per audio chunk and may not be consistent across the entire recording.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Section("Local Engine") {
                LabeledContent("Engine") {
                    Text("Whisper.cpp via Core ML")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Status") {
                    // TODO: Check if model is downloaded
                    Text("Not configured")
                        .foregroundStyle(.orange)
                }
                Text("Local transcription runs entirely on-device using Apple Silicon. No data is sent to any server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("API Engine") {
                LabeledContent("Provider") {
                    Text("OpenAI Whisper")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("API Key") {
                    Text(viewModel.openAIKey.isEmpty ? "Not configured" : "Configured")
                        .foregroundStyle(viewModel.openAIKey.isEmpty ? .orange : .green)
                }
                Text("API transcription sends audio to OpenAI's servers for processing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
