import EventKit
import Foundation
import os

/// Reads upcoming meetings from the user's local macOS Calendar.
/// This includes any calendars synced to macOS — Google, Outlook, iCloud, etc.
@MainActor
@Observable
final class CalendarService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Calendar")
    private let eventStore = EKEventStore()

    var isAuthorized = false
    var upcomingMeetings: [CalendarMeeting] = []
    var nextMeeting: CalendarMeeting? { upcomingMeetings.first }

    private var refreshTimer: Timer?

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                refreshUpcomingMeetings()
                startRefreshTimer()
            }
            logger.info("Calendar access: \(granted)")
            return granted
        } catch {
            logger.error("Calendar access error: \(error.localizedDescription)")
            isAuthorized = false
            return false
        }
    }

    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = status == .fullAccess
    }

    // MARK: - Fetch Meetings

    func refreshUpcomingMeetings() {
        guard isAuthorized else { return }

        let now = Date()
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endOfDay,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .filter { isMeetingEvent($0) }
            .sorted { $0.startDate < $1.startDate }

        upcomingMeetings = events.map { CalendarMeeting(event: $0) }
        logger.info("Found \(self.upcomingMeetings.count) upcoming meetings")
    }

    /// Check if a calendar event looks like a meeting (has a video link or attendees).
    private func isMeetingEvent(_ event: EKEvent) -> Bool {
        // Has attendees beyond the organizer
        if let attendees = event.attendees, attendees.count > 0 {
            return true
        }
        // Has a video conferencing URL in notes or URL
        let meetingPatterns = ["zoom.us", "teams.microsoft.com", "meet.google.com", "webex.com", "gotomeeting.com"]
        if let url = event.url?.absoluteString.lowercased() {
            if meetingPatterns.contains(where: { url.contains($0) }) {
                return true
            }
        }
        if let notes = event.notes?.lowercased() {
            if meetingPatterns.contains(where: { notes.contains($0) }) {
                return true
            }
        }
        return false
    }

    // MARK: - Auto-refresh

    func startRefreshTimer() {
        stopRefreshTimer()
        // Refresh every 60 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshUpcomingMeetings()
            }
        }
    }

    func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Meeting Starting Soon

    /// Returns a meeting if one starts within the given number of minutes.
    func meetingStartingSoon(withinMinutes minutes: Int = 2) -> CalendarMeeting? {
        let now = Date()
        return upcomingMeetings.first { meeting in
            let timeUntilStart = meeting.startDate.timeIntervalSince(now)
            return timeUntilStart >= 0 && timeUntilStart <= Double(minutes * 60)
        }
    }

    /// Returns a meeting that is currently in progress.
    func meetingInProgress() -> CalendarMeeting? {
        let now = Date()
        return upcomingMeetings.first { meeting in
            now >= meeting.startDate && now <= meeting.endDate
        }
    }
}

/// Simplified representation of a calendar event for Clio's UI.
struct CalendarMeeting: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendees: [String]
    let meetingURL: URL?
    let calendarName: String
    let calendarColor: String?

    init(event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled Meeting"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.attendees = event.attendees?.compactMap { $0.name ?? $0.url.absoluteString } ?? []
        self.calendarName = event.calendar?.title ?? "Calendar"
        self.calendarColor = nil

        // Try to extract a meeting URL
        let allText = [event.url?.absoluteString, event.notes].compactMap { $0 }.joined(separator: " ")
        let patterns = ["https://[^ ]*zoom.us/[^ ]*", "https://teams.microsoft.com/[^ ]*", "https://meet.google.com/[^ ]*"]
        self.meetingURL = patterns.lazy.compactMap { pattern -> URL? in
            guard let range = allText.range(of: pattern, options: .regularExpression) else { return nil }
            return URL(string: String(allText[range]))
        }.first ?? event.url
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var isStartingSoon: Bool {
        let minutesUntil = startDate.timeIntervalSinceNow / 60
        return minutesUntil >= 0 && minutesUntil <= 5
    }

    var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
}
