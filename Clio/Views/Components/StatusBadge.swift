import SwiftUI

struct StatusBadge: View {
    let status: MeetingStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .recording: .red.opacity(0.12)
        case .paused: .orange.opacity(0.12)
        case .processing: .blue.opacity(0.12)
        case .completed: .green.opacity(0.12)
        case .failed: .red.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .recording: .red
        case .paused: .orange
        case .processing: .blue
        case .completed: .green
        case .failed: .red
        }
    }
}
