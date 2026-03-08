import SwiftUI
import SwiftData

struct NotesTabView: View {
    @Bindable var meeting: Meeting
    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""

    var body: some View {
        MarkdownNotesEditor(text: $noteText)
            .onAppear {
                noteText = meeting.notes ?? ""
            }
            .onChange(of: noteText) { _, newValue in
                meeting.notes = newValue.isEmpty ? nil : newValue
            }
            .onDisappear {
                try? modelContext.save()
            }
    }
}
