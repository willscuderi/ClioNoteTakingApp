import SwiftUI

struct SummaryTabView: View {
    let meeting: Meeting
    let isGenerating: Bool

    var body: some View {
        if let summary = meeting.summary {
            ScrollView {
                Text(summary)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        } else if isGenerating {
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                Text("Generating summary...")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)
                Text("No summary yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Click \"Generate Summary\" above to create one.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}
