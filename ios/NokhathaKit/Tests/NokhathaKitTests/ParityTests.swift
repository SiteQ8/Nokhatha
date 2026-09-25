// The web app's sample household, evaluated by the web code, must come out identical here.
import Foundation
import XCTest
@testable import NokhathaKit

final class ParityTests: XCTestCase {
    struct Fixture: Decodable {
        struct Task: Decodable { let id: String; let due: String?; let by: String; let status: String; let days: Int? }
        struct SubRow: Decodable { let id: String; let next: String; let days: Int }
        struct Total: Decodable { let month: Int; let year: Int; let count: Int }
        let today: String
        let state: AppState
        let tasks: [Task]
        let subs: [SubRow]
        let totals: [String: Total]
    }

    static let catalog = try! Catalog.load(from: VectorTests.root.appendingPathComponent("docs/data"))
    static let fixture = try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: VectorTests.root.appendingPathComponent("tests/fixtures/parity.json")))

    func testTasksMatchTheWebApp() {
        let f = Self.fixture
        let brain = Brain(catalog: Self.catalog, state: f.state, today: Day(iso: f.today)!)
        let got = brain.tasks()
        XCTAssertEqual(got.count, f.tasks.count)
        for (g, w) in zip(got, f.tasks) {
            XCTAssertEqual(g.item.id, w.id, "order differs at \(w.id)")
            XCTAssertEqual(g.due?.iso, w.due, "due of \(w.id)")
            XCTAssertEqual(g.by, w.by, "reason of \(w.id)")
            XCTAssertEqual(g.status, w.status, "status of \(w.id)")
            XCTAssertEqual(g.days, w.days, "days of \(w.id)")
        }
    }

    func testSubscriptionsMatchTheWebApp() {
        let f = Self.fixture
        let brain = Brain(catalog: Self.catalog, state: f.state, today: Day(iso: f.today)!)
        let got = Dictionary(uniqueKeysWithValues: brain.subs().map { ($0.id, $0) })
        for w in f.subs {
            XCTAssertEqual(got[w.id]?.next.iso, w.next, w.id)
            XCTAssertEqual(got[w.id]?.days, w.days, w.id)
        }
        let totals = brain.totals()
        for (cur, w) in f.totals {
            XCTAssertEqual(totals[cur], SubTotal(month: w.month, year: w.year, count: w.count), cur)
        }
    }

    func testStateSurvivesTheRoundTrip() throws {
        let data = try JSONEncoder().encode(Self.fixture.state)
        let back = try JSONDecoder().decode(AppState.self, from: data)
        XCTAssertEqual(back, Self.fixture.state)
    }

    func testSampleHouseholdMatchesTheWebShape() {
        let today = Day(iso: "2026-09-25")!
        let s = Brain.sample(catalog: Self.catalog, lang: "ar", today: today)
        let w = Self.fixture.state
        XCTAssertEqual(s.homes.map(\.name), w.homes.map(\.name))
        XCTAssertEqual(s.things.map(\.name), w.things.map(\.name))
        XCTAssertEqual(s.items.count, w.items.count)
        XCTAssertEqual(s.items.filter(\.isOn).count, w.items.filter(\.isOn).count)
        let brain = Brain(catalog: Self.catalog, state: s, today: today)
        let web = Brain(catalog: Self.catalog, state: w, today: today)
        let key = { (e: Evaluated) in "\(e.asset.name)|\(e.item.tpl ?? "")|\(e.due?.iso ?? "")|\(e.status)" }
        XCTAssertEqual(Set(brain.tasks().map(key)), Set(web.tasks().map(key)))
    }

    func testWordsSpeakTheDialect() {
        let w = Words(strings: Self.catalog.strings, lang: "ar")
        let today = Day(iso: "2026-09-25")!
        let brain = Brain(catalog: Self.catalog, state: Self.fixture.state, today: today)
        let first = brain.tasks().first!
        let line = w.due(first, today: today)
        XCTAssertTrue(line.rel.hasPrefix("فات موعده"), line.rel)
        let center = w.seasonCenter(seasonAt(today, Self.catalog.seasons), catalog: Self.catalog, today: today)
        XCTAssertEqual(center.title, "سهيل")
        XCTAssertEqual(center.line2, "باقي 20 يوم على الوسم")
        XCTAssertEqual(w.every(Every(days: 30, bawarih: 14), catalog: Self.catalog), "كل 30 يوم، وكل 14 يوم بالبوارح")
    }
}
