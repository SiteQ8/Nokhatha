// Adding and editing, laid out as the web's sheets: sh-head, facts, fields, actions.
import NokhathaKit
import SwiftUI

// MARK: - task

struct TaskSheet: View {
    @EnvironmentObject var model: AppModel
    let e: Evaluated
    let onClose: () -> Void
    @State private var pick = Day.today()
    @State private var whenDay = Day.today()
    @State private var km = ""
    @State private var cost = ""
    @State private var addTech = false
    @State private var interval = false

    private func facts(hasKm: Bool) -> [(String, String)] {
        let w = model.words
        var out: [(String, String)] = [(model.t("item.every"), w.every(e.every, catalog: model.catalog))]
        out.append((model.t("item.last"), e.item.lastDone.flatMap { Day(iso: $0) }.map { w.date($0, today: model.today) } ?? model.t("item.never")))
        if let due = e.due { out.append((model.t("item.next"), w.date(due, today: model.today))) }
        if hasKm, let k = e.item.lastKm { out.append((model.t("item.at_km"), w.km(k))) }
        return out
    }

    var body: some View {
        let w = model.words
        let line = w.due(e, today: model.today)
        let cur = model.state?.settings.currency ?? "KWD"
        let car = e.asset.car
        let hasKm = car != nil && (e.every.km ?? 0) != 0
        let logs = Array((e.item.log ?? []).suffix(6).reversed())
        SheetFrame(title: nil, onClose: onClose) {
            HStack(alignment: .top, spacing: 12) {
                RowIcon(icon: e.icon, tint: Theme.tint(e.status), bg: Theme.tintBg(e.status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.title(model.lang)).font(Theme.title(22)).foregroundStyle(Theme.ink)
                    HStack(spacing: 10) {
                        Text(line.rel).font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.tint(e.status))
                        if let d = line.detail { Text(d).font(Theme.body(13.5)).foregroundStyle(Theme.ink3) }
                    }
                }
            }
            .padding(.top, 8).padding(.trailing, 48)
            if let why = e.tpl?.why(model.lang) {
                Text(why).font(Theme.body(15)).foregroundStyle(Theme.ink).lineSpacing(6)
                    .padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).padding(.top, 14)
            }
            Facts(items: facts(hasKm: hasKm))
            if e.every.fixed == true {
                DayField(label: model.t("item.expiry"), day: $pick)
                WideButton(title: model.t("act.save")) { model.update("toast.saved") { $0.setDue(e.item.id, pick) }; onClose() }.padding(.top, 14)
                if let due = e.due {
                    WideButton(title: model.t("act.renewed_long", ["date": w.date(due.addingMonths(e.every.repeatMonths ?? 12), today: model.today)]), primary: false, icon: "done") { model.renew(e); onClose() }.padding(.top, 10)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    DayField(label: model.t("item.when"), day: $whenDay)
                    if hasKm { VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("item.km")); Input(text: $km, placeholder: "84000", numbers: true) } }
                }
                .padding(.top, 6)
                FieldLabel(text: model.t("item.cost"))
                Input(text: $cost, placeholder: w.money(0, cur), numbers: true)
                WideButton(title: model.t("act.done"), icon: "done") {
                    let k = km.isEmpty ? nil : wholeNumber(km)
                    let c = cost.isEmpty ? nil : parseMoney(cost, cur)
                    if !cost.isEmpty && c == nil { model.say("err.amount"); return }
                    model.update("toast.done", ["title": e.title(model.lang)]) { $0.markDone(e.item.id, on: whenDay > model.today ? model.today : whenDay, km: k, cost: c) }
                    onClose()
                }
                .padding(.top, 16)
                if (e.every.season ?? "").isEmpty {
                    ButtonPair(a: model.t("act.snooze"), onA: { model.snooze(e); onClose() }, b: model.t("act.interval"), onB: { interval = true }, aIcon: "snooze", bIcon: "edit").padding(.top, 12)
                } else {
                    WideButton(title: model.t("act.snooze"), primary: false, icon: "snooze") { model.snooze(e); onClose() }.padding(.top, 12)
                }
            }
            if let trade = e.tpl?.trade {
                let tradeName = model.catalog.trades.first { $0.id == trade }?.name(model.lang) ?? trade
                if let tech = model.brain.techFor(trade) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.t("tech.for", ["trade": tradeName, "name": tech.name])).font(Theme.body(16, "SemiBold")).foregroundStyle(Theme.ink)
                        TechButtons(x: tech)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).padding(.top, 18)
                } else {
                    HStack(spacing: 6) {
                        Text(model.t("tech.none", ["trade": tradeName])).font(Theme.body(13)).foregroundStyle(Theme.ink3)
                        Button(model.t("tech.add_link")) { addTech = true }.font(Theme.body(13, "SemiBold")).foregroundStyle(Theme.ink)
                    }
                    .padding(.top, 18)
                }
            }
            if !logs.isEmpty {
                SmallHead(text: model.t("item.history"))
                VStack(spacing: 0) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { i, l in
                        if i > 0 { RowLine() }
                        HStack(spacing: 14) {
                            Text(Day(iso: l.date).map { w.date($0, today: model.today) } ?? l.date).font(Theme.body(14, "SemiBold")).foregroundStyle(Theme.ink).frame(minWidth: 110, alignment: .leading)
                            if let k = l.km { Text(w.km(k)).font(Theme.body(14)).foregroundStyle(Theme.ink) }
                            if let c = l.cost { Text(w.money(c, l.cur ?? cur)).font(Theme.body(14)).foregroundStyle(Theme.ink) }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
            WideButton(title: e.item.tpl == nil ? model.t("act.delete") : model.t("act.stop"), danger: true, icon: "trash") {
                model.update(e.item.tpl == nil ? "toast.deleted" : "toast.stopped") { $0.stop(e.item.id) }
                onClose()
            }
            .padding(.top, 12)
        }
        .onAppear {
            pick = e.due ?? model.today.adding(30)
            whenDay = model.today
            if hasKm, let c = car, let k = kmOn(c, model.today) { km = String(k) }
        }
        .sheet(isPresented: $addTech) { TechSheet(existing: nil, trade0: e.tpl?.trade ?? "ac") { addTech = false } }
        .sheet(isPresented: $interval) { IntervalSheet(e: e) { interval = false; onClose() } }
    }
}

/// Every n days or months, the kilometre rule for car tasks, and a way back to the suggested interval.
struct IntervalSheet: View {
    @EnvironmentObject var model: AppModel
    let e: Evaluated
    let onClose: () -> Void
    @State private var n = "6"
    @State private var unit = "months"
    @State private var km = ""

    var body: some View {
        let base = e.every
        SheetFrame(title: model.t("act.interval"), onClose: onClose) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("int.every")); Input(text: $n, placeholder: "6", numbers: true) }
                VStack(alignment: .leading, spacing: 0) {
                    FieldLabel(text: model.t("int.unit"))
                    Seg(options: [("days", model.t("int.days")), ("months", model.t("int.months"))], selected: unit) { unit = $0 }
                }
            }
            if (base.km ?? 0) != 0 {
                FieldLabel(text: model.t("int.km"))
                Input(text: $km, placeholder: String(base.km ?? 0), numbers: true)
            }
            WideButton(title: model.t("act.save")) {
                guard let k = wholeNumber(n), k >= 1, k <= 3650 else { model.say("err.number"); return }
                model.update("toast.saved") { $0.setInterval(e.item.id, n: k, unit: unit, km: wholeNumber(km)) }
                onClose()
            }
            .padding(.top, 12)
            if e.item.every != nil && e.item.tpl != nil {
                WideButton(title: model.t("int.reset"), quiet: true) { model.update("toast.saved") { $0.setInterval(e.item.id, n: nil, unit: unit, km: nil) }; onClose() }.padding(.top, 4)
            }
        }
        .onAppear {
            n = String(base.days ?? base.months ?? 6)
            unit = (base.days ?? 0) != 0 ? "days" : "months"
            km = base.km.map(String.init) ?? ""
        }
    }
}

// MARK: - add task

struct AddTaskSheet: View {
    @EnvironmentObject var model: AppModel
    let assetId: String
    let onClose: () -> Void
    @State private var title = ""
    @State private var n = "3"
    @State private var unit = "months"

    var body: some View {
        let list = model.brain.addable(to: assetId)
        SheetFrame(title: model.t("act.add_task"), onClose: onClose) {
            if !list.isEmpty {
                FieldLabel(text: model.t("add.from_list"))
                ChoiceGrid(items: list, columns: 2, isOn: { _ in false }, label: { $0.name(model.lang) }, icon: { $0.icon }) { t in
                    model.update("toast.added") { $0.addTemplate(t.id, to: assetId) }
                    onClose()
                }
            }
            FieldLabel(text: model.t("add.custom"))
            FieldLabel(text: model.t("add.title"))
            Input(text: $title, placeholder: model.t("add.title_ph"))
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("int.every")); Input(text: $n, placeholder: "3", numbers: true) }
                VStack(alignment: .leading, spacing: 0) {
                    FieldLabel(text: model.t("int.unit"))
                    Seg(options: [("days", model.t("int.days")), ("months", model.t("int.months"))], selected: unit) { unit = $0 }
                }
            }
            WideButton(title: model.t("act.save")) {
                let name = title.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { model.say("err.title"); return }
                guard let k = wholeNumber(n), k > 0 else { model.say("err.number"); return }
                model.update("toast.added") { $0.addCustom(title: name, every: unit == "months" ? Every(months: min(k, 120)) : Every(days: k), to: assetId) }
                onClose()
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - subscription

let subCats: [(String, String)] = [("stream", "play"), ("music", "music"), ("cloud", "cloud"), ("games", "game"), ("gym", "gym"), ("internet", "wifi"), ("phone", "phone"), ("apps", "apps"), ("other", "repeat")]

struct SubSheet: View {
    @EnvironmentObject var model: AppModel
    let existing: Sub?
    let onClose: () -> Void
    @State private var name = ""
    @State private var currency = "KWD"
    @State private var amount = ""
    @State private var cycle = "monthly"
    @State private var next = Day.today()
    @State private var trial = false
    @State private var category = "stream"
    @State private var note = ""
    @State private var confirm = false

    var body: some View {
        SheetFrame(title: existing?.name ?? model.t("act.add_sub"), onClose: onClose) {
            FieldLabel(text: model.t("sub.name"))
            Input(text: $name, placeholder: model.t("sub.name_ph"))
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("sub.amount")); Input(text: $amount, placeholder: "3.500", numbers: true) }
                VStack(alignment: .leading, spacing: 0) {
                    FieldLabel(text: model.t("settings.currency"))
                    Select(value: currency, options: currencies.keys.sorted().map { ($0, $0) }) { currency = $0 }
                }
            }
            FieldLabel(text: model.t("sub.cycle"))
            Seg(options: ["weekly", "monthly", "quarterly", "semiannual", "yearly"].map { ($0, model.t("cyclename." + $0)) }, selected: cycle) { cycle = $0 }
            DayField(label: model.t("sub.next"), day: $next)
            SwitchCard(rows: [(model.t("sub.trial_q"), $trial)]).padding(.top, 14)
            FieldLabel(text: model.t("sub.category"))
            ChoiceGrid(items: subCats.map(\.0), columns: 3, isOn: { category == $0 }, label: { model.t("cat." + $0) }, icon: { c in subCats.first { $0.0 == c }?.1 }) { category = $0 }
            FieldLabel(text: model.t("sub.note"))
            Input(text: $note, placeholder: model.t("sub.note_ph"))
            WideButton(title: model.t("act.save")) {
                let title = name.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { model.say("err.title"); return }
                guard let minor = parseMoney(amount, currency) else { model.say("err.amount"); return }
                var s = existing ?? Sub(id: newID(), name: title, amount: minor, currency: currency, cycle: cycle, anchor: next.iso)
                s.name = title; s.amount = minor; s.currency = currency; s.cycle = cycle; s.anchor = next.iso
                s.trial = trial ? true : nil; s.category = category
                let n = note.trimmingCharacters(in: .whitespaces); s.note = n.isEmpty ? nil : n
                model.update("toast.saved") { $0.saveSub(s) }
                onClose()
            }
            .padding(.top, 12)
            if let s = existing {
                if s.cancelled == true {
                    WideButton(title: model.t("sub.restore"), primary: false) { model.update("toast.saved") { $0.restoreSub(s.id) }; onClose() }.padding(.top, 10)
                } else {
                    WideButton(title: model.t("ask.cancelled"), primary: false) { model.update("toast.cancelled", ["name": s.name]) { $0.cancelSub(s.id) }; onClose() }.padding(.top, 10)
                }
                WideButton(title: model.t("act.delete"), danger: true, icon: "trash") { confirm = true }.padding(.top, 4)
            }
        }
        .onAppear {
            if let s = existing {
                name = s.name; currency = s.currency; amount = String(formatMoney(s.amount, s.currency, "en").split(separator: " ").last ?? "")
                cycle = s.cycle; trial = s.trial == true; category = s.category ?? "stream"; note = s.note ?? ""
                next = model.brain.subs().first { $0.sub.id == s.id }?.next ?? model.today.adding(30)
            } else {
                currency = model.state?.settings.currency ?? "KWD"; next = model.today.adding(30)
            }
        }
        .alert(model.t("confirm.sub"), isPresented: $confirm) {
            Button(model.t("act.delete"), role: .destructive) { if let s = existing { model.update("toast.deleted") { $0.deleteSub(s.id) }; onClose() } }
            Button(model.t("act.cancel"), role: .cancel) {}
        }
    }
}

// MARK: - home, car, belonging

struct AssetSheet: View {
    @EnvironmentObject var model: AppModel
    let kind: AssetKind
    let existingId: String?
    let onClose: () -> Void
    @State private var name = ""
    @State private var type = "house"
    @State private var features: [String: Bool] = ["central_ac": false, "tank": true, "filter": false]
    @State private var km = ""
    @State private var daily = "40"
    @State private var confirm = false

    var body: some View {
        let isNew = existingId == nil
        let placeholder: String = {
            switch kind {
            case .home: return model.t("type." + type)
            case .car: return model.t("car.default")
            case .thing: return model.catalog.thingTypes.first { $0.id == type }?.name(model.lang) ?? model.t("thing.name")
            }
        }()
        let title = model.t(kind == .home ? (isNew ? "act.add_home" : "act.edit_home") : kind == .car ? (isNew ? "act.add_car" : "act.edit_car") : (isNew ? "act.add_thing" : "act.edit_thing"))
        SheetFrame(title: title, onClose: onClose) {
            if kind == .home {
                FieldLabel(text: model.t("setup.type"))
                Seg(options: ["house", "flat", "chalet", "farm", "jakhoor"].map { ($0, model.t("type." + $0)) }, selected: type) { type = $0 }
            }
            if kind == .thing && isNew {
                FieldLabel(text: model.t("thing.type"))
                ChoiceGrid(items: model.catalog.thingTypes, columns: 3, isOn: { type == $0.id }, label: { $0.name(model.lang) }, icon: { $0.icon }) { type = $0.id }
            }
            FieldLabel(text: model.t(kind == .car ? "car.name" : kind == .thing ? "thing.name" : "setup.name"))
            Input(text: $name, placeholder: placeholder)
            if kind == .home {
                FieldLabel(text: model.t("setup.has"))
                SwitchCard(rows: ["central_ac", "tank", "filter"].map { f in (model.t("feat." + f), Binding(get: { features[f] ?? false }, set: { features[f] = $0 })) })
            }
            if kind == .car {
                HStack(alignment: .top, spacing: 12) {
                    if isNew { VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("car.km_now")); Input(text: $km, placeholder: "84000", numbers: true) } }
                    VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("car.daily")); Input(text: $daily, placeholder: "40", numbers: true) }
                }
                Fine(text: model.t("car.daily_note"))
            }
            if kind == .thing && isNew { Fine(text: model.t("thing.hint")) }
            WideButton(title: model.t("act.save")) {
                let n = name.trimmingCharacters(in: .whitespaces).isEmpty ? placeholder : name.trimmingCharacters(in: .whitespaces)
                if let id = existingId {
                    model.update("toast.saved") { b in
                        if let i = b.state.homes.firstIndex(where: { $0.id == id }) { b.state.homes[i].name = n; b.state.homes[i].type = type; b.state.homes[i].features = features }
                        if let i = b.state.cars.firstIndex(where: { $0.id == id }) { b.state.cars[i].name = n; b.state.cars[i].dailyKm = wholeNumber(daily) ?? 40 }
                        if let i = b.state.things.firstIndex(where: { $0.id == id }) { b.state.things[i].name = n }
                        if kind == .home {
                            for t in b.catalog.templates where t.kind == "home" && t.needs != nil {
                                let has = features[t.needs!] ?? false
                                if let i = b.state.items.firstIndex(where: { $0.asset == id && $0.tpl == t.id }) { b.state.items[i].enabled = has }
                                else if has && t.isDefault { b.addTemplate(t.id, to: id) }
                            }
                            b.spreadNew([id])
                        }
                    }
                } else {
                    model.update("toast.added") { b in
                        let id: String
                        switch kind {
                        case .home: id = b.addHome(type: type, name: n, features: features).id
                        case .car: id = b.addCar(name: n, km: wholeNumber(km), dailyKm: wholeNumber(daily) ?? 40).id
                        case .thing: id = b.addThing(type: type, name: n).id
                        }
                        b.spreadNew([id])
                    }
                }
                onClose()
            }
            .padding(.top, 12)
            if existingId != nil {
                WideButton(title: model.t(kind == .home ? "act.delete_home" : kind == .car ? "act.delete_car" : "act.delete_thing"), danger: true, icon: "trash") { confirm = true }.padding(.top, 4)
            }
        }
        .onAppear {
            let s = model.state ?? AppState()
            if let h = s.homes.first(where: { $0.id == existingId }) { name = h.name; type = h.type; features.merge(h.features ?? [:]) { $1 } }
            else if let c = s.cars.first(where: { $0.id == existingId }) { name = c.name; daily = String(c.dailyKm ?? 40) }
            else if let t = s.things.first(where: { $0.id == existingId }) { name = t.name; type = t.type }
            else if kind == .thing { type = "boat" }
        }
        .alert(model.t("confirm.asset"), isPresented: $confirm) {
            Button(model.t("act.delete"), role: .destructive) { if let id = existingId { model.update("toast.deleted") { $0.removeAsset(id) }; onClose() } }
            Button(model.t("act.cancel"), role: .cancel) {}
        }
    }
}

// MARK: - odometer

struct OdoSheet: View {
    @EnvironmentObject var model: AppModel
    let carId: String
    let onClose: () -> Void
    @State private var km = ""
    @State private var whenDay = Day.today()

    var body: some View {
        SheetFrame(title: model.t("act.update_odo"), onClose: onClose) {
            Lede(text: model.t("odo.body"), small: true).padding(.top, 6)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("item.km")); Input(text: $km, placeholder: "84000", numbers: true) }
                DayField(label: model.t("item.when"), day: $whenDay)
            }
            WideButton(title: model.t("act.save")) {
                guard let k = wholeNumber(km) else { model.say("err.number"); return }
                model.update("toast.saved") { $0.addReading(car: carId, km: k, on: whenDay > model.today ? model.today : whenDay) }
                onClose()
            }
            .padding(.top, 12)
        }
        .onAppear {
            whenDay = model.today
            if let c = model.state?.cars.first(where: { $0.id == carId }), let k = kmOn(c.odometer, model.today) { km = String(k) }
        }
    }
}

// MARK: - ask

/// The web's .ask card: the question in Kufi, the meta line, then a plain and a quiet button.
struct AskCard: View {
    @EnvironmentObject var model: AppModel
    let s: SubView
    var body: some View {
        let w = model.words
        let tone = s.planned ? Theme.overdue : Theme.rutab
        VStack(alignment: .leading, spacing: 0) {
            if s.planned {
                Text(model.t("ask.cancel_title", ["name": s.sub.name])).font(Theme.title(19)).foregroundStyle(Theme.ink)
                Text(model.t("ask.cancel_body")).font(Theme.body(14)).foregroundStyle(Theme.ink2).padding(.top, 4)
                if let n = s.sub.note {
                    Text(n).font(Theme.body(13.5)).foregroundStyle(Theme.ink2).padding(.horizontal, 12).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous)).padding(.top, 8)
                }
                HStack(spacing: 8) {
                    WideButton(title: model.t("ask.cancelled"), height: 44) { model.update("toast.cancelled", ["name": s.sub.name]) { $0.cancelSub(s.sub.id) } }
                    WideButton(title: model.t("ask.keep"), quiet: true, height: 44) { model.update("toast.kept", ["name": s.sub.name]) { $0.answer(sub: s.sub.id, keep: true) } }
                }
                .padding(.top, 12)
            } else {
                let whenText = s.trial && s.days == 0 ? model.t("sub.trial_today") : s.trial ? model.t("sub.trial", ["rel": w.rel(s.days)]) : s.days == 0 ? model.t("sub.renews_today") : model.t("sub.renews", ["rel": w.rel(s.days)])
                Text(model.t(s.trial ? "ask.q_trial" : "ask.q", ["name": s.sub.name])).font(Theme.title(19)).foregroundStyle(Theme.ink)
                Text(whenText + w.comma + w.money(s.sub.amount, s.sub.currency)).font(Theme.body(14)).foregroundStyle(Theme.ink2).padding(.top, 4)
                HStack(spacing: 8) {
                    WideButton(title: model.t("ask.yes"), primary: false, height: 44) { model.update("toast.kept", ["name": s.sub.name]) { $0.answer(sub: s.sub.id, keep: true) } }
                    WideButton(title: model.t("ask.no"), quiet: true, height: 44) { model.update { $0.answer(sub: s.sub.id, keep: false) } }
                }
                .padding(.top, 12)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.opacity(0.11), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(tone.opacity(0.32), lineWidth: 1))
    }
}
