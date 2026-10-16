// The home screen widget: the season, the days to the next one, and the three nearest dates,
// read from the app's state in the shared App Group. Nothing leaves the device.
import NokhathaKit
import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let lang: String
    let season: String
    let left: String
    let rows: [(title: String, due: String, status: String)]
    let empty: String?
}

struct Provider: TimelineProvider {
    static let group = "group.com.eworldq8.nokhatha"

    func placeholder(in context: Context) -> Entry { load() }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // refreshed after midnight, and whenever the app saves (it reloads the timelines)
        let next = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!.addingTimeInterval(5 * 60)
        completion(Timeline(entries: [load()], policy: .after(next)))
    }

    func load() -> Entry {
        let today = Day.today()
        guard let data = Bundle.main.url(forResource: "data", withExtension: nil), let catalog = try? Catalog.load(from: data) else {
            return Entry(date: Date(), lang: "ar", season: "نُوخذة", left: "", rows: [], empty: nil)
        }
        let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Provider.group)?.appendingPathComponent("nokhatha.json")
        let state = shared.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(AppState.self, from: $0) }
        let lang = state?.settings.lang ?? ((Locale.preferredLanguages.first ?? "ar").hasPrefix("ar") ? "ar" : "en")
        let w = Words(strings: catalog.strings, lang: lang)
        let season = seasonAt(today, catalog.seasons)
        let left = w.t("dial.left", ["n": w.dayCount(season.daysLeft), "next": catalog.season(season.nextId)?.name(lang) ?? ""])
        var rows: [(String, String, String)] = []
        if let state {
            let b = Brain(catalog: catalog, state: state, today: today)
            rows = b.tasks().filter { $0.due != nil }.prefix(3).map { ($0.title(lang), w.due($0, today: today).rel, $0.status) }
        }
        let empty = rows.isEmpty ? w.t(state == nil ? "welcome.start" : "today.clear") : nil
        return Entry(date: Date(), lang: lang, season: catalog.season(season.id)?.name(lang) ?? "", left: left, rows: rows, empty: empty)
    }
}

struct WidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.season).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Color("Ink"))
                Spacer()
                Circle().fill(Color("Sadu")).frame(width: 8, height: 8)
            }
            Text(entry.left).font(.system(size: 12)).foregroundStyle(Color("Ink2")).lineLimit(1)
            if family != .systemSmall {
                Divider().padding(.vertical, 2)
                if let empty = entry.empty {
                    Text(empty).font(.system(size: 13)).foregroundStyle(Color("Ink2"))
                } else {
                    ForEach(Array(entry.rows.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: 8) {
                            Text(r.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color("Ink")).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(r.due).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(r.status)).lineLimit(1)
                        }
                    }
                }
            } else if let first = entry.rows.first {
                Divider().padding(.vertical, 2)
                Text(first.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color("Ink")).lineLimit(2)
                Text(first.due).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(first.status))
            }
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, entry.lang == "ar" ? .rightToLeft : .leftToRight)
        .containerBackground(Color("Surface"), for: .widget)
    }

    func tint(_ status: String) -> Color {
        switch status { case "overdue": return Color("Sadu"); case "today", "soon": return Color("Rutab"); default: return Color("Sea") }
    }
}

@main
struct NokhathaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NokhathaWidget", provider: Provider()) { WidgetView(entry: $0) }
            .configurationDisplayName("نُوخذة")
            .description("الموسم وأقرب المواعيد")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
