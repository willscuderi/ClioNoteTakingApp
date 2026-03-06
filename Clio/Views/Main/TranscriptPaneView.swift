import SwiftUI

struct TranscriptPaneView: View {
    let meeting: Meeting
    @Bindable var viewModel: TranscriptViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                if viewModel.isLiveTranscribing {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Toggle("Auto-scroll", isOn: $viewModel.autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Transcript segments
            if viewModel.segments.isEmpty {
                VStack {
                    Spacer()
                    Text("No transcript segments yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.segments) { segment in
                                TranscriptSegmentRow(segment: segment)
                                    .id(segment.id)
                            }
                        }
                        .padding()
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
