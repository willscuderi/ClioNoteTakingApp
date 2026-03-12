import AppKit
import SwiftUI
import SwiftData

/// Manages a floating overlay panel that appears when a meeting app is detected.
/// Shows on top of all apps regardless of Clio's window state.
@MainActor
@Observable
final class MeetingDetectionPanelController {
    private var panel: FloatingPanel<AnyView>?
    private var observation: Task<Void, Never>?
    private weak var services: ServiceContainer?
    private var modelContext: ModelContext?
    private var recordingVM: RecordingViewModel?

    var isShowing = false

    /// Start observing the meeting detector and show/hide the panel automatically.
    func bind(services: ServiceContainer, recordingVM: RecordingViewModel, modelContext: ModelContext) {
        self.services = services
        self.recordingVM = recordingVM
        self.modelContext = modelContext

        // Start monitoring immediately at app level
        services.meetingDetector.startMonitoring()

        // Watch for changes in detector state
        observation?.cancel()
        observation = Task { [weak self] in
            // Poll detector state since @Observable doesn't support async sequences
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                await self.checkDetectorState()
            }
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        hide()
    }

    private func checkDetectorState() {
        guard let services, let recordingVM else { return }

        if services.meetingDetector.shouldPromptRecording,
           !recordingVM.isRecording,
           !isShowing {
            show()
        } else if !services.meetingDetector.shouldPromptRecording, isShowing {
            hide()
        }
    }

    private func show() {
        guard panel == nil,
              let services,
              let recordingVM,
              let modelContext else { return }

        let appName = services.meetingDetector.detectedMeetingApp ?? "Meeting app"
        let calendarTitle = services.calendar.meetingInProgress()?.title
            ?? services.calendar.meetingStartingSoon()?.title

        let rollingBufferEnabled = UserDefaults.standard.bool(forKey: "enableRollingBuffer")
        let rollingBufferMinutes = max(1, UserDefaults.standard.integer(forKey: "rollingBufferMinutes"))
        let hasRetroactiveAudio = rollingBufferEnabled && recordingVM.isPassiveListening

        let content = MeetingDetectionOverlay(
            appName: appName,
            calendarMeetingTitle: calendarTitle,
            showRetroactive: hasRetroactiveAudio,
            retroactiveMinutes: rollingBufferMinutes,
            onRecord: { [weak self] in
                Task {
                    await recordingVM.startRecording(context: modelContext)
                }
                services.meetingDetector.dismissPrompt()
                self?.hide()
            },
            onRetroactiveCapture: hasRetroactiveAudio ? { [weak self] in
                Task {
                    await recordingVM.captureRetroactive(minutes: rollingBufferMinutes, context: modelContext)
                }
                services.meetingDetector.dismissPrompt()
                self?.hide()
            } : nil,
            onDismiss: { [weak self] in
                services.meetingDetector.dismissPrompt()
                self?.hide()
            }
        )

        let panelHeight = hasRetroactiveAudio ? 150.0 : 120.0
        let newPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: panelHeight),
            content: { AnyView(content) }
        )
        newPanel.show()
        self.panel = newPanel
        isShowing = true
    }

    private func hide() {
        panel?.close()
        panel = nil
        isShowing = false
    }
}

// MARK: - Meeting Detection Overlay View

private struct MeetingDetectionOverlay: View {
    let appName: String
    let calendarMeetingTitle: String?
    var showRetroactive: Bool = false
    var retroactiveMinutes: Int = 3
    let onRecord: () -> Void
    var onRetroactiveCapture: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(appName) detected")
                        .font(.system(size: 13, weight: .semibold))

                    if let title = calendarMeetingTitle {
                        Text(title)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button(action: onRecord) {
                    Label("Start Recording", systemImage: "record.circle")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button("Not now", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .font(.system(size: 12))
            }

            // Retroactive capture button
            if showRetroactive, let onRetroactiveCapture {
                Button(action: onRetroactiveCapture) {
                    Label("Capture last \(retroactiveMinutes) min", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(.orange)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 300)
    }
}
