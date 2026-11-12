import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Configuration Intent

struct ConfigureEntregasIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configurar Entregas"
    static var description = IntentDescription("Configure o link .ics da sua agenda")

    @Parameter(title: "URL da Agenda (.ics)", default: "")
    var calendarURL: String
}

// MARK: - Local storage for completed events

struct WidgetStore {
    private static let completedKey = "widget_completed_events"
    private static let cachedKey = "widget_cached_events"

    private static var defaults: UserDefaults { .standard }

    static var completedEventIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: completedKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: completedKey) }
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

    static func saveCachedEvents(_ events: [CalendarEvent], for url: String) {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: cachedKey + url.hashValue.description)
        }
    }

    static func loadCachedEvents(for url: String) -> [CalendarEvent] {
        guard let data = defaults.data(forKey: cachedKey + url.hashValue.description),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func fetchEvents(from urlString: String) async -> [CalendarEvent] {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let icsString = String(data: data, encoding: .utf8) {
                let events = ICSParser.parse(icsString)
                saveCachedEvents(events, for: urlString)
                return events
            }
        } catch {}
        return loadCachedEvents(for: urlString)
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

// MARK: - Toggle Intent

struct ToggleEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Completar Tarefa"

    @Parameter(title: "Event ID")
    var eventID: String

    init() {}

    init(eventID: String) {
        self.eventID = eventID
    }

    func perform() async throws -> some IntentResult {
        WidgetStore.toggleCompletion(for: eventID)
        return .result()
    }
}

// MARK: - Timeline

struct EntregasEntry: TimelineEntry {
    let date: Date
    let todayEvents: [CalendarEvent]
    let tomorrowEvents: [CalendarEvent]
    let completedIDs: Set<String>
    let hasURL: Bool
}

struct EntregasTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> EntregasEntry {
        EntregasEntry(
            date: Date(),
            todayEvents: [
                CalendarEvent(id: "1", title: "Prova de Cálculo", startDate: Date(), endDate: Date()),
                CalendarEvent(id: "2", title: "Entrega de Projeto", startDate: Date(), endDate: Date())
            ],
            tomorrowEvents: [
                CalendarEvent(id: "3", title: "Seminário de Física", startDate: Date(), endDate: Date())
            ],
            completedIDs: ["1"],
            hasURL: true
        )
    }

    func snapshot(for configuration: ConfigureEntregasIntent, in context: Context) async -> EntregasEntry {
        let url = configuration.calendarURL
        let events = WidgetStore.loadCachedEvents(for: url)
        return EntregasEntry(
            date: Date(),
            todayEvents: WidgetStore.eventsForToday(from: events),
            tomorrowEvents: WidgetStore.eventsForTomorrow(from: events),
            completedIDs: WidgetStore.completedEventIDs,
            hasURL: !url.isEmpty
        )
    }

    func timeline(for configuration: ConfigureEntregasIntent, in context: Context) async -> Timeline<EntregasEntry> {
        let url = configuration.calendarURL
        let events = await WidgetStore.fetchEvents(from: url)
        let entry = EntregasEntry(
            date: Date(),
            todayEvents: WidgetStore.eventsForToday(from: events),
            tomorrowEvents: WidgetStore.eventsForTomorrow(from: events),
            completedIDs: WidgetStore.completedEventIDs,
            hasURL: !url.isEmpty
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Widget Views

struct EventRow: View {
    let event: CalendarEvent
    let isCompleted: Bool

    var body: some View {
        Button(intent: ToggleEventIntent(eventID: event.id)) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(isCompleted ? Color.clear : Color.white.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if isCompleted {
                        Circle()
                            .fill(Color(red: 0.4, green: 0.6, blue: 0.9))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(event.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isCompleted ? .gray : .white)
                    .strikethrough(isCompleted, color: .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct WidgetColumnView: View {
    let title: String
    let events: [CalendarEvent]
    let completedIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)

            if events.isEmpty {
                Text("Nenhuma entrega")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.top, 4)
            } else {
                ForEach(events) { event in
                    EventRow(
                        event: event,
                        isCompleted: completedIDs.contains(event.id)
                    )
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct EntregasWidgetView: View {
    let entry: EntregasEntry

    var body: some View {
        if !entry.hasURL {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                Text("Toque e segure o widget\n> Editar Widget\ne cole o link .ics")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .containerBackground(for: .widget) {
                Color(red: 0.1, green: 0.1, blue: 0.1)
            }
        } else {
            HStack(spacing: 0) {
                WidgetColumnView(
                    title: "Hoje",
                    events: entry.todayEvents,
                    completedIDs: entry.completedIDs
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                WidgetColumnView(
                    title: "Amanhã",
                    events: entry.tomorrowEvents,
                    completedIDs: entry.completedIDs
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
            .padding(16)
            .containerBackground(for: .widget) {
                Color(red: 0.1, green: 0.1, blue: 0.1)
            }
        }
    }
}

// MARK: - Widget

struct EntregasWidget: Widget {
    let kind: String = "EntregasWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigureEntregasIntent.self, provider: EntregasTimelineProvider()) { entry in
            EntregasWidgetView(entry: entry)
        }
        .configurationDisplayName("Entregas")
        .description("Veja suas entregas de hoje e amanhã")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct EntregasWidgetBundle: WidgetBundle {
    var body: some Widget {
        EntregasWidget()
    }
}
