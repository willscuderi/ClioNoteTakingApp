import SwiftUI
import SwiftData

/// Shown during active recording — side-by-side live transcript + notes editor
struct RecordingSplitView: View {
    let meeting: Meeting
    @Bindable var transcriptVM: TranscriptViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Compact Header
            HStack(spacing: 12) {
                // Recording indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .modifier(PulseAnimation())

                    Text(meeting.status == .paused ? "Paused" : "Recording")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(meeting.status == .paused ? .orange : .red)
                }

                Text(meeting.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Text(meeting.durationSeconds.durationFormatted)
                    .font(.system(size: 14).monospacedDigit())
                    .foregroundStyle(.secondary)

                Toggle("Auto-scroll", isOn: $transcriptVM.autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // MARK: - Split Panes
            HSplitView {
                // Left: Live Transcript
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Transcript", systemImage: "text.word.spacing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if transcriptVM.isLiveTranscribing {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 5, height: 5)
                                Text("Live")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.red)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    if transcriptVM.segments.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Text("Waiting for speech...")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 10) {
                                    ForEach(transcriptVM.segments) { segment in
                                        TranscriptSegmentRow(segment: segment)
                                            .id(segment.id)
                                    }
                                }
                                .padding(16)
                            }
                            .onChange(of: transcriptVM.segments.count) { _, _ in
                                if transcriptVM.autoScroll, let lastID = transcriptVM.segments.last?.id {
                                    withAnimation {
                                        proxy.scrollTo(lastID, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 250)

                // Right: Notes Editor
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Notes", systemImage: "note.text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    MarkdownNotesEditor(
                        text: $noteText,
                        fontSize: 14,
                        placeholder: "Type your notes here..."
                    )
                }
                .frame(minWidth: 200)
            }
        }
        .onAppear {
            noteText = meeting.notes ?? ""
            transcriptVM.loadSegments(for: meeting)
            transcriptVM.startListening()
        }
        .onChange(of: noteText) { _, newValue in
            meeting.notes = newValue.isEmpty ? nil : newValue
        }
        .onDisappear {
            transcriptVM.stopListening()
            try? modelContext.save()
        }
    }
}

// MARK: - Pulse Animation

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
