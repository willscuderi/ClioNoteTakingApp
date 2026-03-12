import SwiftUI
import AppKit

struct SummaryTabView: View {
    let meeting: Meeting
    let isGenerating: Bool
    var streamedSummary: String = ""
    @Binding var selectedTemplate: SummaryTemplate

    /// Formatted text for sharing via Messages, Mail, AirDrop, etc.
    private var shareText: String {
        let title = meeting.title
        let date = meeting.createdAt.formatted(date: .abbreviated, time: .shortened)
        let summary = meeting.summary ?? ""
        return "Meeting Notes: \(title)\n\(date)\n\n\(summary)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Template picker — show when no summary exists or when regenerating
            if meeting.summary == nil || isGenerating {
                TemplatePickerView(selectedTemplate: $selectedTemplate)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                Divider()
            }

            if isGenerating && !streamedSummary.isEmpty {
                // Streaming: show text as it arrives (plain text during streaming for performance)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(streamedSummary)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            } else if let summary = meeting.summary {
                // Share / Copy toolbar
                HStack(spacing: 8) {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(summary, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)

                    ShareButton(
                        items: [shareText],
                        label: "Share Notes",
                        systemImage: "square.and.arrow.up"
                    )
                    .frame(width: 28, height: 22)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                Divider()

                ScrollView {
                    Text(markdownAttributedString(from: summary))
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
                    Text("Connecting to AI...")
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
                    Text("Select a template above, then click \"Generate Summary\".")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func markdownAttributedString(from text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
