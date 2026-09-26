// The app's logic, ported from docs/app/app.js and docs/app/store.js so the iPhone
// shows the same tasks, in the same order, with the same dates as the web app.

import Foundation

public enum AssetKind: String, Sendable { case home, car, thing }

public struct AssetRef: Hashable, Sendable {
    public let id: String
    public let kind: AssetKind
    public let name: String
    public let car: CarOdometer?
}

public struct Evaluated: Identifiable, Hashable, Sendable {
    public var id: String { item.id }
    public let item: Item
    public let asset: AssetRef
    public let tpl: Template?
    public let every: Every
    public let due: Day?
    public let by: String
    public let status: String
    public let days: Int?

    public func title(_ lang: String) -> String { tpl?.name(lang) ?? item.title ?? "" }
    public var icon: String { tpl?.icon ?? "spark" }
}

public struct SubView: Identifiable, Hashable, Sendable {
    public var id: String { sub.id }
    public let sub: Sub
    public let next: Day
    public let days: Int
    public let trial: Bool
    public let status: String
    public let ask: Bool
    public let planned: Bool
}

let rank = ["overdue": 0, "today": 1, "soon": 2, "unset": 3, "ok": 4]

public struct Brain: Sendable {
    public let catalog: Catalog
    public var state: AppState
    public var today: Day

    public init(catalog: Catalog, state: AppState, today: Day) {
        self.catalog = catalog; self.state = state; self.today = today
    }

    // MARK: lookups

    public func asset(_ id: String) -> AssetRef? {
        if let h = state.homes.first(where: { $0.id == id }) { return AssetRef(id: h.id, kind: .home, name: h.name, car: nil) }
        if let c = state.cars.first(where: { $0.id == id }) { return AssetRef(id: c.id, kind: .car, name: c.name, car: c.odometer) }
        if let t = state.things.first(where: { $0.id == id }) { return AssetRef(id: t.id, kind: .thing, name: t.name, car: nil) }
        return nil
    }

    public func every(_ item: Item) -> Every {
        item.every ?? item.tpl.flatMap { catalog.template[$0]?.every } ?? Every(months: 6)
    }

    public func evaluate(_ item: Item, templates: [String: Template]? = nil) -> Evaluated? {
        guard let asset = asset(item.asset) else { return nil }
        let tpls = templates ?? catalog.template
        let e = every(item)
        let input = DueInput(every: e, lastDone: item.lastDone.flatMap(Day.init(iso:)), lastKm: item.lastKm,
                             due: item.due.flatMap(Day.init(iso:)), snoozeUntil: item.snoozeUntil.flatMap(Day.init(iso:)),
                             firstDue: item.firstDue.flatMap(Day.init(iso:)))
        let nd = nextDue(input, today: today, seasons: catalog.seasons, bawarih: catalog.bawarih, car: asset.car)
        let lead = e.fixed == true ? (e.lead ?? 30) : state.settings.lead
        let st = statusOf(nd.due, today: today, lead: lead)
        return Evaluated(item: item, asset: asset, tpl: item.tpl.flatMap { tpls[$0] }, every: e, due: nd.due, by: nd.by, status: st.status, days: st.days)
    }

    /// Enabled tasks, most urgent first, then by date.
    public func tasks(_ include: (Item) -> Bool = { _ in true }) -> [Evaluated] {
        let tpls = catalog.template
        return state.items.filter { $0.isOn && include($0) }.compactMap { evaluate($0, templates: tpls) }.sorted { a, b in
            let ra = rank[a.status] ?? 9, rb = rank[b.status] ?? 9
            if ra != rb { return ra < rb }
            return (a.due?.n ?? Int.max) < (b.due?.n ?? Int.max)
        }
    }

    public func progress(_ e: Evaluated) -> Double? {
        guard e.every.fixed != true, let last = e.item.lastDone.flatMap(Day.init(iso:)), let due = e.due else { return nil }
        return cycleProgress(lastDone: last, due: due, today: today)
    }

    public func subs() -> [SubView] {
        state.subs.compactMap { s in
            guard let anchor = Day(iso: s.anchor), let cycle = Cycle(rawValue: s.cycle) else { return nil }
            let next = nextRenewal(anchor: anchor, cycle: cycle, today: today)
            let days = diffDays(today, next)
            let answer = s.usage?[next.iso]
            let off = s.cancelled == true
            return SubView(sub: s, next: next, days: days, trial: s.trial == true && anchor >= today,
                           status: off ? "off" : statusOf(next, today: today, lead: 3).status,
                           ask: !off && days <= 7 && answer == nil, planned: !off && days <= 7 && answer == "no")
        }
    }

    public func totals() -> [String: SubTotal] {
        subTotals(state.subs.compactMap { s in
            Cycle(rawValue: s.cycle).map { SubAmount(amount: s.amount, currency: s.currency, cycle: $0, cancelled: s.cancelled == true) }
        })
    }

    // MARK: changes

    public mutating func markDone(_ id: String, on date: Day? = nil, km: Int? = nil, cost: Int? = nil) {
        guard let i = state.items.firstIndex(where: { $0.id == id }) else { return }
        let when = date ?? today
        var item = state.items[i]
        var entry = LogEntry(date: when.iso)
        if let a = asset(item.asset), a.kind == .car, set(every(item).km) != nil, let ci = state.cars.firstIndex(where: { $0.id == a.id }) {
            if let km {
                var readings = (state.cars[ci].readings ?? []).filter { $0.date != when.iso }
                readings.append(Reading(date: when.iso, km: km))
                state.cars[ci].readings = readings.sorted { $0.date < $1.date }
            }
            let k = km ?? kmOn(state.cars[ci].odometer, when)
            item.lastKm = k
            entry.km = k
        }
        if let cost { entry.cost = cost; entry.cur = state.settings.currency }
        item.lastDone = when.iso
        item.snoozeUntil = nil
        item.log = (item.log ?? []) + [entry]
        state.items[i] = item
    }

    public mutating func snooze(_ id: String, days: Int = 7) {
        guard let i = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[i].snoozeUntil = today.adding(days).iso
    }

    public mutating func renew(_ id: String) {
        guard let i = state.items.firstIndex(where: { $0.id == id }), let due = state.items[i].due.flatMap(Day.init(iso:)) else { return }
        state.items[i].due = due.addingMonths(every(state.items[i]).repeatMonths ?? 12).iso
        state.items[i].lastDone = today.iso
        state.items[i].log = (state.items[i].log ?? []) + [LogEntry(date: today.iso)]
    }

    func wants(_ t: Template, _ features: [String: Bool]) -> Bool {
        t.isDefault && (t.needs == nil || features[t.needs!] == true)
    }

    @discardableResult
    public mutating func addHome(type: String, name: String, features: [String: Bool]) -> Home {
        let f = ["central_ac": false, "tank": false, "filter": false].merging(features) { $1 }
        let home = Home(id: newID(), type: type, name: name, features: f)
        state.homes.append(home)
        for t in catalog.templates where t.kind == "home" && wants(t, f) { state.items.append(Item(id: newID(), asset: home.id, tpl: t.id)) }
        return home
    }

    @discardableResult
    public mutating func addCar(name: String, km: Int?, dailyKm: Int = 40) -> Car {
        let car = Car(id: newID(), name: name, dailyKm: dailyKm, readings: km.map { [Reading(date: today.iso, km: $0)] } ?? [])
        state.cars.append(car)
        for t in catalog.templates where t.kind == "car" && t.isDefault { state.items.append(Item(id: newID(), asset: car.id, tpl: t.id)) }
        return car
    }

    @discardableResult
    public mutating func addThing(type: String, name: String) -> Thing {
        let thing = Thing(id: newID(), type: type, name: name)
        state.things.append(thing)
        for t in catalog.templates where t.kind == "thing" && t.forType == type && t.isDefault { state.items.append(Item(id: newID(), asset: thing.id, tpl: t.id)) }
        return thing
    }

    /// New assets start with many never logged tasks. Their first dates are planned about
    /// two a week, shortest interval first, instead of all being due on day one.
    public mutating func spreadNew(_ assets: [String]) {
        let tpls = catalog.template
        let pending = state.items.indices.filter { i in
            let it = state.items[i]
            return assets.contains(it.asset) && it.isOn && it.lastDone == nil && it.firstDue == nil
        }.compactMap { i -> (Int, Int)? in
            let e = state.items[i].every ?? state.items[i].tpl.flatMap { tpls[$0]?.every } ?? Every(months: 6)
            if e.fixed == true || e.season != nil { return nil }
            return (i, e.days ?? (e.months ?? 6) * 30)
        }.sorted { $0.1 < $1.1 }
        for (k, entry) in pending.enumerated() {
            let (i, span) = entry
            let offset = min(Int((Double(k) * 3.5).rounded()), span)
            state.items[i].firstDue = today.adding(offset).iso
        }
    }

    // MARK: first run, editing

    public static let countries: [String: (cc: String, len: Int, cur: String)] = [
        "KW": ("965", 8, "KWD"), "SA": ("966", 9, "SAR"), "AE": ("971", 9, "AED"),
        "QA": ("974", 8, "QAR"), "BH": ("973", 8, "BHD"), "OM": ("968", 8, "OMR"),
    ]
    public static let countryOrder = ["KW", "SA", "AE", "QA", "BH", "OM"]

    /// The questions of "when was the last time?", in the web app's order.
    public static let lastKeys = ["ac_filters", "pests", "water_tank", "water_filter", "hood", "smoke", "oil", "tire_pressure"]
    public static let lastOptions: [(key: String, days: Int?)] = [("unknown", nil), ("month", 15), ("m3", 90), ("m6", 180), ("year", 365)]

    public struct Setup: Sendable {
        public var country = "KW"
        public var homeType = "house"
        public var homeName = ""
        public var features: [String: Bool] = ["central_ac": false, "tank": true, "filter": false]
        public var extras: [(title: String, months: Int)] = []
        public var hasCar = true
        public var carName = ""
        public var km: Int?
        public var things: [String] = []
        public var otherName = ""
        public init() {}
    }

    /// Creates what the person described and returns the ids of the new home, car and belongings.
    public mutating func setUp(_ s: Setup, names: (home: String, car: String, thing: (String) -> String)) -> [String] {
        state.settings.country = s.country
        state.settings.currency = Brain.countries[s.country]?.cur ?? "KWD"
        let home = addHome(type: s.homeType, name: s.homeName.trimmingCharacters(in: .whitespaces).isEmpty ? names.home : s.homeName, features: s.features)
        var created = [home.id]
        for x in s.extras { addCustom(title: x.title, every: Every(months: x.months), to: home.id) }
        if s.hasCar {
            created.append(addCar(name: s.carName.trimmingCharacters(in: .whitespaces).isEmpty ? names.car : s.carName, km: s.km).id)
        }
        for type in s.things {
            let name = type == "other" && !s.otherName.trimmingCharacters(in: .whitespaces).isEmpty ? s.otherName : names.thing(type)
            created.append(addThing(type: type, name: name).id)
        }
        return created
    }

    /// Applies "when was the last time?" answers, then plans the first dates of the rest.
    public mutating func finishSetUp(created: [String], answers: [String: String]) {
        for (id, key) in answers {
            guard let days = Brain.lastOptions.first(where: { $0.key == key })?.days,
                  let i = state.items.firstIndex(where: { $0.id == id }) else { continue }
            state.items[i].lastDone = today.adding(-days).iso
            if let a = asset(state.items[i].asset), a.kind == .car, set(every(state.items[i]).km) != nil, let car = a.car, let now = kmOn(car, today) {
                state.items[i].lastKm = max(0, now - days * (car.dailyKm > 0 ? car.dailyKm : Engine.defaultDailyKm))
            }
        }
        spreadNew(created)
        state.settings.onboarded = true
    }

    public func lastQuestions(created: [String]) -> [Item] {
        state.items.filter { Brain.lastKeys.contains($0.tpl ?? "") && $0.isOn && created.contains($0.asset) }
            .sorted { Brain.lastKeys.firstIndex(of: $0.tpl!)! < Brain.lastKeys.firstIndex(of: $1.tpl!)! }
    }

    /// Templates that can still be added to an asset.
    public func addable(to assetId: String) -> [Template] {
        guard let a = asset(assetId) else { return [] }
        let have = Set(state.items.filter { $0.asset == assetId && $0.isOn }.compactMap(\.tpl))
        let type = state.things.first { $0.id == assetId }?.type
        return catalog.templates.filter { $0.kind == a.kind.rawValue && (a.kind != .thing || $0.forType == type) && !have.contains($0.id) }
    }

    public mutating func addTemplate(_ tplId: String, to assetId: String) {
        if let i = state.items.firstIndex(where: { $0.asset == assetId && $0.tpl == tplId }) {
            state.items[i].enabled = true
        } else {
            state.items.append(Item(id: newID(), asset: assetId, tpl: tplId))
        }
    }

    public mutating func addCustom(title: String, every: Every, to assetId: String) {
        state.items.append(Item(id: newID(), asset: assetId, tpl: nil, title: title, every: every))
    }

    /// Suggested tasks are switched off, one's own tasks are removed.
    public mutating func stop(_ itemId: String) {
        guard let i = state.items.firstIndex(where: { $0.id == itemId }) else { return }
        if state.items[i].tpl == nil { state.items.remove(at: i) } else { state.items[i].enabled = false }
    }

    public mutating func removeAsset(_ id: String) {
        state.homes.removeAll { $0.id == id }
        state.cars.removeAll { $0.id == id }
        state.things.removeAll { $0.id == id }
        state.items.removeAll { $0.asset == id }
    }

    public mutating func addReading(car id: String, km: Int, on day: Day) {
        guard let i = state.cars.firstIndex(where: { $0.id == id }) else { return }
        var r = (state.cars[i].readings ?? []).filter { $0.date != day.iso }
        r.append(Reading(date: day.iso, km: km))
        state.cars[i].readings = r.sorted { $0.date < $1.date }
    }

    public mutating func saveSub(_ sub: Sub) {
        if let i = state.subs.firstIndex(where: { $0.id == sub.id }) { state.subs[i] = sub } else { state.subs.append(sub) }
    }

    /// The answer to "still using it?" for the coming renewal.
    public mutating func answer(sub id: String, keep: Bool) {
        guard let i = state.subs.firstIndex(where: { $0.id == id }), let v = subs().first(where: { $0.id == id }) else { return }
        var usage = state.subs[i].usage ?? [:]
        usage[v.next.iso] = keep ? "yes" : "no"
        state.subs[i].usage = usage
    }

    public mutating func cancelSub(_ id: String) {
        guard let i = state.subs.firstIndex(where: { $0.id == id }) else { return }
        state.subs[i].cancelled = true
        state.subs[i].cancelledOn = today.iso
    }

    public mutating func deleteSub(_ id: String) { state.subs.removeAll { $0.id == id } }

    // MARK: sample household, the same as the web app's

    public static func sample(catalog: Catalog, lang: String, today: Day) -> AppState {
        var b = Brain(catalog: catalog, state: AppState(lang: lang), today: today)
        b.state.settings.onboarded = true
        b.state.sample = true
        let T = { (ar: String, en: String) in lang == "ar" ? ar : en }
        let home = b.addHome(type: "house", name: T("البيت", "Home"), features: ["tank": true, "filter": true])
        let chalet = b.addHome(type: "chalet", name: T("الشاليه", "Chalet"), features: ["tank": true])
        let car = b.addCar(name: T("سيارتي", "My car"), km: nil)
        if let ci = b.state.cars.firstIndex(where: { $0.id == car.id }) {
            b.state.cars[ci].readings = [Reading(date: today.adding(-130).iso, km: 61200), Reading(date: today.adding(-10).iso, km: 66050)]
        }
        func ago(_ n: Int) -> String { today.adding(-n).iso }
        func cost(_ n: Int, _ amount: Int, km: Int? = nil) -> LogEntry { LogEntry(date: ago(n), cost: amount, cur: "KWD", km: km) }
        func set(_ asset: String, _ tpl: String, _ patch: (inout Item) -> Void) {
            if let i = b.state.items.firstIndex(where: { $0.asset == asset && $0.tpl == tpl }) { patch(&b.state.items[i]) }
        }
        set(home.id, "ac_filters") { $0.lastDone = ago(33) }
        set(home.id, "ac_service") { $0.lastDone = ago(178); $0.log = [cost(178, 25000)] }
        set(home.id, "water_tank") { $0.lastDone = ago(170); $0.log = [cost(170, 15000)] }
        set(home.id, "water_filter") { $0.lastDone = ago(84) }
        set(home.id, "water_heater") { $0.lastDone = ago(305) }
        set(home.id, "leaks") { $0.lastDone = ago(100) }
        set(home.id, "seals") { $0.lastDone = ago(122) }
        set(home.id, "smoke") { $0.lastDone = ago(150) }
        set(home.id, "extinguisher") { $0.lastDone = ago(200) }
        set(home.id, "gas_hose") { $0.lastDone = ago(176) }
        set(home.id, "hood") { $0.lastDone = ago(45) }
        set(home.id, "pests") { $0.lastDone = ago(96); $0.log = [cost(96, 12000)] }
        for i in b.state.items.indices where b.state.items[i].asset == chalet.id
            && !["ac_filters", "water_tank", "pests", "roof_drains", "smoke"].contains(b.state.items[i].tpl ?? "") {
            b.state.items[i].enabled = false
        }
        set(chalet.id, "ac_filters") { $0.lastDone = ago(20) }
        set(chalet.id, "water_tank") { $0.lastDone = ago(60) }
        set(chalet.id, "pests") { $0.lastDone = ago(40); $0.log = [cost(40, 10000)] }
        set(chalet.id, "smoke") { $0.lastDone = ago(90) }
        set(car.id, "oil") { $0.lastDone = ago(100); $0.lastKm = 61900; $0.log = [cost(100, 18500, km: 61900)] }
        set(car.id, "air_filter") { $0.lastDone = ago(200); $0.lastKm = 57500 }
        set(car.id, "cabin_filter") { $0.lastDone = ago(190); $0.lastKm = 58000 }
        set(car.id, "car_ac") { $0.lastDone = ago(172) }
        set(car.id, "coolant") { $0.lastDone = ago(165) }
        set(car.id, "tires") { $0.lastDone = ago(160); $0.log = [cost(160, 120000)] }
        set(car.id, "battery") { $0.lastDone = ago(158) }
        set(car.id, "tire_pressure") { $0.lastDone = ago(27) }
        set(car.id, "brake_fluid") { $0.lastDone = ago(400); $0.lastKm = 50000 }
        set(car.id, "registration") { $0.due = today.adding(21).iso }
        set(car.id, "insurance") { $0.due = today.adding(21).iso }
        let boat = b.addThing(type: "boat", name: T("الطراد", "The boat"))
        set(boat.id, "boat_engine") { $0.lastDone = ago(150); $0.log = [cost(150, 45000)] }
        set(boat.id, "boat_hull") { $0.lastDone = ago(70) }
        set(boat.id, "boat_license") { $0.due = today.adding(45).iso }
        b.spreadNew([home.id, chalet.id, car.id, boat.id])
        func sub(_ ar: String, _ en: String, _ amount: Int, _ cycle: String, _ next: Day, _ back: Int, _ category: String, trial: Bool = false) -> Sub {
            Sub(id: newID(), name: T(ar, en), amount: amount, currency: "KWD", cycle: cycle,
                anchor: (back > 0 ? next.addingMonths(-back) : next).iso, category: category, usage: [:], trial: trial ? true : nil)
        }
        b.state.subs = [
            sub("منصة الأفلام", "Movie streaming", 3500, "monthly", today.adding(1), 9, "stream"),
            sub("الموسيقى", "Music", 1990, "monthly", today.adding(12), 9, "music"),
            sub("التخزين السحابي", "Cloud storage", 990, "monthly", today.adding(3), 0, "cloud", trial: true),
            sub("النادي الرياضي", "Gym", 45000, "quarterly", today.adding(40), 9, "gym"),
            sub("إنترنت البيت", "Home internet", 15000, "monthly", today.adding(6), 9, "internet"),
            sub("برنامج التصميم", "Design app", 35000, "yearly", today.adding(64), 12, "apps"),
        ]
        b.state.warranties = [
            Warranty(id: newID(), name: T("الثلاجة", "Fridge"), store: T("معرض الأجهزة", "Appliance store"), bought: ago(300), months: 24),
            Warranty(id: newID(), name: T("مكيف الصالة", "Living room AC"), store: T("وكيل المكيفات", "AC dealer"), bought: today.adding(26).addingMonths(-24).iso, months: 24),
        ]
        b.state.techs = [
            Tech(id: newID(), name: T("أبو محمد", "Abu Mohammed"), trade: "ac", phone: "12345678"),
            Tech(id: newID(), name: T("أبو علي", "Abu Ali"), trade: "plumber", phone: "12345679"),
            Tech(id: newID(), name: T("كراج الشويخ", "Shuwaikh garage"), trade: "mechanic", phone: "12345680"),
        ]
        b.state.docs = [
            Doc(id: newID(), type: "civil_id", who: T("أنا", "Me"), expiry: today.adding(40).iso),
            Doc(id: newID(), type: "passport", who: T("أم محمد", "Umm Mohammed"), expiry: today.adding(120).iso),
            Doc(id: newID(), type: "residency", who: T("السائق", "The driver"), expiry: today.adding(52).iso),
            Doc(id: newID(), type: "health", who: T("السائق", "The driver"), expiry: today.adding(45).iso),
        ]
        return b.state
    }
}
