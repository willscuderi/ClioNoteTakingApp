import AppKit
import SwiftUI

final class FloatingPanel<Content: View>: NSPanel {
    init(contentRect: NSRect = NSRect(x: 0, y: 0, width: 280, height: 64),
         content: @escaping () -> Content) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: content())
        self.contentView = hostingView
    }

    func show() {
        // Position near top-right of the screen containing the mouse cursor.
        // Falls back to the primary screen if no match (e.g. cursor between screens).
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main

        if let screen = targetScreen {
            let screenFrame = screen.visibleFrame
            let panelFrame = frame
            let x = screenFrame.maxX - panelFrame.width - 16
            let y = screenFrame.maxY - panelFrame.height - 16
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        orderFront(nil)
    }
}
