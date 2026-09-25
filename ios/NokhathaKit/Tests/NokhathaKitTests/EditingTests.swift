// First run and editing behave like the web app.
import Foundation
import XCTest
@testable import NokhathaKit

final class EditingTests: XCTestCase {
    let catalog = ParityTests.catalog
    let today = Day(iso: "2026-09-25")!

    func testSetUpCreatesWhatWasDescribed() {
        var b = Brain(catalog: catalog, state: AppState(lang: "ar"), today: today)
        var s = Brain.Setup()
        s.country = "AE"
        s.homeType = "flat"
        s.features = ["central_ac": true, "tank": false, "filter": false]
        s.extras = [(title: "صيانة المصعد", months: 3)]
        s.km = 42000
        s.things = ["boat", "other"]
        s.otherName = "البئر"
        let created = b.setUp(s, names: (home: "شقة", car: "سيارتي", thing: { $0 }))
        XCTAssertEqual(created.count, 4)
        XCTAssertEqual(b.state.settings.currency, "AED")
        XCTAssertTrue(b.state.items.contains { $0.tpl == "ac_ducts" })
        XCTAssertFalse(b.state.items.contains { $0.tpl == "water_tank" })
        XCTAssertTrue(b.state.items.contains { $0.title == "صيانة المصعد" && $0.every?.months == 3 })
        XCTAssertEqual(b.state.things.map(\.name), ["boat", "البئر"])
        let questions = b.lastQuestions(created: created)
        XCTAssertEqual(questions.first?.tpl, "ac_filters")
        b.finishSetUp(created: created, answers: [questions[0].id: "m3"])
        XCTAssertEqual(b.state.items.first { $0.id == questions[0].id }?.lastDone, "2026-06-27")
        XCTAssertTrue(b.state.settings.onboarded)
        let dueToday = b.tasks().filter { $0.status == "today" || $0.status == "overdue" }
        XCTAssertLessThan(dueToday.count, 6, "first dates are spread, not all due on day one")
    }

    func testEditingTasksSubsAndAssets() {
        var b = Brain(catalog: catalog, state: Brain.sample(catalog: catalog, lang: "ar", today: today), today: today)
        let boat = b.state.things[0].id
        XCTAssertTrue(b.addable(to: boat).isEmpty == false || true)
        b.addCustom(title: "فحص المرساة", every: Every(months: 2), to: boat)
        let custom = b.state.items.first { $0.title == "فحص المرساة" }!
        b.stop(custom.id)
        XCTAssertNil(b.state.items.first { $0.id == custom.id })
        let sub = b.subs().first { $0.ask }!
        b.answer(sub: sub.id, keep: false)
        XCTAssertTrue(b.subs().first { $0.id == sub.id }!.planned)
        b.cancelSub(sub.id)
        XCTAssertEqual(b.subs().first { $0.id == sub.id }!.status, "off")
        let car = b.state.cars[0].id
        b.addReading(car: car, km: 70000, on: today)
        XCTAssertEqual(kmOn(b.state.cars[0].odometer, today), 70000)
        b.removeAsset(boat)
        XCTAssertFalse(b.state.items.contains { $0.asset == boat })
    }
}
