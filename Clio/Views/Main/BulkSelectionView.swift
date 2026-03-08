import SwiftUI
import SwiftData

/// Shown when multiple meetings are selected — displays count + bulk export options
struct BulkSelectionView: View {
    let selectedMeetings: [Meeting]
    let detailVM: MeetingDetailViewModel
    @Binding var selectedMeetingIDs: Set<PersistentIdentifier>

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor.opacity(0.6))

            Text("\(selectedMeetings.count) meetings selected")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)

            // Export menu
            Menu {
                ForEach(ExportDestination.allCases) { dest in
                    Button {
                        let completed = selectedMeetings.filter { $0.status == .completed }
                        guard !completed.isEmpty else { return }
                        Task { await detailVM.bulkExport(meetings: completed, to: dest) }
                    } label: {
                        Label(dest.rawValue, systemImage: dest.icon)
                    }
                }
            } label: {
                Label("Export Selected", systemImage: "arrow.up.doc")
                    .font(.system(size: 15, weight: .medium))
            }
            .menuStyle(.borderedButton)
            .fixedSize()
            .disabled(selectedMeetings.filter { $0.status == .completed }.isEmpty)

            Button("Deselect All") {
                selectedMeetingIDs.removeAll()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.system(size: 14))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
