import SwiftUI
import AppKit

/// A button that presents the native macOS NSSharingServicePicker.
/// Pass the content to share (strings, URLs, images, etc.) as `items`.
struct ShareButton: NSViewRepresentable {
    var items: [Any]
    var label: String = "Share"
    var systemImage: String = "square.and.arrow.up"

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .toolbar
        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: label)
        button.title = ""
        button.imagePosition = .imageOnly
        button.target = context.coordinator
        button.action = #selector(Coordinator.showPicker(_:))
        button.toolTip = label
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.items = items
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(items: items)
    }

    class Coordinator: NSObject {
        var items: [Any]

        init(items: [Any]) {
            self.items = items
        }

        @objc func showPicker(_ sender: NSButton) {
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
