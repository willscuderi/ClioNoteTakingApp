import AppKit
import SwiftUI
import SwiftData

/// Manages the floating recording indicator panel.
/// Shows/hides the panel based on recording state and keeps it updated with live data.
@MainActor
@Observable
final class RecordingPanelController {
    private var panel: FloatingPanel<AnyView>?
    private var updateTask: Task<Void, Never>?

    var isShowing = false

    func show(recordingVM: RecordingViewModel, modelContext: ModelContext) {
        guard panel == nil else { return }

        let indicator = FloatingRecordingIndicatorLive(
            recordingVM: recordingVM,
            modelContext: modelContext,
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 52),
            content: { AnyView(indicator) }
        )
        panel.show()
        self.panel = panel
        isShowing = true
    }

    func hide() {
        panel?.close()
        panel = nil
        isShowing = false
    }
}

/// Live wrapper that reads directly from RecordingViewModel's @Observable properties.
private struct FloatingRecordingIndicatorLive: View {
    let recordingVM: RecordingViewModel
    let modelContext: ModelContext
    let onClose: () -> Void

    var body: some View {
        FloatingRecordingIndicator(
            elapsedTime: recordingVM.elapsedTime,
            isPaused: recordingVM.isPaused,
            audioLevel: recordingVM.audioLevel,
            onPauseTapped: {
                Task { await recordingVM.togglePause() }
            },
            onStopTapped: {
                Task {
                    await recordingVM.stopRecording(context: modelContext)
                    onClose()
                }
            },
            onBookmarkTapped: {
                recordingVM.addBookmark(context: modelContext)
            }
        )
    }
}
