import Testing
import Foundation
@testable import Clio

@Suite("MeetingListViewModel Tests")
@MainActor
struct MeetingListViewModelTests {
    @Test("Filters meetings by title")
    func filterByTitle() {
        let vm = MeetingListViewModel()
        let meetings = [
            Meeting(title: "Weekly Standup"),
            Meeting(title: "1:1 with Alex"),
            Meeting(title: "Sprint Planning"),
        ]

        vm.searchText = "standup"
        let filtered = vm.filteredMeetings(meetings)
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Weekly Standup")
    }

    @Test("Returns all meetings when search is empty")
    func noFilter() {
        let vm = MeetingListViewModel()
        let meetings = [
            Meeting(title: "Meeting 1"),
            Meeting(title: "Meeting 2"),
        ]

        vm.searchText = ""
        let filtered = vm.filteredMeetings(meetings)
        #expect(filtered.count == 2)
    }

    @Test("Filters meetings by summary content")
    func filterBySummary() {
        let vm = MeetingListViewModel()
        let meeting = Meeting(title: "Generic Title")
        meeting.summary = "Discussed the budget"

        vm.searchText = "budget"
        let filtered = vm.filteredMeetings([meeting])
        #expect(filtered.count == 1)
    }
}
