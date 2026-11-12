import Foundation

struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    var isCompleted: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

class ICSParser {
    static func parse(_ icsString: String) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        let lines = icsString.components(separatedBy: .newlines)
        var inEvent = false
        var summary = ""
        var uid = ""
        var dtStart: Date?
        var dtEnd: Date?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                summary = ""
                uid = ""
                dtStart = nil
                dtEnd = nil
            } else if trimmed == "END:VEVENT" {
                if inEvent, !summary.isEmpty, let start = dtStart {
                    let event = CalendarEvent(
                        id: uid.isEmpty ? UUID().uuidString : uid,
                        title: summary,
                        startDate: start,
                        endDate: dtEnd ?? start
                    )
                    events.append(event)
                }
                inEvent = false
            } else if inEvent {
                if trimmed.hasPrefix("SUMMARY:") {
                    summary = String(trimmed.dropFirst("SUMMARY:".count))
                } else if trimmed.hasPrefix("UID:") {
                    uid = String(trimmed.dropFirst("UID:".count))
                } else if trimmed.hasPrefix("DTSTART") {
                    dtStart = parseICSDate(trimmed)
                } else if trimmed.hasPrefix("DTEND") {
                    dtEnd = parseICSDate(trimmed)
                }
            }
        }

        return events
    }

    private static func parseICSDate(_ line: String) -> Date? {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let dateString = String(parts[1])

        let formatters: [DateFormatter] = {
            let f1 = DateFormatter()
            f1.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            f1.timeZone = TimeZone(identifier: "UTC")

            let f2 = DateFormatter()
            f2.dateFormat = "yyyyMMdd'T'HHmmss"
            f2.timeZone = TimeZone.current

            let f3 = DateFormatter()
            f3.dateFormat = "yyyyMMdd"
            f3.timeZone = TimeZone.current

            return [f1, f2, f3]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}
