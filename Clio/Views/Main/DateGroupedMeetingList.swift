import SwiftUI
import SwiftData

// MARK: - Date Group Enum

enum DateGroup: Hashable, Comparable {
    case today
    case yesterday
    case earlierThisWeek
    case lastWeek
    case earlierThisMonth
    case month(year: Int, month: Int) // older months
    case year(Int)                    // older years

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .earlierThisWeek: return "Earlier This Week"
        case .lastWeek: return "Last Week"
        case .earlierThisMonth: return "Earlier This Month"
        case .month(_, let month):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            let date = Calendar.current.date(from: DateComponents(month: month))!
            return formatter.string(from: date)
        case .year(let y): return String(y)
        }
    }

    /// Whether this section starts collapsed by default
    var startsCollapsed: Bool {
        switch self {
        case .today, .yesterday, .earlierThisWeek, .lastWeek, .earlierThisMonth:
            return false
        case .month, .year:
            return true
        }
    }

    /// Sort order — lower = more recent = appears first
    private var sortOrder: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .earlierThisWeek: return 2
        case .lastWeek: return 3
        case .earlierThisMonth: return 4
        case .month: return 5
        case .year: return 6
        }
    }

    static func < (lhs: DateGroup, rhs: DateGroup) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        // For same sort order, compare by date (more recent first)
        switch (lhs, rhs) {
        case (.month(let ly, let lm), .month(let ry, let rm)):
            if ly != ry { return ly > ry }
            return lm > rm
        case (.year(let ly), .year(let ry)):
            return ly > ry
        default:
            return false
        }
    }
}

// MARK: - Date Grouping Logic

struct DateGrouper {
    static func group(_ meetings: [Meeting]) -> [(key: DateGroup, meetings: [Meeting])] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek),
              let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start
        else {
            return [(key: .today, meetings: meetings)]
        }

        let currentYear = calendar.component(.year, from: now)
        _ = calendar.component(.month, from: now)

        var groups: [DateGroup: [Meeting]] = [:]

        for meeting in meetings {
            let meetingDate = calendar.startOfDay(for: meeting.createdAt)
            let group: DateGroup

            if meetingDate >= today {
                group = .today
            } else if meetingDate >= yesterday {
                group = .yesterday
            } else if meetingDate >= startOfWeek {
                group = .earlierThisWeek
            } else if meetingDate >= startOfLastWeek {
                group = .lastWeek
            } else if meetingDate >= startOfMonth {
                group = .earlierThisMonth
            } else {
                let meetingYear = calendar.component(.year, from: meeting.createdAt)
                let meetingMonth = calendar.component(.month, from: meeting.createdAt)

                if meetingYear == currentYear {
                    // Same year, different month
                    group = .month(year: meetingYear, month: meetingMonth)
                } else {
                    // Different year — group by year, then month within
                    group = .month(year: meetingYear, month: meetingMonth)
                }
            }

            groups[group, default: []].append(meeting)
        }

        // Sort each group's meetings by date (newest first) and sort groups
        return groups
            .map { (key: $0.key, meetings: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.key < $1.key }
    }
}

// MARK: - Date Grouped Meeting List View

struct DateGroupedMeetingList: View {
    let meetings: [Meeting]
    let folders: [MeetingFolder]
    @Binding var selectedMeetingIDs: Set<PersistentIdentifier>
    let onDelete: (Meeting) -> Void
    let onMoveToFolder: (Meeting, MeetingFolder?) -> Void

    @State private var collapsedSections: Set<DateGroup> = []

    private var groupedMeetings: [(key: DateGroup, meetings: [Meeting])] {
        DateGrouper.group(meetings)
    }

    var body: some View {
        ForEach(groupedMeetings, id: \.key) { group in
            if group.key.startsCollapsed || collapsedSections.contains(group.key) {
                // Collapsible section
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { !collapsedSections.contains(group.key) },
                        set: { isExpanded in
                            if isExpanded {
                                collapsedSections.remove(group.key)
                            } else {
                                collapsedSections.insert(group.key)
                            }
                        }
                    )
                ) {
                    meetingRows(for: group.meetings)
                } label: {
                    sectionHeader(for: group.key, count: group.meetings.count)
                }
            } else {
                // Always-expanded section
                Section {
                    meetingRows(for: group.meetings)
                } header: {
                    sectionHeader(for: group.key, count: group.meetings.count)
                }
            }
        }
        .onAppear {
            // Initialize collapsed state for sections that start collapsed
            for group in groupedMeetings where group.key.startsCollapsed {
                collapsedSections.insert(group.key)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(for group: DateGroup, count: Int) -> some View {
        HStack {
            Text(group.displayName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func meetingRows(for meetings: [Meeting]) -> some View {
        ForEach(meetings) { meeting in
            MeetingRowView(meeting: meeting)
                .tag(meeting.persistentModelID)
                .draggable(meeting.id.uuidString)
                .contextMenu {
                    if !folders.isEmpty {
                        Menu("Move to Folder") {
                            Button("None (Remove from folder)") {
                                onMoveToFolder(meeting, nil)
                            }
                            Divider()
                            ForEach(folders) { folder in
                                Button(folder.name) {
                                    onMoveToFolder(meeting, folder)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        onDelete(meeting)
                    }
                }
        }
    }
}
