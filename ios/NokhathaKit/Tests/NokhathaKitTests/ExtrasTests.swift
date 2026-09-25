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
