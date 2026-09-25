// A task row with its woven progress bar and a done button, and the task sheet.
import NokhathaKit
import SwiftUI

struct TaskRow: View {
    @EnvironmentObject var model: AppModel
    let e: Evaluated
    var showAsset = false
    @State private var open = false

    var body: some View {
        let w = model.words
        let line = w.due(e, today: model.today)
        HStack(spacing: 12) {
            Button { open = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: Symbol.name(e.icon))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.tint(e.status))
                        .frame(width: 42, height: 42)
                        .background(Theme.tint(e.status).opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(e.title(model.lang)).font(Theme.body(15.5, "SemiBold")).foregroundStyle(Theme.ink).lineLimit(2)
                        HStack(spacing: 8) {
                            Text(line.rel).font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.tint(e.status))
                            if let d = line.detail { Text(d).font(Theme.body(13.5)).foregroundStyle(Theme.ink3) }
                            if showAsset {
                                Text(e.asset.name).font(Theme.body(12, "SemiBold")).foregroundStyle(Theme.ink2)
                                    .padding(.horizontal, 8).background(Theme.ink.opacity(0.07), in: Capsule())
                            }
                        }
                        if let p = model.brain.progress(e) {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.ink.opacity(0.08))
                                    Capsule().fill(Theme.tint(e.status)).frame(width: g.size.width * p)
                                }
                            }
                            .frame(maxWidth: 240, maxHeight: 5)
                            .frame(height: 5)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if e.every.fixed == true {
                Button(e.due == nil ? model.t("act.setdate") : model.t("act.renewed")) {
                    if e.due == nil { open = true } else { model.renew(e) }
                }
                .font(Theme.body(13.5, "Bold"))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14).frame(height: 44)
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1.5))
            } else {
                Button { model.done(e) } label: {
                    Image(systemName: "checkmark").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink3).frame(width: 46, height: 46)
                        .overlay(Circle().stroke(e.status == "overdue" ? Theme.overdue.opacity(0.5) : Theme.line, lineWidth: 1.6))
                }
                .accessibilityLabel(model.t("act.done_label", ["title": e.title(model.lang)]))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .sheet(isPresented: $open) { TaskSheet(e: e).environmentObject(model).presentationDetents([.medium, .large]) }
    }
}

struct TaskList: View {
    let rows: [Evaluated]
    var showAsset = false
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, e in
                if i > 0 { Divider().overlay(Theme.line) }
                TaskRow(e: e, showAsset: showAsset)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct TaskSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let e: Evaluated
    @State private var date = Date()

    var body: some View {
        let w = model.words
        let line = w.due(e, today: model.today)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(e.title(model.lang)).font(Theme.title(22)).foregroundStyle(Theme.ink).padding(.top, 20)
                Text([line.rel, line.detail].compactMap { $0 }.joined(separator: "  ")).font(Theme.body(14, "SemiBold")).foregroundStyle(Theme.tint(e.status))
                if let why = e.tpl?.why(model.lang) {
                    Text(why).font(Theme.body(15)).foregroundStyle(Theme.ink2).lineSpacing(5)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                fact(model.t("item.every"), w.every(e.every, catalog: model.catalog))
                fact(model.t("item.last"), e.item.lastDone.flatMap(Day.init(iso:)).map { w.date($0, today: model.today) } ?? model.t("item.never"))
                if let d = e.due { fact(model.t("item.next"), w.date(d, today: model.today)) }
                if e.every.fixed == true {
                    DatePicker(model.t("item.expiry"), selection: $date, displayedComponents: .date).font(Theme.body(15))
                    wide(model.t("act.save"), primary: true) { model.setDue(e, date); dismiss() }
                } else {
                    wide(model.t("act.done"), primary: true) { model.done(e); dismiss() }
                    wide(model.t("act.snooze"), primary: false) { model.snooze(e); dismiss() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.surface)
        .environment(\.layoutDirection, model.isArabic ? .rightToLeft : .leftToRight)
    }

    func fact(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(Theme.body(12.5, "SemiBold")).foregroundStyle(Theme.ink3)
            Text(v).font(Theme.body(15, "SemiBold")).foregroundStyle(Theme.ink)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    func wide(_ title: String, primary: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.body(16, "SemiBold")).frame(maxWidth: .infinity).frame(height: 50)
                .foregroundStyle(primary ? Theme.onInk : Theme.ink)
                .background(primary ? Theme.ink : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: primary ? 0 : 1))
        }
    }
}
