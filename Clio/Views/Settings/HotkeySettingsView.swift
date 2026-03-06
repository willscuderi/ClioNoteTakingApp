import SwiftUI

struct HotkeySettingsView: View {
    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                HStack {
                    Text("Toggle Recording")
                    Spacer()
                    Text("⌘⇧R")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                HStack {
                    Text("Pause / Resume")
                    Spacer()
                    Text("⌘⇧P")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                HStack {
                    Text("Add Bookmark")
                    Spacer()
                    Text("⌘⇧B")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Section {
                Text("Global keyboard shortcuts work even when Clio is in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // TODO: Add shortcut customization UI
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
