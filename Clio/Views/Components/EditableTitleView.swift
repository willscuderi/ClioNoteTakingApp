import SwiftUI
import SwiftData

struct EditableTitleView: View {
    @Bindable var meeting: Meeting
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if isEditing {
                TextField("Meeting title", text: $editText)
                    .font(.system(size: 28, weight: .bold))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { commitEdit() }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(meeting.title)
                    .font(.system(size: 28, weight: .bold))
                    .onTapGesture {
                        editText = meeting.title
                        isEditing = true
                        isFocused = true
                    }
            }
        }
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            meeting.title = trimmed
            try? modelContext.save()
        }
        isEditing = false
    }
}
