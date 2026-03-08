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
            ScrollView {
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
                    case .backup:
                        BackupLocationStepView(viewModel: viewModel)
                    case .complete:
                        CompletionStepView(onComplete: onComplete)
                    }
                }
                .frame(maxWidth: .infinity)
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

            if viewModel.screenRecordingNeedsRestart && !viewModel.screenRecordingGranted {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("If you've already granted Screen Recording in System Settings, you may need to restart Clio for it to take effect.")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding(.top, 16)
        .onAppear {
            viewModel.checkPermissions()
            viewModel.startPermissionPolling()
        }
        .onDisappear {
            viewModel.stopPermissionPolling()
        }
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
                            VStack(alignment: .leading, spacing: 6) {
                                if viewModel.useDeepgram {
                                    APIKeySetupGuide(
                                        steps: [
                                            "Click below to open Deepgram's console",
                                            "Sign in or create a free account",
                                            "Go to API Keys and create one",
                                            "Copy and paste it here"
                                        ],
                                        linkLabel: "Open Deepgram Console",
                                        linkURL: URL(string: "https://console.deepgram.com/")!
                                    )

                                    SecureField("Deepgram API Key", text: $viewModel.deepgramAPIKey, prompt: Text("Enter key..."))
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)
                                } else {
                                    APIKeySetupGuide(
                                        steps: [
                                            "Click below to open OpenAI's API keys page",
                                            "Sign in or create a free account",
                                            "Click \"Create new secret key\"",
                                            "Copy and paste it here"
                                        ],
                                        linkLabel: "Open OpenAI API Keys",
                                        linkURL: URL(string: "https://platform.openai.com/api-keys")!
                                    )

                                    SecureField("OpenAI API Key", text: $viewModel.sttAPIKey, prompt: Text("sk-..."))
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)
                                }
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
    @State private var ollamaHelper = OllamaInstallHelper()

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
                    if let url = provider.getKeyURL ?? provider.signupURL {
                        APIKeySetupGuide(
                            steps: provider.setupSteps,
                            linkLabel: provider.getLinkLabel,
                            linkURL: url
                        )
                    }

                    SecureField("API Key", text: $apiKey, prompt: Text(provider.apiKeyPlaceholder))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .onSubmit { }
                }

                if isSelected && provider == .ollama {
                    OllamaSetupView(helper: ollamaHelper)
                } else if isSelected && !provider.requiresAPIKey {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(provider.setupSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14, alignment: .trailing)
                                Text(step)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let url = provider.signupURL {
                            Link(destination: url) {
                                Label(provider.getLinkLabel, systemImage: "arrow.up.right.square")
                                    .font(.caption2.weight(.medium))
                            }
                            .padding(.top, 2)
                        }
                    }
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

// MARK: - Ollama Setup View

struct OllamaSetupView: View {
    @Bindable var helper: OllamaInstallHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch helper.state {
            case .unknown, .checking:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Checking for Ollama...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            case .installed:
                if helper.isReachable {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Ollama is running")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Ollama installed but not running")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("Open Ollama from your Applications folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

            case .notInstalled:
                Text("Ollama runs AI models locally on your Mac — no API key or cloud account needed.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if helper.isHomebrewInstalled() {
                    Button {
                        helper.installViaHomebrew()
                    } label: {
                        Label("Install Ollama", systemImage: "terminal")
                            .font(.caption2.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        helper.openDownloadPage()
                    } label: {
                        Label("Download Ollama", systemImage: "arrow.down.circle")
                            .font(.caption2.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

            case .installing:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Installing in Terminal...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Check the Terminal window for progress")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

            case .installFailed(let msg):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("Install failed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)

                Button {
                    helper.openDownloadPage()
                } label: {
                    Label("Download manually", systemImage: "arrow.up.right.square")
                        .font(.caption2.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .task {
            await helper.check()
        }
    }
}

// MARK: - Step 4: Integrations

struct IntegrationsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                title: "Connect your calendar & notes",
                subtitle: "Clio can read your calendar to know when meetings start, and save notes to the apps you already use."
            )

            // Calendar access
            VStack(spacing: 10) {
                CalendarAccessRow(viewModel: viewModel)

                Divider()
                    .padding(.horizontal, 8)

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
        .onAppear {
            viewModel.checkCalendarAccess()
        }
    }
}

struct CalendarAccessRow: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(viewModel.calendarAccessGranted ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Calendar")
                    .font(.subheadline.weight(.medium))
                Text("Auto-detect meetings from your Mac calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.calendarAccessGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                    Text("Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Connect") {
                    viewModel.requestCalendarAccess()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
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
                        VStack(alignment: .leading, spacing: 8) {
                            APIKeySetupGuide(
                                steps: [
                                    "Click below to open Notion's internal integrations",
                                    "Click \"New integration\" and give it a name (e.g. \"Clio\")",
                                    "Copy the \"Internal Integration Secret\"",
                                    "Paste it here, then share a Notion page with your integration"
                                ],
                                linkLabel: "Create Notion Integration",
                                linkURL: URL(string: "https://www.notion.so/profile/integrations/internal")!
                            )

                            SecureField("Integration token", text: $viewModel.notionToken, prompt: Text("ntn_..."))
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)

                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                Text("Clio will create a \"Clio Meeting Notes\" database in your workspace.")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.tertiary)
                        }
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

// MARK: - Step 5: Backup Location

struct BackupLocationStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                title: "Back up your meeting notes",
                subtitle: "Choose a folder to automatically save your meeting notes. We recommend a cloud-synced folder so your notes are backed up and accessible across devices."
            )

            backupOptions
                .padding(.horizontal, 40)

            if viewModel.backupFolderPath != nil {
                backupInfoNote
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding(.top, 16)
    }

    private var backupOptions: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.suggestedBackupPaths, id: \.path) { suggestion in
                BackupPathRow(
                    name: suggestion.name,
                    path: suggestion.path,
                    isSelected: viewModel.backupFolderPath == suggestion.path,
                    action: { viewModel.backupFolderPath = suggestion.path }
                )
            }

            customFolderButton
        }
    }

    private var customFolderButton: some View {
        let isCustomSelected: Bool = {
            guard let path = viewModel.backupFolderPath else { return false }
            return !viewModel.suggestedBackupPaths.contains(where: { $0.path == path })
        }()

        return Button {
            viewModel.selectBackupFolder()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "folder")
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Choose a different folder...")
                        .font(.subheadline.weight(.medium))
                    if isCustomSelected, let path = viewModel.backupFolderPath {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isCustomSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .quaternarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    private var backupInfoNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)
            Text("Notes will be organized in Year / Month / Date folders automatically.")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

private struct BackupPathRow: View {
    let name: String
    let path: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                    Text("Clio Meeting Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .quaternarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch name {
        case "iCloud Drive": return "icloud"
        case "Google Drive": return "externaldrive.badge.icloud"
        case "Dropbox": return "shippingbox"
        case "OneDrive": return "cloud"
        default: return "folder"
        }
    }
}

// MARK: - Step 6: Completion

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

struct APIKeySetupGuide: View {
    let steps: [String]
    let linkLabel: String
    let linkURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(index + 1).")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 14, alignment: .trailing)
                    Text(step)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: linkURL) {
                Label(linkLabel, systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.medium))
            }
            .padding(.top, 4)
        }
    }
}
