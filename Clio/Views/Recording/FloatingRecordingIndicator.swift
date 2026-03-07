import SwiftUI

struct FloatingRecordingIndicator: View {
    let elapsedTime: TimeInterval
    let isPaused: Bool
    let audioLevel: Float
    let onPauseTapped: () -> Void
    let onStopTapped: () -> Void
    let onBookmarkTapped: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Audio level bars
            AudioLevelBars(level: audioLevel, isPaused: isPaused)
                .frame(width: 20, height: 18)

            // Timer
            Text(elapsedTime.durationFormatted)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            // Controls
            Button(action: onBookmarkTapped) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help("Add bookmark")

            Button(action: onPauseTapped) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .help(isPaused ? "Resume" : "Pause")

            Button(action: onStopTapped) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Stop recording")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isPaused ? Color.orange.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
        .frame(width: 260)
    }
}

/// Animated audio level bars that respond to the current audio level.
struct AudioLevelBars: View {
    let level: Float
    let isPaused: Bool

    private let barCount = 4

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor)
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
    }

    private var barColor: Color {
        if isPaused { return .orange }
        if level > 0.5 { return .red }
        if level > 0.2 { return .orange }
        return .green
    }

    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 18

        if isPaused { return minHeight }

        // Each bar has a progressively higher threshold
        let threshold = Float(index) / Float(barCount)
        let normalizedLevel = min(1.0, level * 3.0) // Amplify for visibility
        let barLevel = max(0, normalizedLevel - threshold * 0.5)

        return minHeight + CGFloat(barLevel) * (maxHeight - minHeight)
    }
}

#Preview {
    FloatingRecordingIndicator(
        elapsedTime: 125,
        isPaused: false,
        audioLevel: 0.3,
        onPauseTapped: {},
        onStopTapped: {},
        onBookmarkTapped: {}
    )
    .padding()
}
