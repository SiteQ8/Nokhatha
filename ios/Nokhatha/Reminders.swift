// Reminders scheduled on the iPhone itself: one notification at 9:00 on each day that has
// something due, for the coming two months. No server, nothing leaves the device.
import Foundation
import NokhathaKit
import UserNotifications

@MainActor
enum Reminders {
    static func enable(model: AppModel) async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        model.state?.settings.notify = granted
        model.save()
        return granted
    }

    static func schedule(model: AppModel) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard let state = model.state, state.settings.notify == true else { return }
        let brain = model.brain
        let words = model.words
        let today = model.today
        var byDay: [Day: [(String, Bool)]] = [:]
        for e in brain.tasks() {
            guard let due = e.due else { continue }
            let day = max(due, today)
            if day - today > 60 { continue }
            byDay[day, default: []].append(("\(e.title(model.lang))\(words.comma)\(e.asset.name)", due < today))
        }
        for s in brain.subs() where s.status != "off" && s.days <= 60 {
            let day = max(s.next.adding(-2), today)
            byDay[day, default: []].append((words.t("ask.q", ["name": s.sub.name]), false))
        }
        for w in brain.warranties() where w.days >= 0 && w.days <= 60 {
            let day = max(w.end.adding(-14), today)
            byDay[day, default: []].append((words.t("ics.warranty", ["name": w.w.name]), false))
        }
        for x in brain.docs() where x.days <= 60 {
            guard let end = Day(iso: x.d.expiry) else { continue }
            let day = x.days < 0 ? today : max(end.adding(-min(x.days, x.type.lead)), today)
            byDay[day, default: []].append((words.t("ics.doc", ["name": brain.docTitle(x.d, lang: model.lang)]), x.days < 0))
        }
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        for (day, lines) in byDay.sorted(by: { $0.key < $1.key }).prefix(60) {
            if day == today && hour >= 9 { continue }
            let content = UNMutableNotificationContent()
            content.title = lines.contains { $0.1 } ? words.t("notify.title_now") : words.t("notify.title_today")
            content.body = lines.prefix(3).map(\.0).joined(separator: "\n") + (lines.count > 3 ? "\n" + words.t("notify.more") : "")
            content.sound = .default
            let p = day.ymd
            var when = DateComponents()
            when.year = p.y; when.month = p.m; when.day = p.d; when.hour = 9
            center.add(UNNotificationRequest(identifier: "due-\(day.iso)", content: content,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        }
    }
}
