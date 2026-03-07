import SwiftUI

struct TranscriptTabView: View {
    let meeting: Meeting
    @Bindable var viewModel: TranscriptViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar row: live indicator + auto-scroll
            HStack {
                if viewModel.isLiveTranscribing {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 7, height: 7)
                        Text("Live")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                Toggle("Auto-scroll", isOn: $viewModel.autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Transcript segments
            if viewModel.segments.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.word.spacing")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("No transcript segments yet.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.segments) { segment in
                                TranscriptSegmentRow(segment: segment)
                                    .id(segment.id)
                            }

                            // Bookmarks section
                            if !meeting.bookmarks.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)

                                Text("Bookmarks")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(meeting.bookmarks.sorted { $0.timestamp < $1.timestamp }) { bookmark in
                                    HStack(spacing: 10) {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundStyle(.orange)
                                            .font(.system(size: 13))
                                        Text(bookmark.formattedTimestamp)
                                            .monospacedDigit()
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Text(bookmark.label.isEmpty ? "Bookmark" : bookmark.label)
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: viewModel.segments.count) { _, _ in
                        if viewModel.autoScroll, let lastID = viewModel.segments.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadSegments(for: meeting)
        }
    }
}
