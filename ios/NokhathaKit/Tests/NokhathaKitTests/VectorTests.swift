// Runs tests/vectors.json, the contract shared with the web engine, against the Swift port.
import Foundation
import XCTest
@testable import NokhathaKit

final class VectorTests: XCTestCase {
    static let root: URL = {
        var u = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { u.deleteLastPathComponent() }
        return u
    }()

    static func json(_ path: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(path)), options: [.fragmentsAllowed])
    }

    static let seasonsDoc = try! json("docs/data/seasons.json") as! [String: Any]
    static let seasons: [Season] = try! JSONDecoder().decode([Season].self, from: JSONSerialization.data(withJSONObject: seasonsDoc["seasons"]!))
    static let bawarih: Window = {
        let b = seasonsDoc["bawarih"] as! [String: Any]
        return Window(start: b["start"] as! String, end: b["end"] as! String)
    }()

    // MARK: argument and result conversion

    func str(_ x: Any?) -> String { x as! String }
    func int(_ x: Any?) -> Int { (x as? Int) ?? (x as! NSNumber).intValue }
    func day(_ x: Any?) -> Day? { (x as? String).flatMap(Day.init(iso:)) }
    func iso(_ d: Day?) -> Any { d?.iso ?? NSNull() }
    func decode<T: Decodable>(_ type: T.Type, _ x: Any?) -> T {
        try! JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: x!, options: [.fragmentsAllowed]))
    }
    func window(_ x: Any?) -> Window {
        if let s = x as? String, s == "$bawarih" { return Self.bawarih }
        return decode(Window.self, x)
    }
    func car(_ x: Any?) -> CarOdometer? { x == nil || x is NSNull ? nil : decode(CarOdometer.self, x) }

    func run(_ fn: String, _ a: [Any]) -> Any? {
        let S = Self.seasons
        switch fn {
        case "dayNumber": return Day(iso: str(a[0]))!.n
        case "fromDayNumber": return Day(int(a[0])).iso
        case "weekday": return Day(iso: str(a[0]))!.weekday
        case "addDays": return Day(iso: str(a[0]))!.adding(int(a[1])).iso
        case "diffDays": return diffDays(day(a[0])!, day(a[1])!)
        case "addMonths": return Day(iso: str(a[0]))!.addingMonths(int(a[1])).iso
        case "isISO": return isISO(str(a[0]))
        case "seasonAt":
            let s = seasonAt(day(a[0])!, S)
            return ["id": s.id, "index": s.index, "start": s.start.iso, "next": s.next.iso, "nextId": s.nextId,
                    "length": s.length, "dayIn": s.dayIn, "daysLeft": s.daysLeft] as [String: Any]
        case "seasonRing":
            let r = seasonRing(day(a[0])!, S)
            return ["total": r.total, "segs": r.segs.map { ["id": $0.id, "start": $0.start.iso, "offset": $0.offset, "length": $0.length] as [String: Any] }] as [String: Any]
        case "seasonStartOnOrAfter": return iso(seasonStartOnOrAfter(day(a[0])!, str(a[1]), S))
        case "inWindow": return inWindow(day(a[0])!, window(a[1]))
        case "seasonalDue": return iso(seasonalDue(lastDone: day(a[0]), season: str(a[1]), offset: int(a[2]), today: day(a[3])!, seasons: S))
        case "kmRate":
            let r = kmRate(car(a[0])!)
            return ["num": r.num, "den": r.den] as [String: Any]
        case "kmOn": return kmOn(car(a[0])!, day(a[1])!) as Any? ?? NSNull()
        case "dateAtKm": return iso(dateAtKm(car(a[0])!, int(a[1])))
        case "lastReading":
            guard let r = lastReading(car(a[0])!) else { return NSNull() }
            return ["date": r.date, "km": r.km] as [String: Any]
        case "nextDue":
            let item = a[0] as! [String: Any]
            let ctx = a[1] as! [String: Any]
            let input = DueInput(every: decode(Every.self, item["every"]), lastDone: day(item["lastDone"]), lastKm: item["lastKm"].flatMap { $0 is NSNull ? nil : int($0) },
                                 due: day(item["due"]), snoozeUntil: day(item["snoozeUntil"]), firstDue: day(item["firstDue"]))
            let d = nextDue(input, today: day(ctx["today"])!, seasons: S, bawarih: ctx["bawarih"] == nil ? nil : window(ctx["bawarih"]), car: car(ctx["car"]))
            return ["due": iso(d.due), "by": d.by] as [String: Any]
        case "statusOf":
            let s = statusOf(day(a[0]), today: day(a[1])!, lead: int(a[2]))
            return ["status": s.status, "days": s.days as Any? ?? NSNull()] as [String: Any]
        case "cycleProgress": return cycleProgress(lastDone: day(a[0]), due: day(a[1]), today: day(a[2])!)
        case "nextRenewal":
            let sub = a[0] as! [String: Any]
            return nextRenewal(anchor: day(sub["anchor"])!, cycle: Cycle(rawValue: str(sub["cycle"]))!, today: day(a[1])!).iso
        case "nthRenewal": return nthRenewal(day(a[0])!, Cycle(rawValue: str(a[1]))!, int(a[2])).iso
        case "chargesBetween":
            let sub = a[0] as! [String: Any]
            return chargesBetween(anchor: day(sub["anchor"])!, cycle: Cycle(rawValue: str(sub["cycle"]))!, from: day(a[1])!, to: day(a[2])!)
        case "perMonth": return perMonth(int(a[0]), Cycle(rawValue: str(a[1]))!)
        case "perYear": return perYear(int(a[0]), Cycle(rawValue: str(a[1]))!)
        case "subTotals":
            let subs = (a[0] as! [[String: Any]]).map { SubAmount(amount: int($0["amount"]), currency: str($0["currency"]), cycle: Cycle(rawValue: str($0["cycle"]))!, cancelled: ($0["cancelled"] as? Bool) ?? false) }
            return subTotals(subs).mapValues { ["month": $0.month, "year": $0.year, "count": $0.count] as [String: Any] }
        case "formatMoney": return formatMoney(int(a[0]), str(a[1]), str(a[2]))
        case "normalizeDigits": return normalizeDigits(str(a[0]))
        case "parseMoney": return parseMoney(str(a[0]), str(a[1])) as Any? ?? NSNull()
        case "countAr": return countAr(int(a[0]), str(a[1]))
        case "relative": return relative(int(a[0]), str(a[1]))
        case "formatDate": return formatDate(day(a[0])!, str(a[1]), refYear: a.count > 2 ? int(a[2]) : nil)
        case "toICS":
            let evs = (a[0] as! [[String: Any]]).map { CalendarEvent(uid: str($0["uid"]), date: day($0["date"])!, title: str($0["title"]), note: $0["note"] as? String, lead: int($0["lead"])) }
            let opts = a[1] as! [String: Any]
            return toICS(evs, stamp: str(opts["stamp"]), calName: str(opts["calName"]))
        case "foldLine": return foldLine(str(a[0]))
        default: return "missing function \(fn)"
        }
    }

    func number(_ v: Any) -> Double? {
        if v is String { return nil }
        if let i = v as? Int { return Double(i) }
        if let d = v as? Double { return d }
        if let b = v as? Bool { return b ? 1 : 0 }
        if let n = v as? NSNumber { return n.doubleValue }
        return nil
    }

    func same(_ x: Any?, _ y: Any?) -> Bool {
        let a: Any? = x is NSNull ? nil : x
        let b: Any? = y is NSNull ? nil : y
        guard let a, let b else { return a == nil && b == nil }
        if let p = a as? String, let q = b as? String { return p == q }
        if let p = number(a), let q = number(b) { return abs(p - q) < 1e-9 }
        if let p = a as? [Any], let q = b as? [Any] { return p.count == q.count && zip(p, q).allSatisfy { same($0, $1) } }
        if let p = a as? [String: Any], let q = b as? [String: Any] {
            return Set(p.keys) == Set(q.keys) && p.keys.allSatisfy { same(p[$0], q[$0]) }
        }
        return false
    }

    // MARK: tests

    func testSharedVectors() throws {
        let doc = try Self.json("tests/vectors.json") as! [String: Any]
        let cases = doc["cases"] as! [[String: Any]]
        XCTAssertGreaterThanOrEqual(cases.count, 180)
        var failed = 0
        for c in cases {
            let fn = c["fn"] as! String
            let args = c["args"] as! [Any]
            let got = run(fn, args)
            if !same(got, c["out"]) {
                failed += 1
                XCTFail("\(fn) \(args) expected \(String(describing: c["out"])) got \(String(describing: got))")
            }
        }
        print("NokhathaKit: \(cases.count - failed) of \(cases.count) shared vectors pass")
    }

    func testDayNumbersRoundTrip() {
        let from = Day(iso: "1900-01-01")!.n, to = Day(iso: "2100-12-31")!.n
        for z in from...to where Day(iso: Day(z).iso)!.n != z { XCTFail("round trip \(z)"); break }
    }

    func testSeasonStructureEveryDay() {
        var d = Day(iso: "2024-01-01")!
        let end = Day(iso: "2032-12-31")!
        while d <= end {
            let s = seasonAt(d, Self.seasons)
            let r = seasonRing(d, Self.seasons)
            let ok = s.start <= d && d < s.next && s.dayIn - 1 + s.daysLeft == s.length
                && (r.total == 365 || r.total == 366) && r.segs.count == 14 && r.segs[0].id == s.id
                && zip(r.segs.dropFirst(), r.segs).allSatisfy { $0.offset == $1.offset + $1.length }
            if !ok { XCTFail("season structure on \(d)"); return }
            d = d.adding(1)
        }
    }

    func testMoneyRoundTrip() {
        for code in currencies.keys {
            for minor in [0, 5, 990, 3500, 45000, 123456, 1234567] {
                let en = formatMoney(minor, code, "en")
                XCTAssertEqual(parseMoney(String(en.dropFirst(code.count + 1)), code), minor, en)
                XCTAssertEqual(parseMoney(formatMoney(minor, code, "ar"), code), minor)
            }
        }
    }
}
