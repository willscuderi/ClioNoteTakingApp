import SwiftUI
import SwiftData

struct NotesTabView: View {
    @Bindable var meeting: Meeting
    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $noteText)
                .font(.system(size: 15))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .padding(12)

            if noteText.isEmpty {
                Text("Add notes...")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
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
