// Warranties, technicians' numbers, the calendar, spending and the backup that the web app can open.
import Foundation
import XCTest
@testable import NokhathaKit

final class ExtrasTests: XCTestCase {
    static let catalog = try! Catalog.load(from: VectorTests.root.appendingPathComponent("docs/data"))

    func testPhoneNumbersLikeTheWeb() {
        XCTAssertEqual(phoneDigits("51153554", country: "KW"), "96551153554")
        XCTAssertEqual(phoneDigits("٥١١٥٣٥٥٤", country: "KW"), "96551153554")
        XCTAssertEqual(phoneDigits("+965 5115 3554", country: "KW"), "96551153554")
        XCTAssertEqual(phoneDigits("00965-51153554", country: "KW"), "96551153554")
        XCTAssertEqual(phoneDigits("0512345678", country: "SA"), "966512345678")
        XCTAssertEqual(phoneDigits("1234", country: "KW"), "1234")
    }

    func testWarrantiesSpendAndCalendar() {
        let today = Day(iso: "2026-09-25")!
        let sample = Brain.sample(catalog: Self.catalog, lang: "ar", today: today)
        let b = Brain(catalog: Self.catalog, state: sample, today: today)
        let ws = b.warranties()
        XCTAssertEqual(ws.count, 2)
        XCTAssertEqual(ws.first?.status, "soon")
        XCTAssertEqual(ws.first?.days, 26)
        let report = b.spend(year: 2026, lang: "ar")
        let kwd = report.blocks.first { $0.currency == "KWD" }!
        let logged = sample.items.flatMap { $0.log ?? [] }.filter { $0.cost != nil && $0.date.hasPrefix("2026") }.reduce(0) { $0 + $1.cost! }
        XCTAssertEqual(kwd.home + kwd.car + kwd.things, logged)
        XCTAssertTrue(kwd.subs > 0 && kwd.projected >= kwd.subs)
        XCTAssertEqual(report.logs.map(\.date.n), report.logs.map(\.date.n).sorted(by: >))
        let events = b.calendarEvents(Words(strings: Self.catalog.strings, lang: "ar"))
        XCTAssertEqual(events.count, b.tasks().filter { $0.due != nil }.count + b.subs().filter { $0.sub.cancelled != true }.count + ws.filter { $0.end >= today }.count)
        XCTAssertTrue(events.allSatisfy { $0.date >= today })
        let ics = toICS(events, stamp: utcStamp(Date(timeIntervalSince1970: 0)), calName: "نُوخذة")
        XCTAssertTrue(ics.hasPrefix("BEGIN:VCALENDAR\r\n") && ics.contains("DTSTAMP:19700101T000000Z"))
    }

    #if canImport(CryptoKit) && canImport(CommonCrypto)
    struct WebBackup: Decodable {
        struct File: Decodable { let app: String; let format: Int; let iterations: Int; let salt: String; let iv: String; let data: String }
        let file: File
        let state: AppState
    }

    func testOpensABackupMadeByTheWebApp() throws {
        let raw = try Data(contentsOf: VectorTests.root.appendingPathComponent("tests/fixtures/backup-web.json"))
        let f = try JSONDecoder().decode(WebBackup.self, from: raw)
        let fileData = try JSONSerialization.data(withJSONObject: ["app": f.file.app, "format": f.file.format, "iterations": f.file.iterations, "salt": f.file.salt, "iv": f.file.iv, "data": f.file.data])
        let payload = try JSONSerialization.jsonObject(with: Backup.decrypt(fileData, pass: "nokhatha-test-2026")) as! [String: Any]
        let state = try JSONDecoder().decode(AppState.self, from: JSONSerialization.data(withJSONObject: payload["state"]!))
        XCTAssertEqual(state, f.state)
        XCTAssertEqual(state.warranties.first?.receipt, "r1")
        let receipts = payload["receipts"] as! [String: [String: String]]
        XCTAssertEqual(receipts["r1"]?["type"], "image/jpeg")
        XCTAssertEqual(Array(Data(base64Encoded: receipts["r1"]!["data"]!)!), [0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 0xff, 0xd9])
        XCTAssertThrowsError(try Backup.decrypt(fileData, pass: "wrong-password")) { XCTAssertEqual($0 as? BackupError, .pass) }
        XCTAssertThrowsError(try Backup.decrypt(Data("{\"app\":\"other\"}".utf8), pass: "x")) { XCTAssertEqual($0 as? BackupError, .format) }
        let mine = try Backup.encrypt(Data("{\"v\":1,\"note\":\"نُوخذة\"}".utf8), pass: "12345678", iterations: 1000)
        XCTAssertEqual(String(decoding: try Backup.decrypt(mine, pass: "12345678"), as: UTF8.self), "{\"v\":1,\"note\":\"نُوخذة\"}")
    }
    #endif
}

final class DocsTests: XCTestCase {
    func testDocumentsAndRenewalLikeTheWeb() {
        let catalog = ExtrasTests.catalog
        let today = Day(iso: "2026-09-25")!
        var b = Brain(catalog: catalog, state: Brain.sample(catalog: catalog, lang: "ar", today: today), today: today)
        let docs = b.docs()
        XCTAssertEqual(docs.count, 4)
        XCTAssertEqual(docs.first?.type.id, "civil_id")
        XCTAssertEqual(docs.first?.status, "soon")
        let res = docs.first { $0.type.id == "residency" }!
        XCTAssertEqual(res.status, "soon")
        XCTAssertEqual(res.needType?.id, "health")
        XCTAssertEqual(res.need?.status, "soon")
        XCTAssertEqual(b.docTitle(res.d, lang: "ar"), "الإقامة")
        XCTAssertEqual(catalog.docType["residency"]!.name("en", country: "SA"), "Iqama")
        XCTAssertEqual(b.renewDoc(res.d.id)?.expiry, today.adding(52).addingMonths(12).iso)
        b.saveDoc(Doc(id: "x", type: "passport", who: "أنا", expiry: today.adding(-30).iso))
        XCTAssertEqual(b.evalDoc(b.state.docs.last!).status, "overdue")
        XCTAssertEqual(b.renewDoc("x")?.expiry, today.addingMonths(120).iso)
        b.deleteDoc("x")
        XCTAssertEqual(b.state.docs.count, 4)
        let car = b.state.cars[0]
        XCTAssertTrue(b.renewalShown(car.id))
        b.setRenewStep(car.id, "insurance", on: true)
        b.setRenewYears(car.id, 2)
        XCTAssertEqual(b.state.cars[0].renewal?.done, ["insurance"])
        b.finishRenewal(car.id)
        let reg = b.state.items.first { $0.asset == car.id && $0.tpl == "registration" }!
        XCTAssertEqual(reg.due, today.adding(21).addingMonths(24).iso)
        XCTAssertEqual(reg.lastDone, today.iso)
        XCTAssertNil(b.state.cars[0].renewal)
        XCTAssertFalse(b.renewalShown(car.id))
        // the web's fixture round trips with its documents
        let raw = try! Data(contentsOf: VectorTests.root.appendingPathComponent("tests/fixtures/parity.json"))
        struct StateOnly: Decodable { let state: AppState }
        let fixture = try! JSONDecoder().decode(StateOnly.self, from: raw)
        XCTAssertEqual(fixture.state.docs.count, 4)
        let back = try! JSONDecoder().decode(AppState.self, from: try! JSONEncoder().encode(fixture.state))
        XCTAssertEqual(back.docs, fixture.state.docs)
    }
}
