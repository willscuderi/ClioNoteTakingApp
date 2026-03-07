import SwiftUI

struct RecordingControlsView: View {
    let viewModel: RecordingViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            // Audio source picker with descriptions
            Picker("Audio Source", selection: Binding(
                get: { viewModel.audioSource },
                set: { viewModel.audioSource = $0 }
            )) {
                Label("Microphone", systemImage: "mic.fill").tag(AudioSource.microphone)
                Label("System Audio", systemImage: "speaker.wave.2.fill").tag(AudioSource.systemAudio)
                Label("Both", systemImage: "waveform").tag(AudioSource.both)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isRecording)

            Text(audioSourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                VStack(spacing: 4) {
                    Text(viewModel.elapsedTime.durationFormatted)
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if let status = viewModel.transcriptionStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var audioSourceDescription: String {
        switch viewModel.audioSource {
        case .microphone:
            "Records your voice through the selected microphone."
        case .systemAudio:
            "Records audio from other apps (Zoom, Teams, etc.). Requires Screen Recording permission."
        case .both:
            "Records your mic + system audio. Best for remote meetings."
        }
    }
}
