// Subscriptions: what they cost a month and a year, and when each renews.
import NokhathaKit
import SwiftUI

struct SubsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let b = model.brain
        let w = model.words
        let totals = b.totals()
        let main = totals[model.state?.settings.currency ?? "KWD"] != nil ? (model.state?.settings.currency ?? "KWD") : totals.keys.sorted().first
        let subs = b.subs().sorted { ($0.status == "off" ? 1 : 0, $0.next) < ($1.status == "off" ? 1 : 0, $1.next) }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Header()
                Text(model.t("tab.subs")).font(Theme.title(30)).foregroundStyle(Theme.ink)
                if let main, let t = totals[main] {
                    Card {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.t("subs.month")).font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.ink3)
                            Text(w.money(t.month, main)).font(Theme.title(40)).foregroundStyle(Theme.ink)
                            Text(model.t("subs.year", ["amount": w.money(t.year, main)])).font(Theme.body(14)).foregroundStyle(Theme.ink2)
                        }
                    }
                }
                SectionTitle(text: model.t("subs.all"))
                VStack(spacing: 0) {
                    ForEach(Array(subs.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Divider().overlay(Theme.line) }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.sub.name).font(Theme.body(15.5, "SemiBold")).foregroundStyle(s.status == "off" ? Theme.ink3 : Theme.ink)
                                Text(s.status == "off" ? model.t("sub.cancelled")
                                     : s.trial ? model.t("sub.trial", ["rel": w.rel(s.days)])
                                     : s.days == 0 ? model.t("sub.renews_today") : model.t("sub.renews", ["rel": w.rel(s.days)]))
                                    .font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.tint(s.status))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(w.money(s.sub.amount, s.sub.currency)).font(Theme.body(15, "Bold")).foregroundStyle(Theme.ink)
                                Text(w.cycle(s.sub.cycle)).font(Theme.body(12)).foregroundStyle(Theme.ink3)
                            }
                        }
                        .padding(14)
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Theme.bg)
    }
}
