import SwiftUI

struct RecordingControlsView: View {
    let viewModel: RecordingViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            // Audio source picker
            Picker("Audio Source", selection: Binding(
                get: { viewModel.audioSource },
                set: { viewModel.audioSource = $0 }
            )) {
                Text("System Audio").tag(AudioSource.systemAudio)
                Text("Microphone").tag(AudioSource.microphone)
                Text("Both").tag(AudioSource.both)
            }
            .pickerStyle(.segmented)

            // Main record button
            HStack(spacing: 20) {
                if viewModel.isRecording {
                    Button {
                        Task { await viewModel.togglePause() }
                    } label: {
                        Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(viewModel.isPaused ? .green : .orange)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await viewModel.stopRecording(context: modelContext) }
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await viewModel.startRecording(context: modelContext) }
                    } label: {
                        Image(systemName: "record.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Status
            if viewModel.isRecording {
                Text(viewModel.elapsedTime.durationFormatted)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
