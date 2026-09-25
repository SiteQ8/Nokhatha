// Adding and editing: tasks, subscriptions, homes, cars, belongings, the odometer.
import NokhathaKit
import SwiftUI

struct SheetFrame<Content: View>: View {
    @EnvironmentObject var model: AppModel
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.title(22)).foregroundStyle(Theme.ink).padding(.top, 22)
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
        .background(Theme.surface)
        .environment(\.layoutDirection, model.isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: model.isArabic ? "ar_KW@numbers=latn" : "en_GB"))
    }
}

struct AddTaskSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let assetId: String
    @State private var title = ""
    @State private var n = "3"
    @State private var months = true

    var body: some View {
        SheetFrame(title: model.t("act.add_task")) {
            let list = model.brain.addable(to: assetId)
            if !list.isEmpty {
                FieldLabel(text: model.t("add.from_list"))
                Flow {
                    ForEach(list) { t in
                        Chip(title: t.name(model.lang), icon: t.icon, on: false) {
                            model.update("toast.added") { $0.addTemplate(t.id, to: assetId) }
                            dismiss()
                        }
                    }
                }
            }
            FieldLabel(text: model.t("add.custom"))
            InputField(placeholder: model.t("add.title_ph"), text: $title)
            HStack(spacing: 10) {
                InputField(placeholder: "3", text: $n, numbers: true).frame(width: 90)
                Picker("", selection: $months) {
                    Text(model.t("int.months")).tag(true)
                    Text(model.t("int.days")).tag(false)
                }
                .pickerStyle(.segmented)
            }
            .padding(.top, 8)
            WideButton(title: model.t("act.save")) {
                let name = title.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, let k = wholeNumber(n), k > 0 else { model.toast = Toast(text: model.t("err.title"), undo: nil); return }
                model.update("toast.added") { $0.addCustom(title: name, every: months ? Every(months: min(k, 120)) : Every(days: k), to: assetId) }
                dismiss()
            }
            .padding(.top, 18)
        }
    }
}

struct SubSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let existing: Sub?
    @State private var name = ""
    @State private var amount = ""
    @State private var currency = "KWD"
    @State private var cycle = "monthly"
    @State private var next = Date().addingTimeInterval(30 * 86400)
    @State private var trial = false
    @State private var category = "stream"
    @State private var loaded = false

    static let cats = ["stream": "play", "music": "music", "cloud": "cloud", "games": "game", "gym": "gym", "internet": "wifi", "phone": "phone", "apps": "apps", "other": "repeat"]

    var body: some View {
        SheetFrame(title: existing?.name ?? model.t("act.add_sub")) {
            FieldLabel(text: model.t("sub.name"))
            InputField(placeholder: model.t("sub.name_ph"), text: $name)
            HStack(spacing: 10) {
                VStack(alignment: .leading) { FieldLabel(text: model.t("sub.amount")); InputField(placeholder: "3.500", text: $amount, numbers: true) }
                VStack(alignment: .leading) {
                    FieldLabel(text: model.t("settings.currency"))
                    Picker("", selection: $currency) { ForEach(["KWD", "SAR", "AED", "QAR", "BHD", "OMR", "USD"], id: \.self) { Text($0).tag($0) } }
                        .pickerStyle(.menu).tint(Theme.ink).frame(height: 48)
                }
            }
            FieldLabel(text: model.t("sub.cycle"))
            Flow { ForEach(["weekly", "monthly", "quarterly", "semiannual", "yearly"], id: \.self) { c in Chip(title: model.t("cyclename." + c), on: cycle == c) { cycle = c } } }
            DatePicker(model.t("sub.next"), selection: $next, displayedComponents: .date).font(Theme.body(15)).padding(.top, 12)
            Toggle(model.t("sub.trial_q"), isOn: $trial).font(Theme.body(15)).tint(Theme.ok).padding(.top, 8)
            FieldLabel(text: model.t("sub.category"))
            Flow { ForEach(Array(SubSheet.cats.keys).sorted(), id: \.self) { c in Chip(title: model.t("cat." + c), icon: SubSheet.cats[c], on: category == c) { category = c } } }
            WideButton(title: model.t("act.save")) { save() }.padding(.top, 18)
            if let s = existing {
                if s.cancelled != true {
                    WideButton(title: model.t("ask.cancelled"), primary: false) { model.update("toast.cancelled", ["name": s.name]) { $0.cancelSub(s.id) }; dismiss() }.padding(.top, 8)
                }
                WideButton(title: model.t("act.delete"), primary: false, danger: true) { model.update("toast.deleted") { $0.deleteSub(s.id) }; dismiss() }.padding(.top, 8)
            }
        }
        .onAppear(perform: load)
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        currency = model.state?.settings.currency ?? "KWD"
        guard let s = existing else { return }
        name = s.name
        currency = s.currency
        amount = formatMoney(s.amount, s.currency, "en").split(separator: " ").last.map(String.init) ?? ""
        cycle = s.cycle
        trial = s.trial == true
        category = s.category ?? "other"
        if let v = model.brain.subs().first(where: { $0.id == s.id }) {
            let p = v.next.ymd
            next = Calendar.current.date(from: DateComponents(year: p.y, month: p.m, day: p.d)) ?? next
        }
    }

    func save() {
        let title = name.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { model.toast = Toast(text: model.t("err.title"), undo: nil); return }
        guard let minor = parseMoney(amount, currency) else { model.toast = Toast(text: model.t("err.amount"), undo: nil); return }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: next)
        let anchor = Day(y: c.year!, m: c.month!, d: c.day!).iso
        var s = existing ?? Sub(id: newID(), name: title, amount: minor, currency: currency, cycle: cycle, anchor: anchor, usage: [:])
        s.name = title; s.amount = minor; s.currency = currency; s.cycle = cycle; s.anchor = anchor
        s.trial = trial ? true : nil; s.category = category
        model.update("toast.saved") { $0.saveSub(s) }
        dismiss()
    }
}

struct AssetSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let kind: AssetKind
    let existingId: String?
    @State private var name = ""
    @State private var type = ""
    @State private var features: [String: Bool] = ["central_ac": false, "tank": true, "filter": false]
    @State private var km = ""
    @State private var daily = "40"
    @State private var loaded = false

    var body: some View {
        let isNew = existingId == nil
        let title = kind == .home ? (isNew ? model.t("act.add_home") : model.t("act.edit_home"))
            : kind == .car ? (isNew ? model.t("act.add_car") : model.t("act.edit_car"))
            : (isNew ? model.t("act.add_thing") : model.t("act.edit_thing"))
        SheetFrame(title: title) {
            if kind == .home {
                FieldLabel(text: model.t("setup.type"))
                Flow { ForEach(["house", "flat", "chalet", "farm", "jakhoor"], id: \.self) { ty in Chip(title: model.t("type." + ty), on: type == ty) { type = ty } } }
            }
            if kind == .thing && isNew {
                FieldLabel(text: model.t("thing.type"))
                Flow { ForEach(model.catalog.thingTypes, id: \.id) { tt in Chip(title: tt.name(model.lang), icon: tt.icon, on: type == tt.id) { type = tt.id } } }
            }
            FieldLabel(text: kind == .car ? model.t("car.name") : kind == .thing ? model.t("thing.name") : model.t("setup.name"))
            InputField(placeholder: placeholder, text: $name)
            if kind == .home {
                FieldLabel(text: model.t("setup.has"))
                ForEach(["central_ac", "tank", "filter"], id: \.self) { f in
                    Toggle(model.t("feat." + f), isOn: Binding(get: { features[f] ?? false }, set: { features[f] = $0 })).font(Theme.body(15)).tint(Theme.ok)
                }
            }
            if kind == .car {
                if isNew { FieldLabel(text: model.t("car.km_now")); InputField(placeholder: "84000", text: $km, numbers: true) }
                FieldLabel(text: model.t("car.daily")); InputField(placeholder: "40", text: $daily, numbers: true)
                Text(model.t("car.daily_note")).font(Theme.body(13)).foregroundStyle(Theme.ink3).padding(.top, 6)
            }
            WideButton(title: model.t("act.save")) { save() }.padding(.top, 18)
            if let id = existingId {
                WideButton(title: kind == .home ? model.t("act.delete_home") : kind == .car ? model.t("act.delete_car") : model.t("act.delete_thing"), primary: false, danger: true) {
                    model.update("toast.deleted") { $0.removeAsset(id) }
                    dismiss()
                }
                .padding(.top, 8)
            }
        }
        .onAppear(perform: load)
    }

    var placeholder: String {
        switch kind {
        case .home: return model.t("type." + (type.isEmpty ? "house" : type))
        case .car: return model.t("car.default")
        case .thing: return model.catalog.thingTypes.first { $0.id == type }?.name(model.lang) ?? model.t("thing.name")
        }
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        type = kind == .home ? "house" : kind == .thing ? "boat" : ""
        guard let id = existingId, let s = model.state else { return }
        if let h = s.homes.first(where: { $0.id == id }) { name = h.name; type = h.type; features = h.features ?? features }
        if let c = s.cars.first(where: { $0.id == id }) { name = c.name; daily = String(c.dailyKm ?? 40) }
        if let t = s.things.first(where: { $0.id == id }) { name = t.name; type = t.type }
    }

    func save() {
        let n = name.trimmingCharacters(in: .whitespaces).isEmpty ? placeholder : name.trimmingCharacters(in: .whitespaces)
        if let id = existingId {
            model.update("toast.saved") { b in
                if let i = b.state.homes.firstIndex(where: { $0.id == id }) {
                    b.state.homes[i].name = n; b.state.homes[i].type = type; b.state.homes[i].features = features
                    for t in b.catalog.templates where t.kind == "home" && t.needs != nil {
                        let has = features[t.needs!] == true
                        if let j = b.state.items.firstIndex(where: { $0.asset == id && $0.tpl == t.id }) { b.state.items[j].enabled = has }
                        else if has && t.isDefault { b.addTemplate(t.id, to: id) }
                    }
                    b.spreadNew([id])
                }
                if let i = b.state.cars.firstIndex(where: { $0.id == id }) { b.state.cars[i].name = n; b.state.cars[i].dailyKm = wholeNumber(daily) ?? 40 }
                if let i = b.state.things.firstIndex(where: { $0.id == id }) { b.state.things[i].name = n }
            }
        } else {
            model.update("toast.added") { b in
                let created: String
                switch kind {
                case .home: created = b.addHome(type: type, name: n, features: features).id
                case .car: created = b.addCar(name: n, km: wholeNumber(km), dailyKm: wholeNumber(daily) ?? 40).id
                case .thing: created = b.addThing(type: type, name: n).id
                }
                b.spreadNew([created])
            }
        }
        dismiss()
    }
}

struct OdoSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let carId: String
    @State private var km = ""

    var body: some View {
        SheetFrame(title: model.t("act.update_odo")) {
            Text(model.t("odo.body")).font(Theme.body(14)).foregroundStyle(Theme.ink2).padding(.top, 4)
            FieldLabel(text: model.t("item.km"))
            InputField(placeholder: "84000", text: $km, numbers: true)
            WideButton(title: model.t("act.save")) {
                guard let k = wholeNumber(km) else { model.toast = Toast(text: model.t("err.number"), undo: nil); return }
                model.update("toast.saved") { $0.addReading(car: carId, km: k, on: model.today) }
                dismiss()
            }
            .padding(.top, 18)
        }
        .onAppear {
            if let car = model.state?.cars.first(where: { $0.id == carId }), let k = kmOn(car.odometer, model.today) { km = String(k) }
        }
    }
}

struct AskCard: View {
    @EnvironmentObject var model: AppModel
    let s: SubView

    var body: some View {
        let w = model.words
        VStack(alignment: .leading, spacing: 8) {
            if s.planned {
                Text(model.t("ask.cancel_title", ["name": s.sub.name])).font(Theme.title(18)).foregroundStyle(Theme.ink)
                Text(model.t("ask.cancel_body")).font(Theme.body(14)).foregroundStyle(Theme.ink2).lineSpacing(3)
                HStack(spacing: 8) {
                    WideButton(title: model.t("ask.cancelled")) { model.update("toast.cancelled", ["name": s.sub.name]) { $0.cancelSub(s.id) } }
                    WideButton(title: model.t("ask.keep"), primary: false) { model.update("toast.kept", ["name": s.sub.name]) { $0.answer(sub: s.id, keep: true) } }
                }
            } else {
                Text(model.t(s.trial ? "ask.q_trial" : "ask.q", ["name": s.sub.name])).font(Theme.title(18)).foregroundStyle(Theme.ink)
                Text("\(s.days == 0 ? model.t("sub.renews_today") : model.t("sub.renews", ["rel": w.rel(s.days)]))\(w.comma)\(w.money(s.sub.amount, s.sub.currency))")
                    .font(Theme.body(14)).foregroundStyle(Theme.ink2)
                HStack(spacing: 8) {
                    WideButton(title: model.t("ask.yes"), primary: false) { model.update("toast.kept", ["name": s.sub.name]) { $0.answer(sub: s.id, keep: true) } }
                    WideButton(title: model.t("ask.no"), primary: false) { model.update { $0.answer(sub: s.id, keep: false) } }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((s.planned ? Theme.overdue : Theme.soon).opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke((s.planned ? Theme.overdue : Theme.soon).opacity(0.3), lineWidth: 1))
    }
}
