// Words, from the same strings.json the web app uses, so the iPhone speaks the same dialect.

import Foundation

public struct Words: Sendable {
    public let strings: [String: [String: String]]
    public var lang: String

    public init(strings: [String: [String: String]], lang: String) {
        self.strings = strings
        self.lang = lang
    }

    public var isArabic: Bool { lang == "ar" }

    public func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        var s = strings[lang]?[key] ?? strings["ar"]?[key] ?? key
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }

    public func money(_ minor: Int, _ cur: String) -> String { formatMoney(minor, cur, lang) }
    public func date(_ d: Day, today: Day) -> String { formatDate(d, lang, refYear: today.ymd.y) }
    public func rel(_ days: Int) -> String { relative(days, lang) }
    public var comma: String { isArabic ? "، " : ", " }

    public func dayCount(_ n: Int) -> String { isArabic ? countAr(n, "day") : "\(n) day\(n == 1 ? "" : "s")" }
    public func monthCount(_ n: Int) -> String { isArabic ? countAr(n, "month") : "\(n) month\(n == 1 ? "" : "s")" }
    public func yearCount(_ n: Int) -> String { isArabic ? countAr(n, "year") : "\(n) year\(n == 1 ? "" : "s")" }

    public func km(_ n: Int) -> String {
        let s = groupThousands(String(n))
        return isArabic ? "\(s) كم" : "\(s) km"
    }

    /// The two parts of a task's date line: how far, and the date or odometer target.
    public func due(_ e: Evaluated, today: Day) -> (rel: String, detail: String?) {
        if e.status == "unset" { return (t("due.unset"), nil) }
        guard let d = e.due, let days = e.days else { return ("", nil) }
        let r: String
        if e.every.fixed == true {
            r = days < 0 ? t("due.expired", ["rel": rel(days)]) : t("due.expires", ["rel": rel(days)])
        } else if e.status == "overdue" {
            r = days == -1 ? t("due.overdue_yesterday") : t("due.overdue", ["rel": rel(days)])
        } else {
            r = e.status == "today" ? t("due.today") : t("due.in", ["rel": rel(days)])
        }
        if e.by == "km", let lastKm = e.item.lastKm, let k = e.every.km { return (r, t("due.km", ["km": km(lastKm + k)])) }
        return (r, date(d, today: today))
    }

    public func every(_ e: Every, catalog: Catalog) -> String {
        if e.fixed == true {
            let m = e.repeatMonths ?? 12
            return t("every.fixed", ["n": m == 12 ? t("every.year") : monthCount(m)])
        }
        if let id = e.season, let s = catalog.season(id) {
            let name = s.name(lang)
            if let o = e.offset, o != 0 { return t("every.before", ["season": name, "n": dayCount(-o)]) }
            return t("every.with", ["season": name])
        }
        var s: String
        if let k = e.km {
            s = t("every.km", ["km": km(k), "time": monthCount(e.months ?? 6)])
        } else if let m = e.months {
            s = t("every.plain", ["n": monthCount(m)])
        } else {
            s = t("every.plain", ["n": dayCount(e.days ?? 30)])
        }
        if let b = e.bawarih { s += t("every.bawarih", ["n": dayCount(b)]) }
        return s
    }

    public func greeting(hour: Int) -> String { hour >= 4 && hour < 12 ? t("greet.morning") : t("greet.evening") }

    public func longDate(_ d: Day) -> String {
        "\(weekdayNames[isArabic ? "ar" : "en"]![d.weekday]) \(formatDate(d, lang, refYear: d.ymd.y))"
    }

    public struct Center: Sendable {
        public let title: String
        public let line1: String
        public let line2: String
    }

    public func seasonCenter(_ info: SeasonInfo, catalog: Catalog, today: Day) -> Center {
        let name = catalog.season(info.id)?.name(lang) ?? ""
        let next = catalog.season(info.nextId)?.name(lang) ?? ""
        return Center(
            title: name,
            line1: "\(date(info.start, today: today)) \(t("dial.to")) \(date(info.next.adding(-1), today: today))",
            line2: t("dial.left", ["n": dayCount(info.daysLeft), "next": next]))
    }

    public func cycle(_ c: String) -> String { t("cycle." + c) }
}
