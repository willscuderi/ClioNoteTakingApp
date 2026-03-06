import SwiftUI
import SwiftData

@main
struct ClioApp: App {
    let services = ServiceContainer.makeDefault()
    let modelContainer: ModelContainer
    @State private var showOnboarding = !OnboardingViewModel.hasCompletedOnboarding
    @State private var onboardingVM: OnboardingViewModel?

    init() {
        let schema = Schema([Meeting.self, TranscriptSegment.self, Bookmark.self])

        // Store data in Application Support to avoid sandbox collisions
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDirectory = appSupportURL.appendingPathComponent("com.willscuderi.Clio", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)

        let storeURL = storeDirectory.appendingPathComponent("Clio.store")
        let config = ModelConfiguration("ClioStore", schema: schema, url: storeURL)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    if let onboardingVM {
                        OnboardingView(viewModel: onboardingVM) {
                            onboardingVM.completeOnboarding()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showOnboarding = false
                            }
                        }
                    } else {
                        ProgressView()
                            .onAppear {
                                onboardingVM = OnboardingViewModel(keychain: services.keychain)
                            }
                    }
                } else {
                    ContentView()
                        .environment(services)
                }
            }
        }
        .modelContainer(modelContainer)

        MenuBarExtra("Clio", systemImage: "mic.circle.fill") {
            MenuBarView()
                .environment(services)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
                .environment(services)
        }
        .modelContainer(modelContainer)
    }
}
