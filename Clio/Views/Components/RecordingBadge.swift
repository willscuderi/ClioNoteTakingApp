import SwiftUI

struct RecordingBadge: View {
    let isRecording: Bool
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(isRecording ? .red : .clear)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                isRecording
                    ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                    : .default,
                value: isAnimating
            )
            .onChange(of: isRecording) { _, newValue in
                isAnimating = newValue
            }
            .onAppear {
                isAnimating = isRecording
            }
    }
}

#Preview {
    HStack(spacing: 16) {
        RecordingBadge(isRecording: true)
        RecordingBadge(isRecording: false)
    }
    .padding()
}
