// NokhathaKit: the Nokhatha engine for iPhone.
// A line for line port of docs/engine/nokhatha.js. tests/vectors.json is the contract
// both must satisfy, so every date and every amount comes out the same on web and iPhone.
//
//   * Dates are whole day numbers on the civil calendar, no time zones, no floating point.
//   * Money is integer minor units (fils for KWD).
//   * Every function is pure and takes "today" as an argument.

import Foundation

public enum Engine {
    public static let seasonalMinGap = 60
    public static let seasonalGrace = 60
    public static let defaultDailyKm = 40
}

// MARK: - Integer division, identical to the JS helpers

@inlinable func floorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q
}

@inlinable func ceilDiv(_ a: Int, _ b: Int) -> Int { -floorDiv(-a, b) }

/// Round half up for non negative numerators.
@inlinable func roundDiv(_ a: Int, _ b: Int) -> Int { floorDiv(2 * a + b, 2 * b) }

// MARK: - Days

/// A civil date as days since 1970-01-01 (proleptic Gregorian).
public struct Day: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let n: Int

    public init(_ n: Int) { self.n = n }

    public init(y: Int, m: Int, d: Int) { n = Day.number(y, m, d) }

    public init?(iso: String) {
        guard let p = Day.parse(iso) else { return nil }
        self.init(y: p.y, m: p.m, d: p.d)
    }

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = Day(iso: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad date \(s)"))
        }
        self = d
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso)
    }

    public static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    public static func daysInMonth(_ y: Int, _ m: Int) -> Int {
        [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
    }

    static func parse(_ s: String) -> (y: Int, m: Int, d: Int)? {
        let u = Array(s.utf8)
        guard u.count == 10, u[4] == 45, u[7] == 45 else { return nil }
        func num(_ r: Range<Int>) -> Int? {
            var v = 0
            for i in r {
                let c = u[i]
                guard c >= 48 && c <= 57 else { return nil }
                v = v * 10 + Int(c - 48)
            }
            return v
        }
        guard let y = num(0..<4), let m = num(5..<7), let d = num(8..<10),
              m >= 1, m <= 12, d >= 1, d <= daysInMonth(y, m) else { return nil }
        return (y, m, d)
    }

    static func number(_ year: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? year - 1 : year
        let era = floorDiv(y, 400)
        let yoe = y - era * 400
        let mp = (m + 9) % 12
        let doy = floorDiv(153 * mp + 2, 5) + d - 1
        let doe = yoe * 365 + floorDiv(yoe, 4) - floorDiv(yoe, 100) + doy
        return era * 146097 + doe - 719468
    }

    public var ymd: (y: Int, m: Int, d: Int) {
        let z = n + 719468
        let era = floorDiv(z, 146097)
        let doe = z - era * 146097
        let yoe = floorDiv(doe - floorDiv(doe, 1460) + floorDiv(doe, 36524) - floorDiv(doe, 146096), 365)
        let doy = doe - (365 * yoe + floorDiv(yoe, 4) - floorDiv(yoe, 100))
        let mp = floorDiv(5 * doy + 2, 153)
        let d = doy - floorDiv(153 * mp + 2, 5) + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }

    public var iso: String {
        let p = ymd
        return String(format: "%04d-%02d-%02d", p.y, p.m, p.d)
    }

    public var description: String { iso }

    public func adding(_ days: Int) -> Day { Day(n + days) }

    /// Calendar months, clamped to the last day of the target month.
    public func addingMonths(_ k: Int) -> Day {
        let p = ymd
        let t = p.y * 12 + (p.m - 1) + k
        let ny = floorDiv(t, 12)
        let nm = t - ny * 12 + 1
        return Day(y: ny, m: nm, d: min(p.d, Day.daysInMonth(ny, nm)))
    }

    /// 0 is Sunday, 6 is Saturday.
    public var weekday: Int { ((n % 7) + 7 + 4) % 7 }

    /// "MM-DD", used for windows such as the Bawarih.
    var monthDay: String { String(iso.suffix(5)) }

    public static func < (a: Day, b: Day) -> Bool { a.n < b.n }

    /// Days from b to a.
    public static func - (a: Day, b: Day) -> Int { a.n - b.n }

    /// Today on the device's own calendar.
    public static func today(calendar: Calendar = .current, now: Date = Date()) -> Day {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return Day(y: c.year!, m: c.month!, d: c.day!)
    }
}

public func isISO(_ s: String) -> Bool { Day.parse(s) != nil }

/// b minus a, in days.
public func diffDays(_ a: Day, _ b: Day) -> Int { b.n - a.n }

// MARK: - Seasons

public struct Season: Codable, Hashable, Sendable {
    public let id: String
    public let start: String
    public let group: String
    public let ar: String
    public let en: String
    public let note_ar: String?
    public let note_en: String?
    public let hint_ar: String?
    public let hint_en: String?

    public func name(_ lang: String) -> String { lang == "ar" ? ar : en }
    public func hint(_ lang: String) -> String? { lang == "ar" ? hint_ar : hint_en }
    public func hint(_ lang: String) -> String? { lang == "ar" ? hint_ar : hint_en }
    public func hint(_ lang: String) -> String? { lang == "ar" ? hint_ar : hint_en }
}

/// A month-day range such as the Bawarih winds, {start: "06-07", end: "07-28"}.
public struct Window: Codable, Hashable, Sendable {
    public let start: String
    public let end: String
    public init(start: String, end: String) { self.start = start; self.end = end }
}

func startIn(_ s: Season, _ year: Int) -> Day {
    let p = s.start.split(separator: "-")
    return Day(y: year, m: Int(p[0])!, d: Int(p[1])!)
}

struct SeasonStart { let i: Int; let date: Day }

func startsAround(_ day: Day, _ seasons: [Season]) -> [SeasonStart] {
    let y = day.ymd.y
    var out: [SeasonStart] = []
    for yy in (y - 1)...(y + 2) {
        for (i, s) in seasons.enumerated() { out.append(SeasonStart(i: i, date: startIn(s, yy))) }
    }
    return out.sorted { $0.date < $1.date }
}

func currentIndex(_ list: [SeasonStart], _ day: Day) -> Int {
    var k = -1
    for (j, x) in list.enumerated() where x.date <= day { k = j }
    return k
}

public struct SeasonInfo: Hashable, Sendable {
    public let id: String
    public let index: Int
    public let start: Day
    public let next: Day
    public let nextId: String
    public let length: Int
    public let dayIn: Int
    public let daysLeft: Int
}

/// The Gulf season a date falls in.
public func seasonAt(_ day: Day, _ seasons: [Season]) -> SeasonInfo {
    let list = startsAround(day, seasons)
    let k = currentIndex(list, day)
    let cur = list[k], nxt = list[k + 1]
    return SeasonInfo(
        id: seasons[cur.i].id, index: cur.i, start: cur.date, next: nxt.date, nextId: seasons[nxt.i].id,
        length: diffDays(cur.date, nxt.date), dayIn: diffDays(cur.date, day) + 1, daysLeft: diffDays(day, nxt.date))
}

public struct RingSegment: Hashable, Sendable {
    public let id: String
    public let start: Day
    /// Start of the segment relative to the day asked about.
    public let offset: Int
    public let length: Int
}

/// One full turn of the calendar starting with the season that contains the day.
public func seasonRing(_ day: Day, _ seasons: [Season]) -> (total: Int, segs: [RingSegment]) {
    let list = startsAround(day, seasons)
    let k = currentIndex(list, day)
    var segs: [RingSegment] = []
    for j in 0..<seasons.count {
        let a = list[k + j], b = list[k + j + 1]
        segs.append(RingSegment(id: seasons[a.i].id, start: a.date, offset: diffDays(day, a.date), length: diffDays(a.date, b.date)))
    }
    return (segs.reduce(0) { $0 + $1.length }, segs)
}

public func seasonStartOnOrAfter(_ day: Day, _ id: String, _ seasons: [Season]) -> Day? {
    guard let s = seasons.first(where: { $0.id == id }) else { return nil }
    let y = day.ymd.y
    for yy in (y - 1)...(y + 2) {
        let d = startIn(s, yy)
        if d >= day { return d }
    }
    return nil
}

public func inWindow(_ day: Day, _ w: Window) -> Bool {
    let md = day.monthDay
    return w.start <= w.end ? (md >= w.start && md <= w.end) : (md >= w.start || md <= w.end)
}

func anchors(_ id: String, _ offset: Int, _ y0: Int, _ y1: Int, _ seasons: [Season]) -> [Day] {
    guard let s = seasons.first(where: { $0.id == id }) else { return [] }
    return (y0...y1).map { startIn(s, $0).adding(offset) }
}

/// Next due date of a yearly task pinned to a season (for example 21 days before Al-Wasm).
public func seasonalDue(lastDone: Day?, season: String, offset: Int, today: Day, seasons: [Season]) -> Day? {
    if let last = lastDone {
        let th = last.adding(Engine.seasonalMinGap)
        let y = th.ymd.y
        return anchors(season, offset, y - 1, y + 2, seasons).first { $0 >= th }
    }
    let y = today.ymd.y
    let all = anchors(season, offset, y - 1, y + 2, seasons)
    if let prev = all.filter({ $0 <= today }).last, diffDays(prev, today) <= Engine.seasonalGrace { return prev }
    return all.first { $0 > today }
}

// MARK: - Odometer

public struct Reading: Codable, Hashable, Sendable {
    public var date: String
    public var km: Int
    public init(date: String, km: Int) { self.date = date; self.km = km }
}

public struct CarOdometer: Codable, Hashable, Sendable {
    public var dailyKm: Int
    public var readings: [Reading]
    public init(dailyKm: Int, readings: [Reading]) { self.dailyKm = dailyKm; self.readings = readings }
}

func sortedReadings(_ car: CarOdometer) -> [(day: Day, km: Int)] {
    car.readings.compactMap { r in Day(iso: r.date).map { ($0, r.km) } }.sorted { $0.day < $1.day }
}

public func lastReading(_ car: CarOdometer) -> Reading? {
    guard let l = sortedReadings(car).last else { return nil }
    return Reading(date: l.day.iso, km: l.km)
}

/// Kilometres per day as an exact fraction. Uses the earliest reading within 180 days
/// of the latest one, spanning at least 14 days, otherwise the daily estimate.
public func kmRate(_ car: CarOdometer) -> (num: Int, den: Int) {
    let r = sortedReadings(car)
    if r.count >= 2 {
        let last = r[r.count - 1]
        let from = last.day.adding(-180)
        let early = r.first(where: { $0.day >= from && $0.day < last.day }) ?? r[0]
        let span = diffDays(early.day, last.day)
        let dist = last.km - early.km
        if span >= 14 && dist > 0 { return (dist, span) }
    }
    return (car.dailyKm > 0 ? car.dailyKm : Engine.defaultDailyKm, 1)
}

/// The date the odometer is expected to reach the target, rounded up so a reminder is never late.
public func dateAtKm(_ car: CarOdometer, _ target: Int) -> Day? {
    guard let last = sortedReadings(car).last else { return nil }
    let rate = kmRate(car)
    return last.day.adding(ceilDiv((target - last.km) * rate.den, rate.num))
}

/// Estimated odometer on a date.
public func kmOn(_ car: CarOdometer, _ day: Day) -> Int? {
    guard let last = sortedReadings(car).last else { return nil }
    let d = diffDays(last.day, day)
    if d <= 0 { return last.km }
    let rate = kmRate(car)
    return last.km + floorDiv(d * rate.num, rate.den)
}

// MARK: - Schedules

public struct Every: Codable, Hashable, Sendable {
    public var days: Int?
    public var months: Int?
    public var km: Int?
    public var bawarih: Int?
    public var season: String?
    public var offset: Int?
    public var fixed: Bool?
    public var lead: Int?
    public var repeatMonths: Int?

    enum CodingKeys: String, CodingKey {
        case days, months, km, bawarih, season, offset, fixed, lead
        case repeatMonths = "repeat"
    }

    public init(days: Int? = nil, months: Int? = nil, km: Int? = nil, bawarih: Int? = nil, season: String? = nil,
                offset: Int? = nil, fixed: Bool? = nil, lead: Int? = nil, repeatMonths: Int? = nil) {
        self.days = days; self.months = months; self.km = km; self.bawarih = bawarih; self.season = season
        self.offset = offset; self.fixed = fixed; self.lead = lead; self.repeatMonths = repeatMonths
    }
}

public struct DueInput: Sendable {
    public var every: Every
    public var lastDone: Day?
    public var lastKm: Int?
    public var due: Day?
    public var snoozeUntil: Day?
    public var firstDue: Day?

    public init(every: Every, lastDone: Day? = nil, lastKm: Int? = nil, due: Day? = nil, snoozeUntil: Day? = nil, firstDue: Day? = nil) {
        self.every = every; self.lastDone = lastDone; self.lastKm = lastKm; self.due = due
        self.snoozeUntil = snoozeUntil; self.firstDue = firstDue
    }
}

public struct Due: Hashable, Sendable {
    public var due: Day?
    /// time, km, season, fixed, new, unset or snooze
    public var by: String
}

/// JS truthiness for optional numbers: absent and zero both mean "not set".
@inline(__always) func set(_ v: Int?) -> Int? { (v ?? 0) != 0 ? v : nil }

public func nextDue(_ item: DueInput, today: Day, seasons: [Season], bawarih: Window?, car: CarOdometer?) -> Due {
    let s = item.every
    var res: Due
    if s.fixed == true {
        res = item.due != nil ? Due(due: item.due, by: "fixed") : Due(due: nil, by: "unset")
    } else if let season = s.season, !season.isEmpty {
        res = Due(due: seasonalDue(lastDone: item.lastDone, season: season, offset: s.offset ?? 0, today: today, seasons: seasons), by: "season")
    } else {
        var due: Day?
        var by = "time"
        if let last = item.lastDone {
            if let m = set(s.months) { due = last.addingMonths(m) }
            if var n = set(s.days) {
                if let b = set(s.bawarih), let w = bawarih, inWindow(last, w) { n = b }
                let t = last.adding(n)
                due = due.map { min($0, t) } ?? t
            }
        } else {
            // never logged: due on its planned first date, or today when there is none
            due = item.firstDue ?? today
            by = "new"
        }
        if let km = set(s.km), let car, let lastKm = item.lastKm, let kd = dateAtKm(car, lastKm + km), due == nil || kd < due! {
            due = kd
            by = "km"
        }
        res = Due(due: due, by: by)
    }
    if let sn = item.snoozeUntil, let d = res.due, sn > d { res = Due(due: sn, by: "snooze") }
    return res
}

/// overdue, today, soon, ok or unset
public func statusOf(_ due: Day?, today: Day, lead: Int) -> (status: String, days: Int?) {
    guard let due else { return ("unset", nil) }
    let days = diffDays(today, due)
    return (days < 0 ? "overdue" : days == 0 ? "today" : days <= lead ? "soon" : "ok", days)
}

/// Share of the current cycle already used, 0 to 1. For display only.
public func cycleProgress(lastDone: Day?, due: Day?, today: Day) -> Double {
    guard let lastDone, let due else { return 0 }
    let total = diffDays(lastDone, due)
    if total <= 0 { return 1 }
    return max(0, min(1, Double(diffDays(lastDone, today)) / Double(total)))
}

// MARK: - Subscriptions

public enum Cycle: String, Codable, CaseIterable, Sendable {
    case weekly, monthly, quarterly, semiannual, yearly

    var months: Int {
        switch self {
        case .weekly: return 0
        case .monthly: return 1
        case .quarterly: return 3
        case .semiannual: return 6
        case .yearly: return 12
        }
    }
}

/// Renewals are computed from the anchor, never chained, so a subscription on the 31st
/// returns to the 31st after February.
public func nthRenewal(_ anchor: Day, _ cycle: Cycle, _ n: Int) -> Day {
    cycle == .weekly ? anchor.adding(7 * n) : anchor.addingMonths(cycle.months * n)
}

public func nextRenewal(anchor: Day, cycle: Cycle, today: Day) -> Day {
    if anchor >= today { return anchor }
    let gap = diffDays(anchor, today)
    var n = max(0, (cycle == .weekly ? floorDiv(gap, 7) : floorDiv(gap, cycle.months * 31)) - 1)
    while nthRenewal(anchor, cycle, n) < today { n += 1 }
    return nthRenewal(anchor, cycle, n)
}

/// Charges falling in [from, to], counting from the anchor.
public func chargesBetween(anchor: Day, cycle: Cycle, from: Day, to: Day) -> Int {
    var n = 0, count = 0
    while true {
        let d = nthRenewal(anchor, cycle, n)
        if d > to { break }
        if d >= from { count += 1 }
        n += 1
        if n > 2000 { break }
    }
    return count
}

public func perMonth(_ minor: Int, _ cycle: Cycle) -> Int {
    switch cycle {
    case .weekly: return roundDiv(minor * 52, 12)
    case .monthly: return minor
    case .quarterly: return roundDiv(minor, 3)
    case .semiannual: return roundDiv(minor, 6)
    case .yearly: return roundDiv(minor, 12)
    }
}

public func perYear(_ minor: Int, _ cycle: Cycle) -> Int {
    switch cycle {
    case .weekly: return minor * 52
    case .monthly: return minor * 12
    case .quarterly: return minor * 4
    case .semiannual: return minor * 2
    case .yearly: return minor
    }
}

public struct SubAmount: Sendable {
    public var amount: Int
    public var currency: String
    public var cycle: Cycle
    public var cancelled: Bool
    public init(amount: Int, currency: String, cycle: Cycle, cancelled: Bool = false) {
        self.amount = amount; self.currency = currency; self.cycle = cycle; self.cancelled = cancelled
    }
}

public struct SubTotal: Hashable, Sendable {
    public var month = 0
    public var year = 0
    public var count = 0
}

/// Totals per currency for subscriptions that are not cancelled.
public func subTotals(_ subs: [SubAmount]) -> [String: SubTotal] {
    var out: [String: SubTotal] = [:]
    for s in subs where !s.cancelled {
        var t = out[s.currency] ?? SubTotal()
        t.month += perMonth(s.amount, s.cycle)
        t.year += perYear(s.amount, s.cycle)
        t.count += 1
        out[s.currency] = t
    }
    return out
}

// MARK: - Money

public struct CurrencyInfo: Sendable {
    public let digits: Int
    public let ar: String
}

public let currencies: [String: CurrencyInfo] = [
    "KWD": CurrencyInfo(digits: 3, ar: "د.ك"),
    "SAR": CurrencyInfo(digits: 2, ar: "ر.س"),
    "AED": CurrencyInfo(digits: 2, ar: "د.إ"),
    "QAR": CurrencyInfo(digits: 2, ar: "ر.ق"),
    "BHD": CurrencyInfo(digits: 3, ar: "د.ب"),
    "OMR": CurrencyInfo(digits: 3, ar: "ر.ع"),
    "USD": CurrencyInfo(digits: 2, ar: "دولار"),
]

func pow10(_ k: Int) -> Int { (0..<k).reduce(1) { acc, _ in acc * 10 } }

func groupThousands(_ s: String) -> String {
    var out = ""
    let chars = Array(s)
    for (i, ch) in chars.enumerated() {
        if i > 0 && (chars.count - i) % 3 == 0 { out.append(",") }
        out.append(ch)
    }
    return out
}

/// "4.500 د.ك" in Arabic, "KWD 4.500" in English.
public func formatMoney(_ minor: Int, _ code: String, _ lang: String) -> String {
    guard let c = currencies[code] else { return "" }
    let a = abs(minor)
    let p = pow10(c.digits)
    var frac = String(a % p)
    while frac.count < c.digits { frac = "0" + frac }
    let num = (minor < 0 ? "-" : "") + groupThousands(String(floorDiv(a, p))) + "." + frac
    return lang == "ar" ? "\(num) \(c.ar)" : "\(code) \(num)"
}

/// Arabic Indic and Persian digits, Arabic decimal and thousands marks, to ASCII.
public func normalizeDigits(_ s: String) -> String {
    var out = String.UnicodeScalarView()
    for u in s.unicodeScalars {
        switch u.value {
        case 0x0660...0x0669: out.append(Unicode.Scalar(u.value - 0x0660 + 48)!)
        case 0x06F0...0x06F9: out.append(Unicode.Scalar(u.value - 0x06F0 + 48)!)
        case 0x066B: out.append(".")
        case 0x066C: out.append(",")
        default: out.append(u)
        }
    }
    return String(out)
}

/// Reads what a person types ("4.5", "٤٫٥٠٠", "2,5", "1,500 SAR") into minor units.
/// A single comma is a decimal mark when the digits after it fit the currency,
/// otherwise commas are thousands marks. Extra decimals are rounded half up.
public func parseMoney(_ text: String, _ code: String) -> Int? {
    guard let c = currencies[code] else { return nil }
    let norm = normalizeDigits(text)
    guard let re = try? NSRegularExpression(pattern: "[0-9.,]*[0-9]"),
          let m = re.firstMatch(in: norm, range: NSRange(norm.startIndex..., in: norm)),
          let r = Range(m.range, in: norm) else { return nil }
    var s = String(norm[r])
    if s.hasPrefix(".") || s.hasPrefix(",") { s = "0" + s }
    if s.contains(".") && s.contains(",") {
        s = s.replacingOccurrences(of: ",", with: "")
    } else if s.contains(",") {
        let parts = s.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        s = parts.count == 2 && parts[1].count <= c.digits ? parts[0] + "." + parts[1] : parts.joined()
    }
    guard s.range(of: "^[0-9]+(\\.[0-9]+)?$", options: .regularExpression) != nil else { return nil }
    let comps = s.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    var fp = comps.count > 1 ? comps[1] : ""
    while fp.count < c.digits + 1 { fp += "0" }
    let digits = Array(fp)
    guard let ip = Int(comps[0]) else { return nil }
    var minor = ip * pow10(c.digits) + (Int(String(digits[0..<c.digits])) ?? 0)
    if let next = digits[c.digits].wholeNumberValue, next >= 5 { minor += 1 }
    return minor
}

// MARK: - Wording

func spanOf(_ days: Int) -> (Int, String) {
    if days < 14 { return (days, "day") }
    if days < 30 { return (floorDiv(days, 7), "week") }
    if days < 335 { return (floorDiv(days, 30), "month") }
    return (max(1, roundDiv(days, 365)), "year")
}

// Kuwaiti dialect counting: 1, 2 (dual), 3 to 10 plural, 11 and up singular.
let arUnits: [String: [String]] = [
    "day": ["يوم", "يومين", "أيام", "يوم"],
    "week": ["أسبوع", "أسبوعين", "أسابيع", "أسبوع"],
    "month": ["شهر", "شهرين", "شهور", "شهر"],
    "year": ["سنة", "سنتين", "سنوات", "سنة"],
]

public func countAr(_ n: Int, _ unit: String) -> String {
    let f = arUnits[unit] ?? arUnits["day"]!
    if n == 1 { return f[0] }
    if n == 2 { return f[1] }
    if n <= 10 { return "\(n) \(f[2])" }
    return "\(n) \(f[3])"
}

/// Relative wording for a number of days from today.
public func relative(_ days: Int, _ lang: String) -> String {
    if lang == "ar" {
        if days == 0 { return "اليوم" }
        if days == 1 { return "باچر" }
        if days == -1 { return "أمس" }
        let (n, u) = spanOf(abs(days))
        return (days > 0 ? "بعد " : "من ") + countAr(n, u)
    }
    if days == 0 { return "today" }
    if days == 1 { return "tomorrow" }
    if days == -1 { return "yesterday" }
    let (n, u) = spanOf(abs(days))
    let w = "\(n) \(u)\(n == 1 ? "" : "s")"
    return days > 0 ? "in \(w)" : "\(w) ago"
}

public let monthNames: [String: [String]] = [
    "ar": ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"],
    "en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
]

public let weekdayNames: [String: [String]] = [
    "ar": ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"],
    "en": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
]

/// "25 سبتمبر" or "25 September", with the year when it differs from refYear.
public func formatDate(_ day: Day, _ lang: String, refYear: Int? = nil) -> String {
    let p = day.ymd
    let base = "\(p.d) \(monthNames[lang == "ar" ? "ar" : "en"]![p.m - 1])"
    if let refYear, refYear != 0, p.y != refYear { return "\(base) \(p.y)" }
    return base
}

// MARK: - Calendar export

func icsEscape(_ s: String) -> String {
    var out = String.UnicodeScalarView()
    var it = s.unicodeScalars.makeIterator()
    var pending: Unicode.Scalar? = nil
    func push(_ u: Unicode.Scalar) {
        switch u {
        case "\\": out.append("\\"); out.append("\\")
        case ";": out.append("\\"); out.append(";")
        case ",": out.append("\\"); out.append(",")
        case "\n": out.append("\\"); out.append("n")
        default: out.append(u)
        }
    }
    while let u = pending ?? it.next() {
        pending = nil
        if u == "\r" {
            if let nxt = it.next() {
                if nxt == "\n" { push("\n") } else { out.append(u); pending = nxt }
            } else {
                out.append(u)
            }
        } else {
            push(u)
        }
    }
    return String(out)
}

/// Folds a content line at 75 octets without splitting a character (RFC 5545 3.1).
public func foldLine(_ line: String) -> String {
    var out: [String] = []
    var cur = String.UnicodeScalarView()
    var bytes = 0
    for u in line.unicodeScalars {
        let b = String(u).utf8.count
        if bytes + b > 75 {
            out.append(String(cur))
            cur = String.UnicodeScalarView()
            cur.append(" ")
            cur.append(u)
            bytes = 1 + b
        } else {
            cur.append(u)
            bytes += b
        }
    }
    out.append(String(cur))
    return out.joined(separator: "\r\n")
}

public struct CalendarEvent: Sendable {
    public var uid: String
    public var date: Day
    public var title: String
    public var note: String?
    public var lead: Int
    public init(uid: String, date: Day, title: String, note: String? = nil, lead: Int = 0) {
        self.uid = uid; self.date = date; self.title = title; self.note = note; self.lead = lead
    }
}

/// All-day events with an alert at 9:00 on the day, and another lead days before at 9:00.
public func toICS(_ events: [CalendarEvent], stamp: String, calName: String) -> String {
    var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Nokhatha//Nokhatha//AR", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", "X-WR-CALNAME:\(icsEscape(calName))"]
    for e in events {
        let title = icsEscape(e.title)
        lines += [
            "BEGIN:VEVENT",
            "UID:\(e.uid)@nokhatha.3li.info",
            "DTSTAMP:\(stamp)",
            "DTSTART;VALUE=DATE:\(e.date.iso.replacingOccurrences(of: "-", with: ""))",
            "DTEND;VALUE=DATE:\(e.date.adding(1).iso.replacingOccurrences(of: "-", with: ""))",
            "SUMMARY:\(title)",
        ]
        if let note = e.note, !note.isEmpty { lines.append("DESCRIPTION:\(icsEscape(note))") }
        lines += ["BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:\(title)", "TRIGGER:PT9H", "END:VALARM"]
        if e.lead > 0 {
            let trigger = e.lead - 1 > 0 ? "-P\(e.lead - 1)DT15H" : "-PT15H"
            lines += ["BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:\(title)", "TRIGGER:\(trigger)", "END:VALARM"]
        }
        lines.append("END:VEVENT")
    }
    lines.append("END:VCALENDAR")
    return lines.map(foldLine).joined(separator: "\r\n") + "\r\n"
}
