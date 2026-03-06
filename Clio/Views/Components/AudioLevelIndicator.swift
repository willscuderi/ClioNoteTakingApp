import SwiftUI

struct AudioLevelIndicator: View {
    let level: Float
    let barCount: Int

    init(level: Float, barCount: Int = 5) {
        self.level = level
        self.barCount = barCount
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 16)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount)
        return level > threshold ? CGFloat(6 + index * 2) : 4
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        guard level > threshold else { return .secondary.opacity(0.3) }

        if index < barCount / 2 {
            return .green
        } else if index < barCount * 3 / 4 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        AudioLevelIndicator(level: 0.0)
        AudioLevelIndicator(level: 0.3)
        AudioLevelIndicator(level: 0.6)
        AudioLevelIndicator(level: 0.9)
    }
    .padding()
}
