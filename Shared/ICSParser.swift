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
        var unfoldedLines: [String] = []
        let rawLines = icsString.components(separatedBy: "\n")

        for line in rawLines {
            let cleaned = line.replacingOccurrences(of: "\r", with: "")
            if cleaned.hasPrefix(" ") || cleaned.hasPrefix("\t") {
                if !unfoldedLines.isEmpty {
                    unfoldedLines[unfoldedLines.count - 1] += String(cleaned.dropFirst())
                }
            } else {
                unfoldedLines.append(cleaned)
            }
        }

        var inEvent = false
        var summary = ""
        var uid = ""
        var dtStart: Date?
        var dtEnd: Date?

        for line in unfoldedLines {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                summary = ""
                uid = ""
                dtStart = nil
                dtEnd = nil
            } else if line == "END:VEVENT" {
                if inEvent, !summary.isEmpty, let start = dtStart {
                    let unescaped = summary
                        .replacingOccurrences(of: "\\,", with: ",")
                        .replacingOccurrences(of: "\\;", with: ";")
                        .replacingOccurrences(of: "\\n", with: " ")
                        .replacingOccurrences(of: "\\N", with: " ")
                    let event = CalendarEvent(
                        id: uid.isEmpty ? UUID().uuidString : uid,
                        title: unescaped,
                        startDate: start,
                        endDate: dtEnd ?? start
                    )
                    events.append(event)
                }
                inEvent = false
            } else if inEvent {
                if line.hasPrefix("SUMMARY:") {
                    summary = String(line.dropFirst("SUMMARY:".count))
                } else if line.hasPrefix("UID:") {
                    uid = String(line.dropFirst("UID:".count))
                } else if line.hasPrefix("DTSTART") {
                    dtStart = parseICSDate(line)
                } else if line.hasPrefix("DTEND") {
                    dtEnd = parseICSDate(line)
                }
            }
        }

        return events
    }

    private static func parseICSDate(_ line: String) -> Date? {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let dateString = String(parts[1])
        let prefix = String(parts[0])

        var tzid: String? = nil
        if let range = prefix.range(of: "TZID=") {
            tzid = String(prefix[range.upperBound...])
                .components(separatedBy: ";").first
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if dateString.hasSuffix("Z") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else if dateString.contains("T") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            if let tzid = tzid, let tz = TimeZone(identifier: tzid) {
                formatter.timeZone = tz
            } else {
                formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
            }
        } else {
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        }

        return formatter.date(from: dateString)
    }
}
