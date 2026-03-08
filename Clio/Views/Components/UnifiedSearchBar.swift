import SwiftUI

/// Unified search bar for the toolbar. Supports keyword search (filters meeting list)
/// and AI search (asks questions across all meetings).
struct UnifiedSearchBar: View {
    enum SearchMode: String, CaseIterable {
        case keyword
        case ai
    }

    @Binding var searchText: String
    @Binding var aiQuestionText: String
    @State private var mode: SearchMode = .keyword
    var onAISubmit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Mode toggle
            Picker("", selection: $mode) {
                Image(systemName: "magnifyingglass").tag(SearchMode.keyword)
                Image(systemName: "sparkles").tag(SearchMode.ai)
            }
            .pickerStyle(.segmented)
            .frame(width: 72)
            .help(mode == .keyword ? "Keyword search" : "Ask AI")

            // TextField changes based on mode
            if mode == .keyword {
                HStack(spacing: 4) {
                    TextField("Search meetings...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .frame(width: 200)
            } else {
                HStack(spacing: 4) {
                    TextField("Ask AI about all meetings...", text: $aiQuestionText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit { onAISubmit() }

                    Button {
                        onAISubmit()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                aiQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary : Color.accentColor
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(aiQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .frame(width: 200)
            }
        }
    }
}
