import SwiftUI
import AVFoundation

struct AudioSettingsView: View {
    @Environment(ServiceContainer.self) private var services

    var body: some View {
        Form {
            Section("Microphone") {
                Picker("Input Device", selection: Binding(
                    get: { services.audioDevices.selectedDeviceUID ?? "" },
                    set: { services.audioDevices.selectedDeviceUID = $0.isEmpty ? nil : $0 }
                )) {
                    ForEach(services.audioDevices.availableInputDevices) { device in
                        Text(device.isDefault ? "\(device.name) (Default)" : device.name)
                            .tag(device.uid)
                    }
                }

                Button("Refresh Devices") {
                    services.audioDevices.refreshDevices()
                }
                .font(.caption)
            }

            Section("Audio Source") {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Microphone").font(.body)
                            Text("Records your voice. Best for in-person meetings or when you're speaking.").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "mic.fill")
                    }
                    Divider()
                    Label {
                        VStack(alignment: .leading) {
                            Text("System Audio").font(.body)
                            Text("Records sound from other apps (e.g., Zoom, Teams). Captures remote participants' voices.").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    Divider()
                    Label {
                        VStack(alignment: .leading) {
                            Text("Both").font(.body)
                            Text("Records your mic + system audio. Best for remote meetings to capture everyone.").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "waveform")
                    }
                }
                .padding(.vertical, 4)

                Text("You can change the audio source when starting a recording.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Audio Quality") {
                LabeledContent("Sample Rate") {
                    Text("16,000 Hz (optimized for speech)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Channels") {
                    Text("Mono")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Chunk Duration") {
                    Text("10 seconds")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Local Storage") {
                LabeledContent("Meeting Notes Folder") {
                    Text(MarkdownExportService.meetingNotesPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Button("Open in Finder") {
                    NSWorkspace.shared.open(MarkdownExportService.meetingNotesDirectory)
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            services.audioDevices.refreshDevices()
        }
    }
}
