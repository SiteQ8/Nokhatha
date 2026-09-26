// The app's state on the device, saved as the same JSON the web app keeps.
import Foundation
import NokhathaKit
import SwiftUI
import UIKit
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
    /// The page open from More: things, docs, warranties, techs, travel, spend, settings or about.
    @Published var page: String?
    /// A sheet to open on launch, for the screenshot run: task, sub, addtask, edit, odo.
    @Published var autoSheet: String?

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
        page = defaults.string(forKey: "page")
        autoSheet = defaults.string(forKey: "sheet")
        if defaults.string(forKey: "screen") == "setup" {
            state = AppState(lang: defaults.string(forKey: "lang") ?? AppModel.deviceLang)
            onboarding = .setup
        } else if defaults.bool(forKey: "sample") {
            state = Brain.sample(catalog: catalog, lang: defaults.string(forKey: "lang") ?? AppModel.deviceLang, today: today)
        } else if let d = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(AppState.self, from: d) {
            state = s
        } else if let l = defaults.string(forKey: "lang") {
            state = AppState(lang: l)
        }
    }

    var country: String { state?.settings.country ?? "KW" }

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
        onboarding = nil
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
        try? FileManager.default.removeItem(at: receiptsDir)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        state = nil
        onboarding = nil
        page = nil
        tab = "today"
    }

    func say(_ key: String, _ vars: [String: String] = [:]) { toast = Toast(text: t(key, vars), undo: nil) }

    // MARK: receipts

    var receiptsDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("receipts")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func receiptImage(_ id: String) -> UIImage? { (try? Data(contentsOf: receiptsDir.appendingPathComponent(id))).flatMap(UIImage.init(data:)) }

    /// A photo scaled to 1600 pixels at most and saved as JPEG, as the web app does.
    static func compress(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat.default(); f.scale = 1; return f }())
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return scaled.jpegData(compressionQuality: 0.82)
    }

    func saveWarranty(_ existing: Warranty?, name: String, store: String, bought: Day, months: Int, photo: Data?) {
        var rid = existing?.receipt
        if let photo {
            let id = rid ?? newID()
            if (try? photo.write(to: receiptsDir.appendingPathComponent(id), options: .atomic)) != nil { rid = id } else { say("err.photo") }
        }
        update("toast.saved") { b in
            let w = Warranty(id: existing?.id ?? newID(), name: name, store: store.isEmpty ? nil : store, bought: bought.iso, months: months, receipt: rid)
            if let i = b.state.warranties.firstIndex(where: { $0.id == w.id }) { b.state.warranties[i] = w } else { b.state.warranties.append(w) }
        }
    }

    func deleteWarranty(_ w: Warranty) {
        if let r = w.receipt { try? FileManager.default.removeItem(at: receiptsDir.appendingPathComponent(r)) }
        update("toast.deleted") { b in b.state.warranties.removeAll { $0.id == w.id } }
    }

    // MARK: files

    /// The calendar file written to a temporary place for the share sheet.
    func calendarFile() -> URL? {
        let text = toICS(brain.calendarEvents(words), stamp: utcStamp(), calName: t("app.name"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nokhatha.ics")
        return (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
    }

    /// The encrypted backup in the web app's format, written to a temporary place for the share sheet.
    func backupFile(pass: String) async -> URL? {
        guard let s = state else { return nil }
        var receipts: [String: Any] = [:]
        for id in s.warranties.compactMap(\.receipt) {
            if let d = try? Data(contentsOf: receiptsDir.appendingPathComponent(id)) { receipts[id] = ["type": "image/jpeg", "data": d.base64EncodedString()] }
        }
        guard let stateData = try? JSONEncoder().encode(s), let stateObj = try? JSONSerialization.jsonObject(with: stateData),
              let payload = try? JSONSerialization.data(withJSONObject: ["state": stateObj, "receipts": receipts]) else { return nil }
        let name = "nokhatha-backup-\(today.iso).json"
        let file: Data? = await Task.detached(priority: .userInitiated) { try? Backup.encrypt(payload, pass: pass) }.value
        guard let file else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        guard (try? file.write(to: url, options: .atomic)) != nil else { return nil }
        state?.settings.lastBackup = today.iso
        save()
        return url
    }

    /// Nil when the backup was restored, otherwise "pass" or "format".
    func restore(from url: URL, pass: String) async -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return "format" }
        let result: Result<Data, Error> = await Task.detached(priority: .userInitiated) { Result { try Backup.decrypt(data, pass: pass) } }.value
        let payloadData: Data
        switch result {
        case .success(let d): payloadData = d
        case .failure(let e): return (e as? BackupError) == .pass ? "pass" : "format"
        }
        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any], let st = payload["state"],
              let stData = try? JSONSerialization.data(withJSONObject: st), var restored = try? JSONDecoder().decode(AppState.self, from: stData) else { return "format" }
        try? FileManager.default.removeItem(at: receiptsDir)
        if let rs = payload["receipts"] as? [String: [String: String]] {
            for (id, r) in rs { if let b64 = r["data"], let d = Data(base64Encoded: b64) { try? d.write(to: receiptsDir.appendingPathComponent(id)) } }
        }
        restored.settings.onboarded = true
        state = restored
        onboarding = nil
        save()
        return nil
    }

    // MARK: links

    func openUrl(_ s: String) { if let u = URL(string: s) { UIApplication.shared.open(u) } }
    func dial(_ phone: String) { openUrl("tel:+" + phoneDigits(phone, country: country)) }
    func whatsapp(_ phone: String) { openUrl("https://wa.me/" + phoneDigits(phone, country: country)) }

    var version: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.1" }

    /// The theme chosen in Settings.
    var colorScheme: ColorScheme? {
        switch state?.settings.theme { case "light": return .light; case "dark": return .dark; default: return nil }
    }
}
