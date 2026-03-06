import SwiftUI
import SwiftData

struct SidebarView: View {
    @Bindable var viewModel: MeetingListViewModel
    @Binding var selectedMeeting: Meeting?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]

    var body: some View {
        List(selection: $selectedMeeting) {
            ForEach(viewModel.filteredMeetings(meetings)) { meeting in
                MeetingRowView(meeting: meeting)
                    .tag(meeting)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            viewModel.deleteMeeting(meeting, context: modelContext)
                            if selectedMeeting == meeting {
                                selectedMeeting = nil
                            }
                        }
                    }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search meetings")
        .navigationTitle("Meetings")
        .overlay {
            if meetings.isEmpty {
                ContentUnavailableView(
                    "No Meetings Yet",
                    systemImage: "waveform",
                    description: Text("Start a recording to create your first meeting.")
                )
            } else if viewModel.filteredMeetings(meetings).isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }
}
