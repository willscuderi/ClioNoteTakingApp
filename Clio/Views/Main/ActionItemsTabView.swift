import SwiftUI
import SwiftData

struct ActionItemsTabView: View {
    let meeting: Meeting
    @Environment(\.modelContext) private var modelContext

    private var sortedItems: [ActionItem] {
        meeting.actionItems.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            return a.text < b.text
        }
    }

    private var uncompletedCount: Int {
        meeting.actionItems.filter { !$0.isCompleted }.count
    }

    var body: some View {
        if meeting.actionItems.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "checklist")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)
                Text("No action items yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Generate a summary to extract action items automatically.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List {
                ForEach(sortedItems) { item in
                    ActionItemRow(item: item) {
                        item.isCompleted.toggle()
                        try? modelContext.save()
                    }
                }
                .onDelete { offsets in
                    let itemsToDelete = offsets.map { sortedItems[$0] }
                    for item in itemsToDelete {
                        meeting.actionItems.removeAll { $0.id == item.id }
                        modelContext.delete(item)
                    }
                    try? modelContext.save()
                }
            }
            .listStyle(.inset)
        }
    }
}
