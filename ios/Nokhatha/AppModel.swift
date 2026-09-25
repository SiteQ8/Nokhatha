// The app's state on the device, saved as the same JSON the web app keeps.
import Foundation
import NokhathaKit
import SwiftUI
import UserNotifications

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
        if defaults.bool(forKey: "sample") {
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

    private func change(_ toastKey: String? = nil, _ vars: [String: String] = [:], _ body: (inout Brain) -> Void) {
        let before = state
        var b = brain
        body(&b)
        state = b.state
        save()
        if let toastKey { toast = Toast(text: t(toastKey, vars), undo: before) }
    }

    func done(_ e: Evaluated) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        change("toast.done", ["title": e.title(lang)]) { $0.markDone(e.item.id) }
    }

    func snooze(_ e: Evaluated) {
        change("toast.snoozed", ["date": words.date(today.adding(7), today: today)]) { $0.snooze(e.item.id) }
    }

    func renew(_ e: Evaluated) { change("toast.saved") { $0.renew(e.item.id) } }

    func setDue(_ e: Evaluated, _ d: Date) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        let day = Day(y: c.year!, m: c.month!, d: c.day!)
        change("toast.saved") { b in
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
