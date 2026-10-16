// The rest of the web app's features for iPhone: warranties, technicians' numbers, the calendar
// file, the year's spending and the encrypted backup. Same rules as docs/app/app.js and
// docs/app/backup.js, so a backup made on the web opens on iPhone and the other way round.
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif

// MARK: - warranties

public struct WarrantyView: Identifiable, Hashable, Sendable {
    public var id: String { w.id }
    public let w: Warranty
    public let end: Day
    public let status: String
    public let days: Int
}

public extension Brain {
    /// The warranty ends its months after the purchase; the reminder comes a month before.
    func warranties() -> [WarrantyView] {
        state.warranties.compactMap { w -> WarrantyView? in
            guard let bought = Day(iso: w.bought) else { return nil }
            let end = bought.addingMonths(w.months)
            let st = statusOf(end, today: today, lead: 30)
            return WarrantyView(w: w, end: end, status: st.status, days: st.days ?? 0)
        }.sorted { $0.end < $1.end }
    }

    func techFor(_ trade: String?) -> Tech? {
        guard let trade else { return nil }
        return state.techs.first { $0.trade == trade }
    }

    /// The zakat anniversary's next occurrence, or nil when none is set.
    func hawlNext() -> HijriNext? {
        guard let h = state.settings.hawl else { return nil }
        return nextHijriDate(today, h.m, h.d)
    }

    /// Every upcoming date as a calendar event, the same set the web app exports.
    func calendarEvents(_ w: Words) -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        for e in tasks() {
            guard let due = e.due else { continue }
            out.append(CalendarEvent(uid: "\(e.item.id)-\(due.iso)", date: due < today ? today : due,
                                     title: e.title(w.lang) + w.comma + e.asset.name, note: e.tpl?.why(w.lang),
                                     lead: e.every.fixed == true ? 7 : e.status == "ok" ? 3 : 0))
        }
        for s in subs() where s.sub.cancelled != true {
            out.append(CalendarEvent(uid: "sub-\(s.sub.id)-\(s.next.iso)", date: s.next,
                                     title: w.t("ics.sub", ["name": s.sub.name, "amount": w.money(s.sub.amount, s.sub.currency)]), lead: s.days > 3 ? 3 : 0))
        }
        for x in warranties() where x.end >= today {
            out.append(CalendarEvent(uid: "w-\(x.w.id)", date: x.end, title: w.t("ics.warranty", ["name": x.w.name]), lead: x.days > 14 ? 14 : 0))
        }
        for x in docs() {
            guard let end = Day(iso: x.d.expiry), end >= today else { continue }
            out.append(CalendarEvent(uid: "d-\(x.d.id)", date: end, title: w.t("ics.doc", ["name": docTitle(x.d, lang: w.lang)]), lead: min(x.type.lead, max(0, x.days))))
        }
        if let h = hawlNext() {
            out.append(CalendarEvent(uid: "hawl-\(h.date.iso)", date: h.date, title: w.t("hawl.head"), lead: h.days > 7 ? 7 : 0))
        }
        return out
    }

    /// What a year cost: the costs logged when tasks were done, and subscription charges up to today.
    func spend(year: Int, lang: String) -> SpendReport {
        let from = Day(y: year, m: 1, d: 1)
        let to = Day(y: year, m: 12, d: 31)
        let upto = to < today ? to : today
        var order: [String] = []
        var sums: [String: [Int]] = [:] // home, car, things, subs, projected
        func add(_ cur: String, _ i: Int, _ v: Int) {
            if sums[cur] == nil { sums[cur] = [0, 0, 0, 0, 0]; order.append(cur) }
            sums[cur]![i] += v
        }
        var logs: [SpendLog] = []
        for it in state.items {
            for l in it.log ?? [] {
                guard let cost = l.cost, let d = Day(iso: l.date), d >= from, d <= to else { continue }
                let a = asset(it.asset)
                let cur = l.cur ?? state.settings.currency
                add(cur, a?.kind == .car ? 1 : a?.kind == .thing ? 2 : 0, cost)
                logs.append(SpendLog(date: d, cost: cost, currency: cur, title: it.tpl.flatMap { catalog.template[$0]?.name(lang) } ?? it.title ?? "", asset: a?.name))
            }
        }
        for s in state.subs {
            guard let anchor = Day(iso: s.anchor), let cycle = Cycle(rawValue: s.cycle) else { continue }
            let stop = s.cancelled == true ? s.cancelledOn.flatMap { Day(iso: $0) } : nil
            let n = chargesBetween(anchor: anchor, cycle: cycle, from: from, to: stop.map { $0 < upto ? $0 : upto } ?? upto)
            let all = chargesBetween(anchor: anchor, cycle: cycle, from: from, to: stop.map { $0 < to ? $0 : to } ?? to)
            add(s.currency, 3, n * s.amount)
            sums[s.currency]![4] += all * s.amount
        }
        return SpendReport(year: year, blocks: order.map { cur in
            let v = sums[cur]!
            return SpendBlock(currency: cur, home: v[0], car: v[1], things: v[2], subs: v[3], projected: v[4])
        }, logs: logs.sorted { $0.date > $1.date })
    }
}

public struct SpendBlock: Hashable, Sendable, Identifiable {
    public var id: String { currency }
    public let currency: String
    public let home: Int, car: Int, things: Int, subs: Int, projected: Int
    public var total: Int { home + car + things + subs }
}

public struct SpendLog: Hashable, Sendable {
    public let date: Day
    public let cost: Int
    public let currency: String
    public let title: String
    public let asset: String?
}

public struct SpendReport: Sendable {
    public let year: Int
    public let blocks: [SpendBlock]
    public let logs: [SpendLog]
}

// MARK: - technicians

/// A local number becomes international with the dialling code of the chosen country.
public func phoneDigits(_ phone: String, country: String) -> String {
    var d = normalizeDigits(phone).filter { ("0"..."9").contains($0) || $0 == "+" }
    if d.hasPrefix("+") { return String(d.dropFirst()) }
    if d.hasPrefix("00") { return String(d.dropFirst(2)) }
    while d.hasPrefix("0") { d.removeFirst() }
    let c = Brain.countries[country] ?? Brain.countries["KW"]!
    return d.count == c.len ? c.cc + d : d
}

/// "20260925T090000Z" for the calendar file's time stamp, in UTC.
public func utcStamp(_ date: Date = Date()) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    func p(_ n: Int?) -> String { let v = n ?? 0; return v < 10 ? "0\(v)" : "\(v)" }
    return "\(c.year ?? 1970)\(p(c.month))\(p(c.day))T\(p(c.hour))\(p(c.minute))\(p(c.second))Z"
}

// MARK: - backup

public enum BackupError: Error, Equatable {
    case format
    case pass
}

#if canImport(CryptoKit) && canImport(CommonCrypto)
/// The web app's backup file: PBKDF2 with SHA-256 over 600,000 rounds, then AES-256-GCM.
public enum Backup {
    public static let iterations = 600_000

    static func key(_ pass: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let passData = Array(pass.utf8)
        if passData.isEmpty { throw BackupError.pass }
        var out = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { s in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pass, passData.count, s.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations), &out, out.count)
        }
        guard status == kCCSuccess else { throw BackupError.format }
        return SymmetricKey(data: out)
    }

    public static func encrypt(_ payload: Data, pass: String, iterations: Int = iterations) throws -> Data {
        var salt = Data(count: 16)
        var iv = Data(count: 12)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        _ = iv.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!) }
        let sealed = try AES.GCM.seal(payload, using: try key(pass, salt: salt, iterations: iterations), nonce: try AES.GCM.Nonce(data: iv))
        let file: [String: Any] = [
            "app": "nokhatha", "format": 1, "kdf": "PBKDF2-SHA256", "iterations": iterations, "cipher": "AES-256-GCM",
            "salt": salt.base64EncodedString(), "iv": iv.base64EncodedString(), "data": (sealed.ciphertext + sealed.tag).base64EncodedString(),
        ]
        return try JSONSerialization.data(withJSONObject: file)
    }

    /// The payload, or BackupError.format for a foreign file and BackupError.pass for a wrong password.
    public static func decrypt(_ file: Data, pass: String) throws -> Data {
        guard let f = try? JSONSerialization.jsonObject(with: file) as? [String: Any], f["app"] as? String == "nokhatha", f["format"] as? Int == 1,
              let salt = (f["salt"] as? String).flatMap({ Data(base64Encoded: $0) }), let iv = (f["iv"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let data = (f["data"] as? String).flatMap({ Data(base64Encoded: $0) }), data.count > 16, iv.count == 12
        else { throw BackupError.format }
        let k = try key(pass, salt: salt, iterations: f["iterations"] as? Int ?? iterations)
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: data.dropLast(16), tag: data.suffix(16))
            return try AES.GCM.open(box, using: k)
        } catch {
            throw BackupError.pass
        }
    }
}
#endif

// MARK: - documents

public struct DocView: Identifiable, Hashable, Sendable {
    public var id: String { d.id }
    public let d: Doc
    public let type: DocType
    public let status: String
    public let days: Int
    public let needType: DocType?
    public let need: DocViewNeed?
}

/// The document needed first, judged on its own.
public struct DocViewNeed: Hashable, Sendable {
    public let status: String
    public let days: Int
}

public extension Brain {
    func docTitle(_ d: Doc, lang: String) -> String {
        d.name ?? (catalog.docType[d.type] ?? catalog.docType["other"]!).name(lang, country: state.settings.country)
    }

    /// A document judged by its own lead time, with the document it needs first for the same person.
    func evalDoc(_ d: Doc) -> DocView {
        let type = catalog.docType[d.type] ?? catalog.docType["other"]!
        let st = statusOf(Day(iso: d.expiry), today: today, lead: type.lead)
        let needType = type.needs.flatMap { catalog.docType[$0] }
        var need: DocViewNeed? = nil
        if let needType, let n = state.docs.first(where: { $0.type == needType.id && ($0.who ?? "") == (d.who ?? "") }) {
            let ns = statusOf(Day(iso: n.expiry), today: today, lead: needType.lead)
            need = DocViewNeed(status: ns.status, days: ns.days ?? 0)
        }
        return DocView(d: d, type: type, status: st.status, days: st.days ?? 0, needType: needType, need: need)
    }

    func docs() -> [DocView] { state.docs.map(evalDoc).sorted { $0.d.expiry < $1.d.expiry } }

    mutating func saveDoc(_ doc: Doc) {
        if let i = state.docs.firstIndex(where: { $0.id == doc.id }) { state.docs[i] = doc } else { state.docs.append(doc) }
    }

    mutating func deleteDoc(_ id: String) { state.docs.removeAll { $0.id == id } }

    /// Renewed for its usual term, counted from the old date when that is still ahead.
    @discardableResult
    mutating func renewDoc(_ id: String) -> Doc? {
        guard let i = state.docs.firstIndex(where: { $0.id == id }) else { return nil }
        let type = catalog.docType[state.docs[i].type] ?? catalog.docType["other"]!
        let old = Day(iso: state.docs[i].expiry) ?? today
        state.docs[i].expiry = (old >= today ? old : today).addingMonths(12 * type.years).iso
        return state.docs[i]
    }

    // MARK: registration renewal

    /// The renewal path shows once the registration is due within its lead or a step has been ticked.
    func renewalShown(_ carId: String) -> Bool {
        guard let reg = tasks({ $0.asset == carId && $0.tpl == "registration" }).first, let car = state.cars.first(where: { $0.id == carId }) else { return false }
        return ["overdue", "today", "soon"].contains(reg.status) || !(car.renewal?.done.isEmpty ?? true)
    }

    mutating func setRenewStep(_ carId: String, _ step: String, on: Bool) {
        guard let i = state.cars.firstIndex(where: { $0.id == carId }), let plan = catalog.renewPlan(state.settings.country) else { return }
        var r = state.cars[i].renewal ?? Renewal(years: plan.years.first)
        r.done = on ? Array(Set(r.done + [step])).sorted { a, b in plan.steps.firstIndex { $0.id == a } ?? 0 < plan.steps.firstIndex { $0.id == b } ?? 0 } : r.done.filter { $0 != step }
        state.cars[i].renewal = r
    }

    mutating func setRenewYears(_ carId: String, _ years: Int) {
        guard let i = state.cars.firstIndex(where: { $0.id == carId }) else { return }
        var r = state.cars[i].renewal ?? Renewal()
        r.years = years
        state.cars[i].renewal = r
    }

    /// The registration renewed: registration and insurance move on by the chosen years, the inspection by a year.
    mutating func finishRenewal(_ carId: String) {
        guard let ci = state.cars.firstIndex(where: { $0.id == carId }) else { return }
        let years = state.cars[ci].renewal?.years ?? 1
        for (tpl, months) in [("registration", 12 * years), ("insurance", 12 * years), ("inspection", 12)] {
            guard let i = state.items.firstIndex(where: { $0.asset == carId && $0.tpl == tpl && $0.isOn }) else { continue }
            let due = state.items[i].due.flatMap { Day(iso: $0) }
            let base = (due != nil && due! >= today) ? due! : today
            state.items[i].due = base.addingMonths(months).iso
            state.items[i].lastDone = today.iso
            state.items[i].log = (state.items[i].log ?? []) + [LogEntry(date: today.iso)]
        }
        state.cars[ci].renewal = nil
    }
}

// MARK: - Ramadan

public extension Brain {
    /// The Ramadan the checklist is for: the one running, or the next one.
    func ramadanYear() -> Int {
        let ev = nextHijriEvent(today)
        if ev.id == "ramadan" { return ev.year }
        let h = toHijri(today)
        return h.m > 9 ? h.y + 1 : h.y
    }

    /// The ticks for that Ramadan; an older year's ticks are forgotten.
    func ramadanDone() -> [String] { state.ramadan.year == ramadanYear() ? state.ramadan.done : [] }

    mutating func setRamadan(_ id: String, on: Bool) {
        var done = Set(ramadanDone())
        if on { done.insert(id) } else { done.remove(id) }
        state.ramadan = RamadanState(year: ramadanYear(), done: catalog.ramadan.map(\.id).filter { done.contains($0) })
    }

    mutating func resetRamadan() { state.ramadan = RamadanState(year: ramadanYear(), done: []) }
}

// MARK: - the week's digest

public extension Brain {
    /// The week ahead as one message for the household: overdue, due within seven days, renewals and documents.
    func weekText(_ w: Words) -> String {
        let end = today.adding(7)
        let sep = w.isArabic ? "، " : ", "
        var lines = [w.t("week.title"), w.t("week.head", ["from": w.date(today, today: today), "to": w.date(end, today: today)]), ""]
        let evs = tasks().filter { $0.due != nil }
        let overdue = evs.filter { $0.status == "overdue" }
        let soon = evs.filter { $0.status != "overdue" && $0.due! <= end }.sorted { $0.due! < $1.due! }
        func line(_ e: Evaluated) -> String { "• \(e.title(w.lang)) (\(e.asset.name))\(sep)\(e.status == "overdue" ? w.rel(e.days ?? 0) : w.date(e.due!, today: today))" }
        if !overdue.isEmpty { lines.append(w.t("week.overdue") + ":"); lines += overdue.map(line); lines.append("") }
        if !soon.isEmpty { lines += soon.map(line); lines.append("") }
        let subs = subs().filter { $0.sub.cancelled != true && $0.next <= end }
        if !subs.isEmpty { lines.append(w.t("week.subs") + ":"); lines += subs.map { "• \($0.sub.name)\(sep)\(w.money($0.sub.amount, $0.sub.currency))\(sep)\(w.date($0.next, today: today))" }; lines.append("") }
        let docs = docs().filter { $0.status != "ok" }
        if !docs.isEmpty { lines.append(w.t("week.docs") + ":"); lines += docs.map { x in "• \(docTitle(x.d, lang: w.lang))\(x.d.who.map { " (\($0))" } ?? "")\(sep)\(Day(iso: x.d.expiry).map { w.date($0, today: today) } ?? x.d.expiry)" }; lines.append("") }
        let hawl = hawlNext().flatMap { $0.date <= end ? $0 : nil }
        if let hawl { lines.append("• \(w.t("week.hawl"))\(sep)\(w.date(hawl.date, today: today))"); lines.append("") }
        if overdue.isEmpty && soon.isEmpty && subs.isEmpty && docs.isEmpty && hawl == nil { lines.append(w.t("week.none")); lines.append("") }
        lines.append(w.t("week.foot"))
        return lines.joined(separator: "\n")
    }
}

// MARK: - tires

/// Tire age from the last four DOT digits: the week they were made, full months since, and ok / soon (four years) / overdue (five).
public struct TireAge: Hashable, Sendable {
    public let made: Day
    public let months: Int
    public let status: String
}

public func tireAge(_ dot: String?, _ today: Day) -> TireAge? {
    let chars = Array((dot ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    guard chars.count >= 4 else { return nil }
    let tail = chars.suffix(4)
    guard tail.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
    if chars.count > 4, let before = chars.dropLast(4).last, before.isASCII, before.isNumber { return nil }
    let digits = tail.map { Int(String($0))! }
    let week = digits[0] * 10 + digits[1]
    guard week >= 1, week <= 53 else { return nil }
    let made = Day(y: 2000 + digits[2] * 10 + digits[3], m: 1, d: 1).adding((week - 1) * 7)
    if made > today { return nil }
    let a = made.ymd, b = today.ymd
    let months = (b.y - a.y) * 12 + (b.m - a.m) - (b.d < a.d ? 1 : 0)
    return TireAge(made: made, months: months, status: months >= 60 ? "overdue" : months >= 48 ? "soon" : "ok")
}

/// An age in full months as words: years and months in the Kuwaiti count, "under a month" below one.
public func ageText(_ months: Int, _ lang: String) -> String {
    let y = months / 12
    let m = months % 12
    func unit(_ n: Int, _ u: String) -> String { lang == "ar" ? countAr(n, u) : "\(n) \(u)\(n == 1 ? "" : "s")" }
    if y == 0 && m == 0 { return lang == "ar" ? "أقل من شهر" : "under a month" }
    if y > 0 && m > 0 { return lang == "ar" ? "\(unit(y, "year")) و\(unit(m, "month"))" : "\(unit(y, "year")) and \(unit(m, "month"))" }
    return y > 0 ? unit(y, "year") : unit(m, "month")
}

// MARK: - bills

/// The logged cost of a template's task per month of a year: twelve sums in minor units, nil where nothing was logged.
public func monthlyCosts(_ items: [Item], tpl: String, year: Int, currency: String) -> [Int?] {
    var out = [Int?](repeating: nil, count: 12)
    for it in items where it.tpl == tpl {
        for l in it.log ?? [] {
            guard let cost = l.cost, l.cur == nil || l.cur == currency, let d = Day(iso: l.date) else { continue }
            let p = d.ymd
            if p.y != year { continue }
            out[p.m - 1] = (out[p.m - 1] ?? 0) + cost
        }
    }
    return out
}
