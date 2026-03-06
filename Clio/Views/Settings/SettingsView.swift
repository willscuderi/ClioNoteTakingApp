import SwiftUI

struct SettingsView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                TabView {
                    GeneralSettingsView(viewModel: viewModel)
                        .tabItem {
                            Label("General", systemImage: "gear")
                        }
                    APIKeysSettingsView(viewModel: viewModel)
                        .tabItem {
                            Label("API Keys", systemImage: "key")
                        }
                    AudioSettingsView()
                        .tabItem {
                            Label("Audio", systemImage: "waveform")
                        }
                    TranscriptionSettingsView(viewModel: viewModel)
                        .tabItem {
                            Label("Transcription", systemImage: "text.bubble")
                        }
                    HotkeySettingsView()
                        .tabItem {
                            Label("Shortcuts", systemImage: "keyboard")
                        }
                }
            } else {
                ProgressView()
            }
        }
        .frame(width: 500, height: 380)
        .onAppear {
            viewModel = SettingsViewModel(keychain: services.keychain)
            viewModel?.loadKeys()
        }
    }
}
