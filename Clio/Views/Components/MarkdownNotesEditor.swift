import SwiftUI
import AppKit

/// A Markdown-aware notes editor with a formatting toolbar.
/// Wraps NSTextView for selection range access.
struct MarkdownNotesEditor: View {
    @Binding var text: String
    var fontSize: CGFloat = 15
    var placeholder: String = "Add notes..."

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    var body: some View {
        VStack(spacing: 0) {
            // Formatting toolbar
            HStack(spacing: 2) {
                FormatButton(title: "H", icon: nil, help: "Heading") {
                    insertPrefix("# ")
                }
                FormatButton(title: "B", icon: nil, help: "Bold") {
                    wrapSelection(with: "**")
                }
                .fontWeight(.bold)
                FormatButton(title: "I", icon: nil, help: "Italic") {
                    wrapSelection(with: "*")
                }
                .italic()
                FormatButton(title: nil, icon: "list.bullet", help: "Bullet list") {
                    insertPrefix("- ")
                }
                FormatButton(title: nil, icon: "checklist", help: "Checkbox") {
                    insertPrefix("- [ ] ")
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Text editor
            MarkdownTextView(
                text: $text,
                selectedRange: $selectedRange,
                fontSize: fontSize,
                placeholder: placeholder
            )
        }
    }

    // MARK: - Formatting Actions

    private func wrapSelection(with marker: String) {
        let nsText = text as NSString
        let range = selectedRange

        if range.length > 0 {
            // Wrap the selected text
            let selected = nsText.substring(with: range)
            let replacement = marker + selected + marker
            let before = nsText.substring(to: range.location)
            let after = nsText.substring(from: range.location + range.length)
            text = before + replacement + after
            // Move cursor to after the wrapped text
            selectedRange = NSRange(location: range.location + replacement.count, length: 0)
        } else {
            // Insert markers with cursor between them
            let location = min(range.location, nsText.length)
            let before = nsText.substring(to: location)
            let after = nsText.substring(from: location)
            text = before + marker + marker + after
            selectedRange = NSRange(location: location + marker.count, length: 0)
        }
    }

    private func insertPrefix(_ prefix: String) {
        let nsText = text as NSString
        let location = min(selectedRange.location, nsText.length)

        // Find the start of the current line
        let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
        let lineStart = lineRange.location

        let before = nsText.substring(to: lineStart)
        let after = nsText.substring(from: lineStart)
        text = before + prefix + after
        selectedRange = NSRange(location: lineStart + prefix.count, length: 0)
    }
}

// MARK: - Format Button

private struct FormatButton: View {
    let title: String?
    let icon: String?
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                } else if let title {
                    Text(title)
                        .font(.system(size: 13))
                }
            }
            .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .help(help)
    }
}

// MARK: - NSTextView Wrapper

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var fontSize: CGFloat
    var placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.delegate = context.coordinator

        // Set up line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        textView.defaultParagraphStyle = paragraphStyle

        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Only update text if it actually changed (avoid cursor jumping)
        if textView.string != text {
            let previousRange = textView.selectedRange()
            textView.string = text
            // Try to restore a valid selection
            let newRange = NSRange(
                location: min(selectedRange.location, textView.string.count),
                length: min(selectedRange.length, max(0, textView.string.count - selectedRange.location))
            )
            textView.setSelectedRange(newRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: NSTextView?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.selectedRange = textView.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.selectedRange = textView.selectedRange()
        }
    }
}
