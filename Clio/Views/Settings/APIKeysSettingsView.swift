import SwiftUI

struct APIKeysSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Speech-to-Text") {
                SecureField("OpenAI API Key", text: $viewModel.openAIKey, prompt: Text("sk-..."))
                SecureField("Deepgram API Key", text: $viewModel.deepgramKey, prompt: Text("Optional"))
            }

            Section("LLM Providers") {
                SecureField("OpenAI API Key", text: $viewModel.openAIKey, prompt: Text("sk-..."))
                    .disabled(true)
                    .help("Same key as above, used for GPT summarization")
                SecureField("Anthropic API Key", text: $viewModel.claudeKey, prompt: Text("sk-ant-..."))
            }

            Section("Integrations") {
                SecureField("Notion API Key", text: $viewModel.notionKey, prompt: Text("ntn_..."))
            }

            Section {
                HStack {
                    if let success = viewModel.successMessage {
                        Text(success)
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    Spacer()
                    Button("Save") {
                        viewModel.saveKeys()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
