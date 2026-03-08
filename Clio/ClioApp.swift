import SwiftUI
import SwiftData
import Sparkle

@main
struct ClioApp: App {
    let services = ServiceContainer.makeDefault()
    let modelContainer: ModelContainer
    @State private var showOnboarding = !OnboardingViewModel.hasCompletedOnboarding
    @State private var onboardingVM: OnboardingViewModel?
    @State private var meetingDetectionPanel = MeetingDetectionPanelController()
    @State private var appRecordingVM: RecordingViewModel?
    @State private var showCrashRecovery = false
    @State private var crashRecoveryMeetings: [Meeting] = []
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    init() {
        let schema = Schema([Meeting.self, TranscriptSegment.self, Bookmark.self, MeetingFolder.self])

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
                    ContentView(recordingVM: appRecordingVM)
                        .environment(services)
                }
            }
            .onAppear {
                // Create the shared recording VM once we have a model context
                if appRecordingVM == nil {
                    appRecordingVM = RecordingViewModel(services: services)
                }
                // Bind meeting detection panel at app level
                if let vm = appRecordingVM {
                    meetingDetectionPanel.bind(
                        services: services,
                        recordingVM: vm,
                        modelContext: modelContainer.mainContext
                    )
                }
                // Start calendar refresh
                services.calendar.checkAuthorizationStatus()
                if services.calendar.isAuthorized {
                    services.calendar.refreshUpcomingMeetings()
                    services.calendar.startRefreshTimer()
                }

                // Request notification permission
                services.notifications.requestPermission()

                // Check for crash recovery (orphaned recordings)
                let orphaned = services.recovery.findOrphanedRecordings(in: modelContainer.mainContext)
                if !orphaned.isEmpty {
                    crashRecoveryMeetings = orphaned
                    showCrashRecovery = true
                    services.notifications.sendCrashRecovered(meetingCount: orphaned.count)
                }
            }
            .sheet(isPresented: $showCrashRecovery) {
                CrashRecoveryView(
                    meetings: crashRecoveryMeetings,
                    recovery: services.recovery,
                    onDismiss: {
                        showCrashRecovery = false
                        crashRecoveryMeetings = []
                    }
                )
            }
        }
        .modelContainer(modelContainer)

        MenuBarExtra("Clio", image: "MenuBarIcon") {
            MenuBarView()
                .environment(services)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)

        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(services)
        }
        .modelContainer(modelContainer)
    }
}
