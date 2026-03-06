import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            if viewModel.currentStep != .complete {
                OnboardingProgressDots(
                    currentStep: viewModel.stepIndex,
                    totalSteps: viewModel.totalSteps
                )
                .padding(.top, 24)
                .padding(.bottom, 8)
            }

            // Step content
            Group {
                switch viewModel.currentStep {
                case .permissions:
                    PermissionsStepView(viewModel: viewModel)
                case .transcription:
                    TranscriptionStepView(viewModel: viewModel)
                case .llm:
                    LLMStepView(viewModel: viewModel)
                case .integrations:
                    IntegrationsStepView(viewModel: viewModel)
                case .complete:
                    CompletionStepView(onComplete: onComplete)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation
            if viewModel.currentStep != .complete {
                OnboardingNavigationBar(viewModel: viewModel)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 640, height: 560)
        .background(.background)
    }
}

// MARK: - Progress Dots

struct OnboardingProgressDots: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }
}

// MARK: - Navigation Bar

struct OnboardingNavigationBar: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        HStack {
            if viewModel.canGoBack {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.goBack()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Set up later") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.goNext()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.callout)

            Button("Continue") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.goNext()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 1: Permissions

struct PermissionsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            StepHeader(
                title: "How Clio listens",
                subtitle: "Clio listens to your meetings the same way you do, through your speakers and microphone. Nothing is sent anywhere unless you choose to. We need these permissions so Clio can hear what's being said."
            )

            VStack(spacing: 12) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Capture audio from your microphone",
                    isGranted: viewModel.micPermissionGranted,
                    action: viewModel.requestMicPermission
                )

                PermissionRow(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Recording",
                    description: "Capture system audio from your meetings",
                    isGranted: viewModel.screenRecordingGranted,
                    action: viewModel.requestScreenRecording
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 16)
        .onAppear { viewModel.checkPermissions() }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button("Grant Access") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }
}

// MARK: - Step 2: Transcription

struct TranscriptionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                title: "How Clio understands speech",
                subtitle: "Choose how Clio converts speech to text."
            )

            HStack(spacing: 16) {
                // Cloud card
                TranscriptionOptionCard(
                    title: "Cloud",
                    badge: "Recommended",
                    icon: "cloud.fill",
                    isSelected: viewModel.transcriptionChoice == .cloud,
                    action: { viewModel.transcriptionChoice = .cloud }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clio sends your audio to OpenAI's Whisper service to turn speech into text. It's fast and accurate. Most meetings cost less than a penny to transcribe.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if viewModel.transcriptionChoice == .cloud {
                            if viewModel.useDeepgram {
                                SecureField("Deepgram API Key", text: $viewModel.deepgramAPIKey, prompt: Text("Enter key..."))
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                            } else {
                                SecureField("OpenAI API Key", text: $viewModel.sttAPIKey, prompt: Text("sk-..."))
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                            }

                            HStack(spacing: 4) {
                                if let url = URL(string: "https://platform.openai.com/api-keys") {
                                    Link("How to get a key", destination: url)
                                        .font(.caption2)
                                }
                                Text("(takes 2 minutes)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            Toggle("Use Deepgram instead", isOn: $viewModel.useDeepgram)
                                .font(.caption)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                        }
                    }
                }

                // On-device card
                TranscriptionOptionCard(
                    title: "On-device",
                    badge: "Private",
                    icon: "desktopcomputer",
                    isSelected: viewModel.transcriptionChoice == .onDevice,
                    action: { viewModel.transcriptionChoice = .onDevice }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clio uses a built-in speech engine that runs entirely on your Mac. Nothing leaves your computer. It's slightly slower and works best on newer Macs (M2 or later).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if viewModel.transcriptionChoice == .onDevice {
                            if viewModel.modelDownloaded {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("Speech model ready")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if viewModel.isDownloadingModel {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: viewModel.modelDownloadProgress)
                                        .controlSize(.small)
                                    Text("\(Int(viewModel.modelDownloadProgress * 100))% downloaded")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            } else {
                                Button {
                                    viewModel.downloadWhisperModel()
                                } label: {
                                    Label("Download speech model (141 MB)", systemImage: "arrow.down.circle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 40)

            Text("You can always switch between these later in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.top, 16)
    }
}

struct TranscriptionOptionCard<Content: View>: View {
    let title: String
    let badge: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15)))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: LLM

struct LLMStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                title: "How Clio writes your notes",
                subtitle: "After your meeting, Clio reads the transcript and writes a clean summary with action items, key decisions, and follow-ups. Pick the AI assistant you already use:"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LLMProvider.allCases) { provider in
                        LLMProviderCard(
                            provider: provider,
                            isSelected: viewModel.selectedLLMProvider == provider,
                            apiKey: Binding(
                                get: { viewModel.selectedLLMProvider == provider ? viewModel.llmAPIKey : "" },
                                set: { viewModel.llmAPIKey = $0 }
                            ),
                            action: {
                                viewModel.selectedLLMProvider = provider
                                viewModel.llmAPIKey = ""
                            }
                        )
                    }
                }
                .padding(.horizontal, 40)
            }

            Text("An API key is like a password that lets Clio use this service on your behalf. Clio never stores your key in the cloud. It's saved securely on your Mac in your system keychain.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 16)
    }
}

struct LLMProviderCard: View {
    let provider: LLMProvider
    let isSelected: Bool
    @Binding var apiKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: provider.iconName)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text(provider.companyName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if isSelected && provider.requiresAPIKey {
                    SecureField("API Key", text: $apiKey, prompt: Text(provider.apiKeyPlaceholder))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .onSubmit { }

                    if let url = provider.getKeyURL {
                        Link("How to get your API key", destination: url)
                            .font(.caption2)
                    }
                }

                if isSelected && !provider.requiresAPIKey {
                    Text("Make sure Ollama is running on your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(width: 150, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 4: Integrations

struct IntegrationsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                title: "Where should Clio save your notes?",
                subtitle: "After each meeting, Clio can automatically send your notes to the apps you already use. Pick one or more:"
            )

            VStack(spacing: 10) {
                ForEach(ExportFormat.allCases) { format in
                    IntegrationToggleRow(
                        format: format,
                        isEnabled: viewModel.enabledExports.contains(format),
                        viewModel: viewModel,
                        toggle: { viewModel.toggleExport(format) }
                    )
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 16)
    }
}

struct IntegrationToggleRow: View {
    let format: ExportFormat
    let isEnabled: Bool
    @Bindable var viewModel: OnboardingViewModel
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: format.iconName)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(format.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(format.setupDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in toggle() }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            .padding(12)

            // Expanded setup fields
            if isEnabled {
                Group {
                    switch format {
                    case .notion:
                        SecureField("Notion integration token", text: $viewModel.notionToken, prompt: Text("ntn_..."))
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    case .obsidian:
                        FolderPickerRow(label: "Obsidian vault", path: $viewModel.obsidianVaultPath)
                    case .markdown:
                        FolderPickerRow(label: "Markdown folder", path: $viewModel.markdownFolderPath)
                    case .googleDocs:
                        Text("Google Docs integration coming soon")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    case .appleNotes:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }
}

struct FolderPickerRow: View {
    let label: String
    @Binding var path: URL?

    var body: some View {
        HStack {
            Text(path?.lastPathComponent ?? "No folder selected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Choose...") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.message = "Choose \(label) location"
                if panel.runModal() == .OK {
                    path = panel.url
                }
            }
            .controlSize(.small)
        }
    }
}

// MARK: - Step 5: Completion

struct CompletionStepView: View {
    var onComplete: () -> Void
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }

            Text("You're all set")
                .font(.title.weight(.semibold))

            Text("Clio will sit in your menu bar. Click the icon or press **\u{2318}\u{21E7}R** to start recording.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            HStack(spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("Look for this icon in your menu bar")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))

            Spacer()

            Button("Get Started") { onComplete() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Shared Components

struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
