import SwiftUI

struct FloatingRecordingIndicator: View {
    let elapsedTime: TimeInterval
    let isPaused: Bool
    let onPauseTapped: () -> Void
    let onStopTapped: () -> Void
    let onBookmarkTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Pulsing record dot
            Circle()
                .fill(isPaused ? .orange : .red)
                .frame(width: 10, height: 10)
                .opacity(isPaused ? 0.6 : 1.0)
                .animation(
                    isPaused ? .none : .easeInOut(duration: 1).repeatForever(),
                    value: isPaused
                )

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

            Button(action: onPauseTapped) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button(action: onStopTapped) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 260)
    }
}

#Preview {
    FloatingRecordingIndicator(
        elapsedTime: 125,
        isPaused: false,
        onPauseTapped: {},
        onStopTapped: {},
        onBookmarkTapped: {}
    )
    .padding()
}
