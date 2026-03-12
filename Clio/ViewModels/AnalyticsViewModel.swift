import Foundation
import SwiftData
import os

@MainActor
@Observable
final class AnalyticsViewModel {
    var totalMeetings = 0
    var totalHours: Double = 0
    var averageDuration: Double = 0
    var meetingsThisWeek = 0
    var weeklyDurations: [(date: Date, duration: Double)] = []
    var speakerBreakdown: [(speaker: String, characterCount: Int)] = []

    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Analytics")

    func loadStats(from context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Meeting>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let meetings = try context.fetch(descriptor)

            totalMeetings = meetings.count
            totalHours = meetings.reduce(0) { $0 + $1.durationSeconds } / 3600.0
            averageDuration = meetings.isEmpty ? 0 : meetings.reduce(0) { $0 + $1.durationSeconds } / Double(meetings.count)

            // Meetings this week
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            meetingsThisWeek = meetings.filter { $0.createdAt >= startOfWeek }.count

            // Weekly durations (last 14 days)
            let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            weeklyDurations = meetings
                .filter { $0.createdAt >= twoWeeksAgo && $0.status == .completed }
                .map { (date: $0.createdAt, duration: $0.durationSeconds / 60.0) }

            // Speaker breakdown across all meetings
            var speakerCounts: [String: Int] = [:]
            for meeting in meetings {
                for segment in meeting.segments {
                    let speaker = segment.speakerLabel ?? "Unknown"
                    speakerCounts[speaker, default: 0] += segment.text.count
                }
            }
            speakerBreakdown = speakerCounts
                .sorted { $0.value > $1.value }
                .map { (speaker: $0.key, characterCount: $0.value) }

        } catch {
            logger.error("Failed to load analytics: \(error.localizedDescription)")
        }
    }
}
