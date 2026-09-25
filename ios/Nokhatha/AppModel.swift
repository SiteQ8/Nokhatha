// The app's state on the device, saved as the same JSON the web app keeps.
import Foundation
import NokhathaKit
import SwiftUI
import UserNotifications

enum Onboarding: Equatable {
    case setup
    case last([String])
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let undo: AppState?
    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

@MainActor
final class AppModel: ObservableObject {
    let catalog: Catalog
    @Published var state: AppState?
    @Published var today = Day.today()
    @Published var toast: Toast?
    @Published var tab: String
    @Published var onboarding: Onboarding?

    private let file: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("nokhatha.json")
    }()

    init() {
        let data = Bundle.main.url(forResource: "data", withExtension: nil)!
        catalog = try! Catalog.load(from: data)
        let defaults = UserDefaults.standard
        tab = defaults.string(forKey: "tab") ?? "today"
        if defaults.string(forKey: "screen") == "setup" {
            state = AppState(lang: defaults.string(forKey: "lang") ?? AppModel.deviceLang)
            onboarding = .setup
        } else if defaults.bool(forKey: "sample") {
            state = Brain.sample(catalog: catalog, lang: defaults.string(forKey: "lang") ?? AppModel.deviceLang, today: today)
        } else if let d = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(AppState.self, from: d) {
            state = s
        }
    }

    static var deviceLang: String { (Locale.preferredLanguages.first ?? "ar").hasPrefix("ar") ? "ar" : "en" }

    var lang: String { state?.settings.lang ?? AppModel.deviceLang }
    var isArabic: Bool { lang == "ar" }
    var words: Words { Words(strings: catalog.strings, lang: lang) }
    var brain: Brain { Brain(catalog: catalog, state: state ?? AppState(lang: lang), today: today) }

    func t(_ key: String, _ vars: [String: String] = [:]) -> String { words.t(key, vars) }

    func refreshDay() {
        let now = Day.today()
        if now != today { today = now }
    }

    func save() {
        guard let state else { return }
        if let d = try? JSONEncoder().encode(state) { try? d.write(to: file, options: .atomic) }
        Reminders.schedule(model: self)
    }

    func update(_ toastKey: String? = nil, _ vars: [String: String] = [:], _ body: (inout Brain) -> Void) {
        let before = state
        var b = brain
        body(&b)
        state = b.state
        save()
        if let toastKey { toast = Toast(text: t(toastKey, vars), undo: before) }
    }

    func done(_ e: Evaluated) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        update("toast.done", ["title": e.title(lang)]) { $0.markDone(e.item.id) }
    }

    func snooze(_ e: Evaluated) {
        update("toast.snoozed", ["date": words.date(today.adding(7), today: today)]) { $0.snooze(e.item.id) }
    }

    func renew(_ e: Evaluated) { update("toast.saved") { $0.renew(e.item.id) } }

    func setDue(_ e: Evaluated, _ d: Date) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        let day = Day(y: c.year!, m: c.month!, d: c.day!)
        update("toast.saved") { b in
            if let i = b.state.items.firstIndex(where: { $0.id == e.item.id }) { b.state.items[i].due = day.iso }
        }
    }

    func undo() {
        guard let before = toast?.undo else { return }
        state = before
        toast = nil
        save()
    }

    func startWithSample() {
        state = Brain.sample(catalog: catalog, lang: lang, today: today)
        save()
    }

    static func guessCountry() -> String {
        let zones = ["Asia/Kuwait": "KW", "Asia/Riyadh": "SA", "Asia/Dubai": "AE", "Asia/Qatar": "QA", "Asia/Bahrain": "BH", "Asia/Muscat": "OM"]
        if let c = zones[TimeZone.current.identifier] { return c }
        if let r = Locale.current.region?.identifier, Brain.countries[r] != nil { return r }
        return "KW"
    }

    func thingName(_ type: String) -> String { catalog.thingTypes.first { $0.id == type }?.name(lang) ?? type }

    func beginSetup() {
        if state == nil { state = AppState(lang: lang) }
        onboarding = .setup
    }

    func runSetup(_ draft: Brain.Setup) {
        var b = brain
        let created = b.setUp(draft, names: (home: t("type." + draft.homeType), car: t("car.default"), thing: { [catalog, lang] type in
            catalog.thingTypes.first { $0.id == type }?.name(lang) ?? type
        }))
        state = b.state
        onboarding = .last(created)
    }

    func finishSetup(_ created: [String], answers: [String: String]) {
        update { $0.finishSetUp(created: created, answers: answers) }
        onboarding = nil
    }

    func startFresh() {
        var b = Brain(catalog: catalog, state: AppState(lang: lang), today: today)
        let home = b.addHome(type: "house", name: t("type.house"), features: ["tank": true])
        let car = b.addCar(name: t("car.default"), km: nil)
        b.spreadNew([home.id, car.id])
        b.state.settings.onboarded = true
        state = b.state
        save()
    }

    func setLang(_ l: String) {
        if state == nil { state = AppState(lang: l) } else { state?.settings.lang = l }
        save()
    }

    func eraseAll() {
        try? FileManager.default.removeItem(at: file)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        state = nil
    }
}
