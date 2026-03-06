import SwiftUI
import AVFoundation

struct AudioSettingsView: View {
    @State private var selectedInputDevice: String = "Default"
    @State private var availableDevices: [String] = ["Default"]

    var body: some View {
        Form {
            Section("Microphone") {
                Picker("Input Device", selection: $selectedInputDevice) {
                    ForEach(availableDevices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
            }

            Section("System Audio") {
                Text("System audio is captured via ScreenCaptureKit.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("You may be prompted for Screen Recording permission on first use.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
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
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAudioDevices()
        }
    }

    private func loadAudioDevices() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        availableDevices = ["Default"] + devices.map(\.localizedName)
    }
}
