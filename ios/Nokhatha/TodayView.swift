// Today: the dial for where we are in the Gulf year, then what needs doing.
import NokhathaKit
import SwiftUI

struct Header: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 9) {
            Image("Mark").resizable().frame(width: 30, height: 30)
            Text(model.t("app.name")).font(Theme.title(21)).foregroundStyle(Theme.ink)
            Spacer()
        }
    }
}

struct SectionTitle: View {
    let text: String
    var count: Int? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(Theme.title(20)).foregroundStyle(Theme.ink)
            Spacer()
            if let count, count > 0 {
                Text(verbatim: String(count)).font(Theme.body(13, "Bold")).foregroundStyle(Theme.overdue)
                    .padding(.horizontal, 9).frame(height: 26).background(Theme.overdue.opacity(0.11), in: Capsule())
            }
        }
        .padding(.top, 18)
    }
}

struct TodayView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let b = model.brain
        let w = model.words
        let tasks = b.tasks()
        let now = tasks.filter { ["overdue", "today", "soon"].contains($0.status) }
        let later = Array(tasks.filter { $0.status == "ok" && ($0.days ?? 999) <= 30 }.prefix(6))
        let subs = b.subs()
        let season = seasonAt(model.today, model.catalog.seasons)
        let dots = tasks.compactMap { e in e.days.map { DialDot(days: $0, status: e.status) } }
            + subs.filter { $0.status != "off" }.map { DialDot(days: $0.days, status: "sub") }
        let hour = Calendar.current.component(.hour, from: Date())
        let totals = b.totals()
        let cur = totals[model.state?.settings.currency ?? "KWD"] != nil ? (model.state?.settings.currency ?? "KWD") : totals.keys.sorted().first

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Header()
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.greeting(hour: hour)).font(Theme.title(24)).foregroundStyle(Theme.ink)
                    Text(w.longDate(model.today)).font(Theme.body(14)).foregroundStyle(Theme.ink3)
                }
                DialView(today: model.today, catalog: model.catalog, dots: dots, center: w.seasonCenter(season, catalog: model.catalog, today: model.today))
                    .frame(maxWidth: 380)
                    .frame(maxWidth: .infinity)
                if let hint = model.catalog.season(season.id).flatMap({ model.isArabic ? $0.hint_ar : $0.hint_en }) {
                    Card(padding: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle").foregroundStyle(Theme.sadu).padding(.top, 3)
                            Text(hint).font(Theme.body(14.5)).foregroundStyle(Theme.ink2).lineSpacing(4)
                        }
                    }
                }
                SectionTitle(text: model.t("today.now"), count: now.count)
                if now.isEmpty {
                    Card { Label(model.t("today.clear"), systemImage: "checkmark.circle").font(Theme.body(15)).foregroundStyle(Theme.ink2) }
                } else {
                    TaskList(rows: now, showAsset: true)
                }
                if let ask = subs.first(where: { $0.ask || $0.planned }) { AskCard(s: ask).padding(.top, 8) }
                if let cur, let t = totals[cur] {
                    Button { model.tab = "subs" } label: {
                        Card(padding: 14) {
                            HStack {
                                Image(systemName: Symbol.name("repeat")).foregroundStyle(Theme.ok)
                                Text(model.t("today.subs", ["amount": w.money(t.month, cur)])).font(Theme.body(15, "SemiBold")).foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: model.isArabic ? "chevron.left" : "chevron.right").foregroundStyle(Theme.ink3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                if !later.isEmpty {
                    SectionTitle(text: model.t("today.later"))
                    TaskList(rows: later, showAsset: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Theme.bg)
    }
}
