// The screens, laid out as the web lays them out.
import NokhathaKit
import SwiftUI

/// The web's .page: 18 at the sides, room for the tab bar below.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 110)
        }
    }
}

// MARK: - rows

let subCatIcons = ["stream": "play", "music": "music", "cloud": "cloud", "games": "game", "gym": "gym", "internet": "wifi", "phone": "phone", "apps": "apps"]

/// The web's .row for a task: icon, title and meta, the weave, and the done button at the end.
struct TaskRow: View {
    @EnvironmentObject var model: AppModel
    let e: Evaluated
    var showAsset = false
    @State private var open = false

    var body: some View {
        let w = model.words
        let line = w.due(e, today: model.today)
        let tint = Theme.tint(e.status)
        HStack(spacing: 10) {
            Button { open = true } label: {
                HStack(spacing: 12) {
                    RowIcon(icon: e.icon, tint: tint, bg: Theme.tintBg(e.status))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title(model.lang)).font(Theme.body(15.5, "SemiBold")).foregroundStyle(Theme.ink).lineLimit(2).multilineTextAlignment(.leading)
                        HStack(spacing: 10) {
                            Text(line.rel).font(Theme.body(13.5, "SemiBold")).foregroundStyle(tint).lineLimit(1)
                            if let d = line.detail { Text(d).font(Theme.body(13.5)).foregroundStyle(Theme.ink3).lineLimit(1) }
                            if showAsset { MetaTag(text: e.asset.name) }
                        }
                        if let p = model.brain.progress(e) { ProgressLine(value: p, color: tint) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if e.every.fixed == true {
                Button { if e.due == nil { open = true } else { model.renew(e) } } label: {
                    Text(e.due == nil ? model.t("act.setdate") : model.t("act.renewed")).font(Theme.body(13.5, "Bold")).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).frame(minWidth: 64).frame(height: 46)
                        .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line, lineWidth: 1.6))
                }
                .buttonStyle(.plain)
            } else {
                Button { model.done(e) } label: {
                    Image(systemName: "checkmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink3)
                        .frame(width: 46, height: 46).background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(e.status == "overdue" ? Theme.overdue.opacity(0.45) : Theme.line, lineWidth: 1.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.t("act.done_label", ["title": e.title(model.lang)]))
            }
        }
        .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 10)
        .sheet(isPresented: $open) { TaskSheet(e: e) { open = false } }
        .onAppear { if model.autoSheet == "task" && e.status == "overdue" { model.autoSheet = nil; open = true } }
    }
}

struct TaskList: View {
    let rows: [Evaluated]
    var showAsset = false
    var body: some View {
        ListCard {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, e in
                if i > 0 { RowLine() }
                TaskRow(e: e, showAsset: showAsset)
            }
        }
    }
}

/// The web's grouped rows: a small area heading, then a list.
struct GroupedRows: View {
    @EnvironmentObject var model: AppModel
    let tasks: [Evaluated]
    let areas: [Named]
    var body: some View {
        ForEach(areas, id: \.id) { area in
            let rows = tasks.filter { ($0.tpl?.area ?? "custom") == area.id }
            if !rows.isEmpty {
                SmallHead(text: area.name(model.lang))
                TaskList(rows: rows)
            }
        }
    }
}

// MARK: - today

struct TodayScreen: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let b = model.brain
        let w = model.words
        let tasks = b.tasks()
        let now = tasks.filter { ["overdue", "today", "soon"].contains($0.status) }
        let later = Array(tasks.filter { $0.status == "ok" && ($0.days ?? 999) <= 30 }.prefix(6))
        let subs = b.subs()
        let talk = subs.filter { $0.ask || $0.planned }
        let warr = b.warranties().filter { $0.status == "soon" || $0.status == "today" }
        let docsSoon = b.docs().filter { ["soon", "today", "overdue"].contains($0.status) }
        let season = seasonAt(model.today, model.catalog.seasons)
        let dots = tasks.compactMap { e in e.days.map { DialDot(days: $0, status: e.status) } } + subs.filter { $0.status != "off" }.map { DialDot(days: $0.days, status: "sub") }
        let totals = b.totals()
        let cur = totals[model.state?.settings.currency ?? ""] != nil ? model.state?.settings.currency : totals.keys.sorted().first
        Page {
            VStack(alignment: .leading, spacing: 0) {
                Text(w.greeting(hour: Calendar.current.component(.hour, from: Date()))).font(Theme.title(24)).foregroundStyle(Theme.ink)
                Text(w.longDate(model.today)).font(Theme.body(14)).foregroundStyle(Theme.ink3)
            }
            .padding(.top, 2).padding(.bottom, 4)
            DialView(today: model.today, catalog: model.catalog, dots: dots, center: w.seasonCenter(season, catalog: model.catalog, today: model.today))
                .frame(maxWidth: .infinity).padding(.top, 4).padding(.bottom, 10)
            if let hint = model.catalog.season(season.id)?.hint(model.lang) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkle").font(.system(size: 14)).foregroundStyle(Theme.sadu).padding(.top, 4)
                    Text(hint).font(Theme.body(14.5)).foregroundStyle(Theme.ink2).lineSpacing(4)
                }
                .padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
                .padding(.top, 6)
            }
            SectionTitle(text: model.t("today.now"), count: now.count)
            if now.isEmpty { EmptyNote(icon: "done", text: model.t("today.clear")) } else { TaskList(rows: now, showAsset: true) }
            if let first = talk.first { AskCard(s: first).padding(.top, 14) }
            if talk.count > 1 {
                Button { model.tab = "subs" } label: {
                    Text(model.t("today.more_asks")).font(Theme.body(14, "SemiBold")).foregroundStyle(Theme.ink2).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            if let cur, let t = totals[cur] {
                ListCard {
                    Button { model.tab = "subs" } label: {
                        HStack(spacing: 10) {
                            Image(systemName: Symbol.name("repeat")).font(.system(size: 16)).foregroundStyle(Theme.ok)
                            Text(model.t("today.subs", ["amount": w.money(t.month, cur)])).font(Theme.body(15, "SemiBold")).foregroundStyle(Theme.ink)
                            Spacer()
                            Chevron()
                        }
                        .padding(14).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            }
            if !warr.isEmpty {
                SectionTitle(text: model.t("today.warranties"))
                WarrantyList(list: warr)
            }
            if !docsSoon.isEmpty {
                SectionTitle(text: model.t("today.docs"))
                DocList(list: docsSoon)
            }
            if !later.isEmpty {
                SectionTitle(text: model.t("today.later"))
                TaskList(rows: later, showAsset: true)
            }
        }
    }
}

// MARK: - home, car, belongings

struct AssetsScreen: View {
    @EnvironmentObject var model: AppModel
    let kind: AssetKind
    var onBack: (() -> Void)? = nil
    @State private var selected: String?
    @State private var sheet: String?

    var body: some View {
        let state = model.state ?? AppState()
        let list: [(String, String)] = {
            switch kind {
            case .home: return state.homes.map { ($0.id, $0.name) }
            case .car: return state.cars.map { ($0.id, $0.name) }
            case .thing: return state.things.map { ($0.id, $0.name) }
            }
        }()
        let current = list.first { $0.0 == selected } ?? list.first
        let tasks = current.map { c in model.brain.tasks { $0.asset == c.0 } } ?? []
        let areas = model.catalog.areas[kind.rawValue] ?? []
        let add = kind == .home ? "act.add_home" : kind == .car ? "act.add_car" : "act.add_thing"
        let edit = kind == .home ? "act.edit_home" : kind == .car ? "act.edit_car" : "act.edit_thing"
        let icon = kind == .home ? "home" : kind == .car ? "car" : "box"
        let name = model.t(kind == .home ? "tab.home" : kind == .car ? "tab.car" : "more.things")
        Page {
            PageHead(title: name, band: kind == .thing ? "more" : kind.rawValue, back: onBack, backText: model.t("tab.more")) {
                if !list.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(list, id: \.0) { id, n in ChipButton(text: n, on: id == current?.0) { selected = id } }
                            ChipButton(text: model.t(add), on: false, icon: "plus", dashed: true) { sheet = "add" }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            if let current {
                if kind == .car, let car = state.cars.first(where: { $0.id == current.0 }) {
                    let km = kmOn(car.odometer, model.today)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(model.t("car.odo")).font(Theme.body(13, "SemiBold")).foregroundStyle(Theme.ink3)
                            Text(km.map { model.words.km($0) } ?? model.t("car.odo_unknown")).font(Theme.title(28)).foregroundStyle(Theme.ink)
                            Text(lastReading(car.odometer).flatMap { r in Day(iso: r.date).map { model.t("car.odo_last", ["km": model.words.km(r.km), "date": model.words.date($0, today: model.today)]) } } ?? model.t("car.odo_none"))
                                .font(Theme.body(13)).foregroundStyle(Theme.ink2)
                        }
                        Spacer(minLength: 8)
                        WideButton(title: model.t("act.update_odo"), primary: false, icon: "gauge", block: false) { sheet = "odo" }
                    }
                    .padding(16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    RenewalCard(carId: current.0)
                }
                if tasks.isEmpty { EmptyNote(icon: icon, text: model.t("empty." + kind.rawValue)) } else { GroupedRows(tasks: tasks, areas: areas) }
                ButtonPair(a: model.t("act.add_task"), onA: { sheet = "task" }, b: model.t(edit), onB: { sheet = "edit" }, aIcon: "plus", bIcon: "edit", bQuiet: true).padding(.top, 16)
            } else {
                EmptyNote(icon: icon, text: model.t("empty." + kind.rawValue), big: true) {
                    WideButton(title: model.t(add), icon: "plus", block: false) { sheet = "add" }
                }
            }
        }
        .onAppear {
            switch model.autoSheet { case "addtask": sheet = "task"; case "edit": sheet = "edit"; case "odo": sheet = "odo"; default: return }
            model.autoSheet = nil
        }
        .sheet(isPresented: Binding(get: { sheet != nil }, set: { if !$0 { sheet = nil } })) {
            switch sheet {
            case "add": AssetSheet(kind: kind, existingId: nil) { sheet = nil }
            case "edit": AssetSheet(kind: kind, existingId: current?.0) { sheet = nil }
            case "task": AddTaskSheet(assetId: current?.0 ?? "") { sheet = nil }
            default: OdoSheet(carId: current?.0 ?? "") { sheet = nil }
            }
        }
    }
}

/// The web's chip: a 40 pill sized to its words, for the asset tabs.
struct ChipButton: View {
    let text: String
    let on: Bool
    var icon: String? = nil
    var dashed = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: Symbol.name(icon)).font(.system(size: 13)) }
                Text(text).lineLimit(1)
            }
            .font(Theme.body(14.5, on ? "SemiBold" : "Regular")).foregroundStyle(on ? Theme.onInk : dashed ? Theme.ink3 : Theme.ink2)
            .padding(.horizontal, 15).frame(height: 40)
            .background(on ? Theme.ink : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(on ? Theme.ink : Theme.line, style: StrokeStyle(lineWidth: 1, dash: dashed ? [5, 4] : [])))
        }
        .buttonStyle(.plain)
    }
}

/// The web's renewal path: the steps for the chosen country with their links, the term, and the button that sets the next dates.
struct RenewalCard: View {
    @EnvironmentObject var model: AppModel
    let carId: String
    var body: some View {
        let b = model.brain
        if b.renewalShown(carId), let plan = model.catalog.renewPlan(model.country), let car = model.state?.cars.first(where: { $0.id == carId }) {
            let done = car.renewal?.done ?? []
            let years = car.renewal?.years ?? plan.years.first ?? 1
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: Symbol.name("id")).font(.system(size: 16)).foregroundStyle(Theme.ink2)
                    Text(model.t("renew.title")).font(Theme.title(19)).foregroundStyle(Theme.ink)
                }
                Lede(text: model.t("renew.lede", ["portal": plan.portalName(model.lang)]), small: true).padding(.top, 4)
                ListCard {
                    ForEach(Array(plan.steps.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { RowLine() }
                        let on = done.contains(s.id)
                        HStack(spacing: 12) {
                            Button { model.update { $0.setRenewStep(carId, s.id, on: !on) } } label: {
                                HStack(spacing: 12) {
                                    CheckBox(on: on)
                                    Text(s.name(model.lang)).font(Theme.body(16)).foregroundStyle(on ? Theme.ink3 : Theme.ink).strikethrough(on).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if let link = s.link {
                                Button { model.openUrl(link) } label: {
                                    Image(systemName: Symbol.name("link")).font(.system(size: 15)).foregroundStyle(Theme.ink3).frame(width: 34, height: 34)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
                    }
                }
                if plan.years.count > 1 {
                    FieldLabel(text: model.t("renew.years"))
                    Seg(options: plan.years.map { (String($0), model.words.yearCount($0)) }, selected: String(years)) { v in model.update { $0.setRenewYears(carId, Int(v) ?? 1) } }
                }
                WideButton(title: model.t("renew.done"), icon: "done") { model.update("renew.done_toast") { $0.finishRenewal(carId) } }.padding(.top, 12)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .padding(.top, 14).padding(.bottom, 4)
        }
    }
}

struct CheckBox: View {
    let on: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous).fill(on ? Theme.ok : Color.clear).frame(width: 24, height: 24)
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(on ? Theme.ok : Theme.line, lineWidth: 1.6))
            .overlay { if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.onInk) } }
    }
}

// MARK: - subscriptions

struct SubsScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var editing: Sub?
    @State private var adding = false

    var body: some View {
        let b = model.brain
        let w = model.words
        let totals = b.totals()
        let main = totals[model.state?.settings.currency ?? ""] != nil ? model.state?.settings.currency : totals.keys.sorted().first
        let subs = b.subs().sorted { a, c in (a.sub.cancelled == true ? 1 : 0, a.next.n) < (c.sub.cancelled == true ? 1 : 0, c.next.n) }
        Page {
            PageHead(title: model.t("tab.subs"), band: "subs")
            if subs.isEmpty {
                EmptyNote(icon: "repeat", text: model.t("empty.subs"), big: true) { WideButton(title: model.t("act.add_sub"), icon: "plus", block: false) { adding = true } }
            } else {
                if let main, let t = totals[main] {
                    CardBox(padding: 18) {
                        Text(model.t("subs.month")).font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.ink3)
                        Text(w.money(t.month, main)).font(Theme.title(40)).foregroundStyle(Theme.ink)
                        Text(model.t("subs.year", ["amount": w.money(t.year, main)])).font(Theme.body(14)).foregroundStyle(Theme.ink2)
                        ForEach(totals.keys.sorted().filter { $0 != main }, id: \.self) { c in
                            Text(w.money(totals[c]!.month, c) + " " + model.t("cycle.monthly")).font(Theme.body(14, "SemiBold")).foregroundStyle(Theme.ink2)
                        }
                    }
                }
                ForEach(subs.filter { $0.ask || $0.planned }) { s in AskCard(s: s).padding(.top, 14) }
                SectionTitle(text: model.t("subs.all"), count: subs.filter { $0.sub.cancelled != true }.count)
                ListCard {
                    ForEach(Array(subs.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { RowLine() }
                        let off = s.sub.cancelled == true
                        let status = off ? "off" : s.status
                        Button { editing = s.sub } label: {
                            HStack(spacing: 12) {
                                RowIcon(icon: subCatIcons[s.sub.category ?? ""] ?? "repeat", tint: Theme.tint(status), bg: Theme.tintBg(status))
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 7) {
                                        Text(s.sub.name).font(Theme.body(15.5, "SemiBold")).foregroundStyle(off ? Theme.ink3 : Theme.ink).strikethrough(off)
                                        if s.trial && !off { Circle().fill(Theme.soon).frame(width: 7, height: 7) }
                                    }
                                    HStack(spacing: 10) {
                                        Text(off ? model.t("sub.cancelled") : s.trial && s.days == 0 ? model.t("sub.trial_today") : s.trial ? model.t("sub.trial", ["rel": w.rel(s.days)]) : s.days == 0 ? model.t("sub.renews_today") : model.t("sub.renews", ["rel": w.rel(s.days)]))
                                            .font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.tint(status))
                                        if !off && !s.trial { Text(w.date(s.next, today: model.today)).font(Theme.body(13.5)).foregroundStyle(Theme.ink3) }
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(w.money(s.sub.amount, s.sub.currency)).font(Theme.body(15, "Bold")).foregroundStyle(Theme.ink)
                                    Text(model.t("cycle." + s.sub.cycle)).font(Theme.body(12)).foregroundStyle(Theme.ink3)
                                }
                            }
                            .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 14).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                WideButton(title: model.t("act.add_sub"), primary: false, icon: "plus") { adding = true }.padding(.top, 16)
            }
        }
        .onAppear { if model.autoSheet == "sub" { model.autoSheet = nil; editing = subs.first?.sub } }
        .sheet(item: $editing) { s in SubSheet(existing: s) { editing = nil } }
        .sheet(isPresented: $adding) { SubSheet(existing: nil) { adding = false } }
    }
}

// MARK: - first run

struct WelcomeScreen: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 60)
                Image("Mark").resizable().frame(width: 96, height: 96)
                Text(model.t("app.name")).font(Theme.display(56)).foregroundStyle(Theme.ink).padding(.top, 6)
                Text(model.t("welcome.tag")).font(Theme.title(21)).foregroundStyle(Theme.overdue)
                Text(model.t("welcome.body")).font(Theme.body(16)).foregroundStyle(Theme.ink2).lineSpacing(6).multilineTextAlignment(.center).padding(.top, 12).padding(.bottom, 6)
                Seg(options: [("ar", "عربي"), ("en", "English")], selected: model.lang, compact: true) { model.setLang($0) }.padding(.top, 6).padding(.bottom, 16)
                WideButton(title: model.t("welcome.start")) { model.beginSetup() }
                WideButton(title: model.t("welcome.demo"), quiet: true) { model.startWithSample() }.padding(.top, 12)
                HStack(spacing: 6) {
                    Image(systemName: "lock").font(.system(size: 13)).foregroundStyle(Theme.ink3)
                    Text(model.t("welcome.private")).font(Theme.body(13.5)).foregroundStyle(Theme.ink3)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 22).padding(.vertical, 36)
        }
    }
}

struct SetupScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var d = Brain.Setup()
    @State private var extraName = ""
    @State private var extraMonths = "6"
    @State private var homeName = ""
    @State private var carName = ""
    @State private var km = ""
    @State private var other = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.t("setup.step", ["n": "1", "of": "2"])).font(Theme.body(13, "Bold")).foregroundStyle(Theme.overdue)
                Text(model.t("setup.title")).font(Theme.title(30)).foregroundStyle(Theme.ink)
                FieldLabel(text: model.t("setup.country"))
                ChoiceGrid(items: Array(Brain.countries.keys).sorted { ["KW", "SA", "AE", "QA", "BH", "OM"].firstIndex(of: $0)! < ["KW", "SA", "AE", "QA", "BH", "OM"].firstIndex(of: $1)! }, columns: 3, isOn: { d.country == $0 }, label: { model.t("country." + $0) }) { d.country = $0 }
                FieldLabel(text: model.t("setup.type"))
                ChoiceGrid(items: ["house", "flat", "chalet", "farm", "jakhoor"], columns: 3, isOn: { d.homeType == $0 }, label: { model.t("type." + $0) }) { d.homeType = $0; d.features["tank"] = $0 != "flat" }
                FieldLabel(text: model.t("setup.name"))
                Input(text: $homeName, placeholder: model.t("type." + d.homeType))
                FieldLabel(text: model.t("setup.has"))
                SwitchCard(rows: ["central_ac", "tank", "filter"].map { f in (model.t("feat." + f), Binding(get: { d.features[f] ?? false }, set: { d.features[f] = $0 })) })
                FieldLabel(text: model.t("setup.extra"))
                if !d.extras.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(d.extras.enumerated()), id: \.offset) { i, x in
                                ChipButton(text: "\(x.title)  \(model.t("setup.every_\(x.months)"))", on: true, icon: "close") { d.extras.remove(at: i) }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                HStack(spacing: 8) {
                    Input(text: $extraName, placeholder: model.t("setup.extra_ph"))
                    Select(value: extraMonths, options: [1, 3, 6, 12].map { (String($0), model.t("setup.every_\($0)")) }, width: 118) { extraMonths = $0 }
                    Button {
                        let t = extraName.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { d.extras.append((title: t, months: Int(extraMonths) ?? 6)); extraName = "" }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).frame(width: 48, height: 48)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                FieldLabel(text: model.t("setup.car"))
                SwitchCard(rows: [(model.t("setup.has_car"), $d.hasCar)])
                if d.hasCar {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("car.name")); Input(text: $carName, placeholder: model.t("car.default")) }
                        VStack(alignment: .leading, spacing: 0) { FieldLabel(text: model.t("car.km_now")); Input(text: $km, placeholder: "84000", numbers: true) }
                    }
                }
                FieldLabel(text: model.t("setup.things"))
                ChoiceGrid(items: model.catalog.thingTypes, columns: 3, isOn: { d.things.contains($0.id) }, label: { $0.name(model.lang) }, icon: { $0.icon }) { tt in
                    if let i = d.things.firstIndex(of: tt.id) { d.things.remove(at: i) } else { d.things.append(tt.id) }
                }
                if d.things.contains("other") {
                    FieldLabel(text: model.t("setup.other"))
                    Input(text: $other, placeholder: model.t("setup.other_ph"))
                }
                WideButton(title: model.t("act.next")) {
                    d.homeName = homeName; d.carName = carName; d.km = wholeNumber(km); d.otherName = other
                    model.runSetup(d)
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 40)
        }
        .onAppear { d.country = AppModel.guessCountry() }
    }
}

struct LastTimeScreen: View {
    @EnvironmentObject var model: AppModel
    let created: [String]
    @State private var answers: [String: String] = [:]

    var body: some View {
        let questions = model.brain.lastQuestions(created: created)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.t("setup.step", ["n": "2", "of": "2"])).font(Theme.body(13, "Bold")).foregroundStyle(Theme.overdue)
                Text(model.t("last.title")).font(Theme.title(30)).foregroundStyle(Theme.ink)
                Lede(text: model.t("last.body"))
                ForEach(questions, id: \.id) { q in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(q.tpl.flatMap { model.catalog.template[$0]?.name(model.lang) } ?? "").font(Theme.body(16, "SemiBold")).foregroundStyle(Theme.ink).padding(.bottom, 10)
                        ChoiceGrid(items: Brain.lastOptions.map(\.key), columns: 3, isOn: { (answers[q.id] ?? "unknown") == $0 }, label: { model.t("last." + $0) }, small: true) { answers[q.id] = $0 }
                    }
                    .padding(.vertical, 14)
                    RowLine()
                }
                WideButton(title: model.t("act.finish")) { model.finishSetup(created, answers: answers) }.padding(.top, 20)
            }
            .padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 40)
        }
    }
}

/// Reads digits typed in Arabic or Western numerals.
func wholeNumber(_ s: String) -> Int? {
    let digits = normalizeDigits(s).filter { $0.isNumber }
    return digits.isEmpty ? nil : Int(digits)
}
