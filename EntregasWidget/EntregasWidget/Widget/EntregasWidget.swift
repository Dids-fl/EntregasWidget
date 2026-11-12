import WidgetKit
import SwiftUI
import AppIntents

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
        DataStore.toggleCompletion(for: eventID)
        return .result()
    }
}

// MARK: - Timeline

struct EntregasEntry: TimelineEntry {
    let date: Date
    let todayEvents: [CalendarEvent]
    let tomorrowEvents: [CalendarEvent]
    let completedIDs: Set<String>
}

struct EntregasTimelineProvider: TimelineProvider {
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
            completedIDs: ["1"]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (EntregasEntry) -> Void) {
        let events = DataStore.loadCachedEvents()
        let entry = EntregasEntry(
            date: Date(),
            todayEvents: DataStore.eventsForToday(from: events),
            tomorrowEvents: DataStore.eventsForTomorrow(from: events),
            completedIDs: DataStore.completedEventIDs
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntregasEntry>) -> Void) {
        Task {
            let events = await DataStore.fetchAndCacheEvents()
            let entry = EntregasEntry(
                date: Date(),
                todayEvents: DataStore.eventsForToday(from: events),
                tomorrowEvents: DataStore.eventsForTomorrow(from: events),
                completedIDs: DataStore.completedEventIDs
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
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

// MARK: - Widget

struct EntregasWidget: Widget {
    let kind: String = "EntregasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EntregasTimelineProvider()) { entry in
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
