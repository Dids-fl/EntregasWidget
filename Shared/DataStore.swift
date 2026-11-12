import Foundation

class DataStore {
    static let appGroupID = "group.com.entregas.widget"
    private static let calendarURLKey = "calendarURL"
    private static let completedEventsKey = "completedEvents"
    private static let cachedEventsKey = "cachedEvents"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var calendarURL: String? {
        get { sharedDefaults?.string(forKey: calendarURLKey) }
        set { sharedDefaults?.set(newValue, forKey: calendarURLKey) }
    }

    static var completedEventIDs: Set<String> {
        get {
            let array = sharedDefaults?.stringArray(forKey: completedEventsKey) ?? []
            return Set(array)
        }
        set {
            sharedDefaults?.set(Array(newValue), forKey: completedEventsKey)
        }
    }

    static func toggleCompletion(for eventID: String) {
        var completed = completedEventIDs
        if completed.contains(eventID) {
            completed.remove(eventID)
        } else {
            completed.insert(eventID)
        }
        completedEventIDs = completed
    }

    static func saveCachedEvents(_ events: [CalendarEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            sharedDefaults?.set(data, forKey: cachedEventsKey)
        }
    }

    static func loadCachedEvents() -> [CalendarEvent] {
        guard let data = sharedDefaults?.data(forKey: cachedEventsKey),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func fetchAndCacheEvents() async -> [CalendarEvent] {
        guard let urlString = calendarURL, let url = URL(string: urlString) else {
            return loadCachedEvents()
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let icsString = String(data: data, encoding: .utf8) {
                let events = ICSParser.parse(icsString)
                saveCachedEvents(events)
                return events
            }
        } catch {
            print("Failed to fetch ICS: \(error)")
        }

        return loadCachedEvents()
    }

    static func eventsForToday(from events: [CalendarEvent]) -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return events.filter { $0.startDate >= today && $0.startDate < tomorrow }
            .sorted { $0.startDate < $1.startDate }
    }

    static func eventsForTomorrow(from events: [CalendarEvent]) -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!
        return events.filter { $0.startDate >= tomorrow && $0.startDate < dayAfter }
            .sorted { $0.startDate < $1.startDate }
    }
}
