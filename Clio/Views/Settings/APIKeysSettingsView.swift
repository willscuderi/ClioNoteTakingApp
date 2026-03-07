import SwiftUI

struct APIKeysSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Speech-to-Text section
                ProviderKeySection(
                    title: "Speech-to-Text",
                    providers: [
                        ProviderKeyConfig(
                            name: "OpenAI",
                            icon: "brain",
                            keychainID: "openai",
                            key: $viewModel.openAIKey,
                            placeholder: "sk-...",
                            steps: [
                                "Click the link below to open OpenAI's API key page",
                                "Sign in or create a free account",
                                "Click \"Create new secret key\"",
                                "Copy the key and paste it here"
                            ],
                            linkLabel: "Open OpenAI API Keys",
                            linkURL: URL(string: "https://platform.openai.com/api-keys")
                        ),
                        ProviderKeyConfig(
                            name: "Deepgram",
                            icon: "waveform",
                            keychainID: "deepgram",
                            key: $viewModel.deepgramKey,
                            placeholder: "Optional — for Deepgram transcription",
                            steps: [
                                "Click the link below to open Deepgram's console",
                                "Sign in or create a free account",
                                "Go to API Keys and click \"Create a New API Key\"",
                                "Copy the key and paste it here"
                            ],
                            linkLabel: "Open Deepgram Console",
                            linkURL: URL(string: "https://console.deepgram.com/")
                        )
                    ],
                    viewModel: viewModel
                )

                Divider()

                // LLM Providers section
                Text("LLM Providers")
                    .font(.system(size: 15, weight: .semibold))

                Text("Choose which AI provider generates meeting summaries. You only need a key for the one you use.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                ForEach(LLMProvider.allCases) { provider in
                    LLMProviderSetupCard(
                        provider: provider,
                        key: bindingForProvider(provider),
                        isConfigured: isConfigured(provider),
                        viewModel: viewModel
                    )
                }

                Divider()

                // Integrations section
                ProviderKeySection(
                    title: "Integrations",
                    providers: [
                        ProviderKeyConfig(
                            name: "Notion",
                            icon: "square.and.arrow.up",
                            keychainID: "notion",
                            key: $viewModel.notionKey,
                            placeholder: "ntn_...",
                            steps: [
                                "Go to notion.so/my-integrations",
                                "Click \"New integration\" and give it a name (e.g. \"Clio\")",
                                "Copy the \"Internal Integration Secret\"",
                                "Paste it here, then share a Notion page with the integration"
                            ],
                            linkLabel: "Open Notion Integrations",
                            linkURL: URL(string: "https://www.notion.so/my-integrations")
                        )
                    ],
                    viewModel: viewModel
                )

                // Notion parent page setting
                if !viewModel.notionKey.isEmpty {
                    NotionParentPageSetting(viewModel: viewModel)
                }

                // Status messages
                if let success = viewModel.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 13))
                        .transition(.opacity)
                }
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 13))
                }
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.2), value: viewModel.successMessage)
        }
    }

    private func bindingForProvider(_ provider: LLMProvider) -> Binding<String> {
        switch provider {
        case .openai: $viewModel.openAIKey
        case .claude: $viewModel.claudeKey
        case .gemini: $viewModel.geminiKey
        case .grok: $viewModel.grokKey
        case .ollama: .constant("")
        }
    }

    private func isConfigured(_ provider: LLMProvider) -> Bool {
        switch provider {
        case .openai: !viewModel.openAIKey.isEmpty
        case .claude: !viewModel.claudeKey.isEmpty
        case .gemini: !viewModel.geminiKey.isEmpty
        case .grok: !viewModel.grokKey.isEmpty
        case .ollama: true
        }
    }
}

// MARK: - LLM Provider Setup Card

struct LLMProviderSetupCard: View {
    let provider: LLMProvider
    @Binding var key: String
    let isConfigured: Bool
    let viewModel: SettingsViewModel

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                if provider.requiresAPIKey {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: provider.iconName)
                        .frame(width: 20)
                        .foregroundStyle(isConfigured ? .green : .secondary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(provider.displayName)
                            .font(.system(size: 14, weight: .medium))
                        Text(provider.companyName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isConfigured {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    } else if !provider.requiresAPIKey {
                        Label("No key needed", systemImage: "checkmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Set up")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }

                    if provider.requiresAPIKey {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)

            // Expandable setup section
            if isExpanded && provider.requiresAPIKey {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 12) {
                    // Step-by-step walkthrough
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(provider.setupSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                Text(step)
                                    .font(.system(size: 13))
                            }
                        }
                    }

                    // Link to provider console
                    if let url = provider.getKeyURL {
                        Link(destination: url) {
                            Label(provider.getLinkLabel, systemImage: "arrow.up.right.square")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }

                    // API key input + delete
                    HStack(spacing: 8) {
                        SecureField(provider.apiKeyPlaceholder, text: $key)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .onSubmit {
                                viewModel.saveKey(key, for: provider.keychainKey)
                            }
                            .onChange(of: key) { oldValue, newValue in
                                // Auto-save when key is pasted (length jump > 5 chars suggests paste)
                                if !newValue.isEmpty && (newValue.count - oldValue.count) > 5 {
                                    viewModel.saveKey(newValue, for: provider.keychainKey)
                                }
                            }

                        if isConfigured {
                            Button(role: .destructive) {
                                viewModel.deleteKey(for: provider.keychainKey)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.borderless)
                            .help("Remove this API key")
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Notion Parent Page Setting

struct NotionParentPageSetting: View {
    @Bindable var viewModel: SettingsViewModel
    @AppStorage("notionParentPageID") private var parentPageID = ""
    @Environment(ServiceContainer.self) private var services
    @State private var testResult: (success: Bool, message: String)?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notion Parent Page")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Button {
                    isTesting = true
                    testResult = nil
                    Task {
                        let apiKey = viewModel.notionKey.isEmpty ? nil : viewModel.notionKey
                        testResult = await services.export.testNotionConnection(apiKey: apiKey)
                        isTesting = false
                    }
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Test Connection", systemImage: "bolt.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTesting)
            }

            Text("Clio creates a \"Clio Meeting Notes\" database under this page. Share the page with your integration, then paste its URL or ID here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Paste Notion page URL or ID", text: $parentPageID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))

                if !parentPageID.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Button(role: .destructive) {
                        parentPageID = ""
                        UserDefaults.standard.removeObject(forKey: "notionParentPageID")
                        // Also clear stored database ID so it re-creates
                        UserDefaults.standard.removeObject(forKey: "notionClioDatabaseID")
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.borderless)
                    .help("Remove parent page ID")
                }
            }

            if let result = testResult {
                Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(result.success ? .green : .red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("How to set up:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("1. Open the Notion page you want to use as parent")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("2. Click \"Share\" and invite your Clio integration")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("3. Copy the page link and paste it above (or leave blank to auto-detect)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .onChange(of: parentPageID) { _, newValue in
            let cleaned = extractNotionPageID(from: newValue)
            if cleaned != newValue {
                parentPageID = cleaned
            }
            UserDefaults.standard.set(cleaned, forKey: "notionParentPageID")
            testResult = nil  // Clear old test results when ID changes
        }
    }

    private func extractNotionPageID(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("notion.so") || trimmed.contains("notion.site") {
            let components = trimmed.components(separatedBy: "/")
            if let last = components.last {
                let parts = last.components(separatedBy: "-")
                if let idPart = parts.last, idPart.count >= 32 {
                    return String(idPart.prefix(32))
                }
                return last.components(separatedBy: "?").first ?? last
            }
        }

        return trimmed.replacingOccurrences(of: "-", with: "")
    }
}

// MARK: - Provider Key Section (non-LLM providers)

struct ProviderKeySection: View {
    let title: String
    let providers: [ProviderKeyConfig]
    let viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            ForEach(providers) { config in
                ProviderKeyCard(config: config, viewModel: viewModel)
            }
        }
    }
}

struct ProviderKeyConfig: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let keychainID: String
    var key: Binding<String>
    let placeholder: String
    let steps: [String]
    let linkLabel: String
    let linkURL: URL?
}

struct ProviderKeyCard: View {
    let config: ProviderKeyConfig
    let viewModel: SettingsViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: config.icon)
                        .frame(width: 20)
                        .foregroundStyle(!config.key.wrappedValue.isEmpty ? .green : .secondary)

                    Text(config.name)
                        .font(.system(size: 14, weight: .medium))

                    Spacer()

                    if !config.key.wrappedValue.isEmpty {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    } else {
                        Text("Set up")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(config.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                Text(step)
                                    .font(.system(size: 13))
                            }
                        }
                    }

                    if let url = config.linkURL {
                        Link(destination: url) {
                            Label(config.linkLabel, systemImage: "arrow.up.right.square")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }

                    HStack(spacing: 8) {
                        SecureField(config.placeholder, text: config.key)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .onSubmit {
                                viewModel.saveKey(config.key.wrappedValue, for: config.keychainID)
                            }
                            .onChange(of: config.key.wrappedValue) { oldValue, newValue in
                                if !newValue.isEmpty && (newValue.count - oldValue.count) > 5 {
                                    viewModel.saveKey(newValue, for: config.keychainID)
                                }
                            }

                        if !config.key.wrappedValue.isEmpty {
                            Button(role: .destructive) {
                                viewModel.deleteKey(for: config.keychainID)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.borderless)
                            .help("Remove this API key")
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}
