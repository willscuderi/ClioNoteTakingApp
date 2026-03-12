import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AnalyticsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Stat Cards
                Text("Meeting Analytics")
                    .font(.system(size: 22, weight: .semibold))

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(title: "Total Meetings", value: "\(viewModel.totalMeetings)", icon: "person.2")
                    StatCard(title: "Total Hours", value: String(format: "%.1f", viewModel.totalHours), icon: "clock")
                    StatCard(title: "Avg Duration", value: formatDuration(viewModel.averageDuration), icon: "timer")
                    StatCard(title: "This Week", value: "\(viewModel.meetingsThisWeek)", icon: "calendar")
                }

                // MARK: - Duration Chart
                if !viewModel.weeklyDurations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meeting Durations (Last 2 Weeks)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)

                        Chart(viewModel.weeklyDurations, id: \.date) { item in
                            BarMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Minutes", item.duration)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 2)) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxisLabel("Minutes")
                        .frame(height: 200)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // MARK: - Speaker Breakdown
                if !viewModel.speakerBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speaker Participation (by text volume)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)

                        let total = viewModel.speakerBreakdown.reduce(0) { $0 + $1.characterCount }

                        ForEach(viewModel.speakerBreakdown, id: \.speaker) { item in
                            HStack(spacing: 10) {
                                Text(item.speaker)
                                    .font(.system(size: 13))
                                    .frame(width: 80, alignment: .trailing)

                                GeometryReader { geometry in
                                    let fraction = total > 0 ? Double(item.characterCount) / Double(total) : 0
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(speakerColor(for: item.speaker).gradient)
                                        .frame(width: geometry.size.width * fraction)
                                }
                                .frame(height: 20)

                                Text("\(total > 0 ? Int(Double(item.characterCount) / Double(total) * 100) : 0)%")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
        }
        .onAppear {
            viewModel.loadStats(from: modelContext)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }

    private func speakerColor(for speaker: String) -> Color {
        switch speaker {
        case "You": .blue
        case "Remote": .purple
        case "Speaker A": .blue
        case "Speaker B": .purple
        case "Speaker C": .green
        case "Speaker D": .orange
        default: .gray
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
