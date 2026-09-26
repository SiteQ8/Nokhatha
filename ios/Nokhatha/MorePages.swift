// More and its pages, as the web lays them out.
import NokhathaKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MoreScreen: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let s = model.state ?? AppState()
        let entries: [(String, String, String?)] = [
            ("things", "box", s.things.isEmpty ? nil : String(s.things.count)),
            ("docs", "id", s.docs.isEmpty ? nil : String(s.docs.count)),
            ("warranties", "seal", s.warranties.isEmpty ? nil : String(s.warranties.count)),
            ("techs", "wrench", s.techs.isEmpty ? nil : String(s.techs.count)),
            ("travel", "plane", s.travel.done.isEmpty ? nil : "\(s.travel.done.count)/\(model.catalog.travel.count)"),
            ("spend", "wallet", nil), ("settings", "sliders", nil), ("about", "info", nil),
        ]
        Page {
            PageHead(title: model.t("tab.more"), band: "more")
            ListCard {
                ForEach(Array(entries.enumerated()), id: \.offset) { i, e in
                    if i > 0 { RowLine() }
                    NavRow(icon: e.1, label: model.t("more." + e.0), count: e.2) { model.page = e.0 }
                }
            }
        }
    }
}

struct SubHead: View {
    @EnvironmentObject var model: AppModel
    let title: String
    var body: some View { PageHead(title: title, band: "more", back: { model.page = nil }, backText: model.t("tab.more")) }
}

/// The share sheet, for the calendar file and the backup.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - documents

struct DocsScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var adding = false
    var body: some View {
        let list = model.brain.docs()
        let groups = DocsScreen.whoGroups(list)
        Page {
            SubHead(title: model.t("more.docs"))
            Lede(text: model.t("docs.lede"))
            if list.isEmpty { EmptyNote(icon: "id", text: model.t("empty.docs")) }
            ForEach(groups, id: \.self) { g in
                if !g.isEmpty { SmallHead(text: g) }
                DocList(list: list.filter { ($0.d.who ?? "") == g })
            }
            WideButton(title: model.t("act.add_doc"), primary: false, icon: "plus") { adding = true }.padding(.top, 16)
        }
        .sheet(isPresented: $adding) { DocSheet(existing: nil) { adding = false } }
    }
}

extension DocsScreen {
    static func whoGroups(_ list: [DocView]) -> [String] {
        var groups: [String] = []
        for g in list.map({ $0.d.who ?? "" }) where !groups.contains(g) { groups.append(g) }
        return groups
    }
}

struct DocList: View {
    let list: [DocView]
    var body: some View {
        ListCard {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, x in
                if i > 0 { RowLine() }
                DocRow(x: x)
            }
        }
    }
}

/// A document's row: its icon, name, when it expires, what it needs first, and the renew button.
struct DocRow: View {
    @EnvironmentObject var model: AppModel
    let x: DocView
    @State private var open = false
    var body: some View {
        let w = model.words
        let b = model.brain
        let rel = x.status == "overdue" ? model.t("docs.expired", ["rel": w.rel(x.days)]) : x.status == "today" ? model.t("docs.today") : model.t("docs.expires", ["rel": w.rel(x.days)])
        let need: String? = x.needType != nil && x.need == nil ? model.t("docs.need_missing", ["name": x.needType!.name(model.lang, country: model.country)])
            : (x.need != nil && x.need!.status != "ok") ? model.t("docs.need", ["name": x.needType!.name(model.lang, country: model.country)]) : nil
        HStack(spacing: 10) {
            Button { open = true } label: {
                HStack(spacing: 12) {
                    RowIcon(icon: x.type.icon, tint: Theme.tint(x.status), bg: Theme.tintBg(x.status))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.docTitle(x.d, lang: model.lang)).font(Theme.body(15.5, "SemiBold")).foregroundStyle(Theme.ink)
                        HStack(spacing: 10) {
                            Text(rel).font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.tint(x.status)).lineLimit(1)
                            if let d = Day(iso: x.d.expiry) { Text(w.date(d, today: model.today)).font(Theme.body(13.5)).foregroundStyle(Theme.ink3).lineLimit(1) }
                        }
                        if let need { MetaTag(text: need) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                var br = model.brain
                if let d = br.renewDoc(x.d.id) {
                    model.state = br.state; model.save()
                    model.say("toast.doc_renewed", ["name": b.docTitle(d, lang: model.lang), "date": Day(iso: d.expiry).map { w.date($0, today: model.today) } ?? d.expiry])
                }
            } label: {
                Text(model.t("act.renewed")).font(Theme.body(13.5, "Bold")).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).frame(minWidth: 64).frame(height: 46)
                    .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line, lineWidth: 1.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 10)
        .sheet(isPresented: $open) { DocSheet(existing: x.d) { open = false } }
    }
}

struct DocSheet: View {
    @EnvironmentObject var model: AppModel
    let existing: Doc?
    let onClose: () -> Void
    @State private var type = "civil_id"
    @State private var who = ""
    @State private var name = ""
    @State private var expiry = Day.today()
    @State private var note = ""
    @State private var confirm = false

    var body: some View {
        let ty = model.catalog.docType[type] ?? model.catalog.docType["other"]!
        let portal = ty.portal?[model.country]
        SheetFrame(title: existing.map { model.brain.docTitle($0, lang: model.lang) } ?? model.t("act.add_doc"), onClose: onClose) {
            FieldLabel(text: model.t("docs.type"))
            ChoiceGrid(items: model.catalog.docTypes, columns: 2, isOn: { type == $0.id }, label: { $0.name(model.lang, country: model.country) }, icon: { $0.icon }) { t in
                if existing == nil { expiry = model.today.addingMonths(12 * t.years) }
                type = t.id
            }
            if let hint = ty.hint(model.lang) { Fine(text: hint) }
            FieldLabel(text: model.t("docs.who"))
            Input(text: $who, placeholder: model.t("docs.who_ph"))
            ChoiceGrid(items: model.catalog.who, columns: 4, isOn: { who == $0.name(model.lang) }, label: { $0.name(model.lang) }, small: true) { who = $0.name(model.lang) }.padding(.top, 8)
            FieldLabel(text: model.t("docs.name"))
            Input(text: $name, placeholder: ty.name(model.lang, country: model.country))
            DayField(label: model.t("docs.expiry"), day: $expiry)
            FieldLabel(text: model.t("docs.note"))
            Input(text: $note, placeholder: model.t("docs.note_ph"))
            if let portal { WideButton(title: model.t("docs.portal"), primary: false, icon: "link") { model.openUrl(portal) }.padding(.top, 16) }
            WideButton(title: model.t("act.save")) {
                let w = who.trimmingCharacters(in: .whitespaces), n = name.trimmingCharacters(in: .whitespaces), nt = note.trimmingCharacters(in: .whitespaces)
                model.update("toast.saved") { $0.saveDoc(Doc(id: existing?.id ?? newID(), type: type, who: w.isEmpty ? nil : w, name: n.isEmpty ? nil : n, expiry: expiry.iso, note: nt.isEmpty ? nil : nt)) }
                onClose()
            }
            .padding(.top, 12)
            if existing != nil { WideButton(title: model.t("act.delete"), danger: true, icon: "trash") { confirm = true }.padding(.top, 4) }
        }
        .onAppear {
            if let d = existing { type = d.type; who = d.who ?? ""; name = d.name ?? ""; expiry = Day(iso: d.expiry) ?? model.today; note = d.note ?? "" }
            else { expiry = model.today.addingMonths(120) }
        }
        .alert(model.t("confirm.doc"), isPresented: $confirm) {
            Button(model.t("act.delete"), role: .destructive) { if let d = existing { model.update("toast.deleted") { $0.deleteDoc(d.id) }; onClose() } }
            Button(model.t("act.cancel"), role: .cancel) {}
        }
    }
}

// MARK: - settings

struct SettingsScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var sheet: String?
    @State private var confirm: String?
    @State private var share: ShareItem?

    var body: some View {
        let s = model.state?.settings ?? Settings()
        let w = model.words
        Page {
            SubHead(title: model.t("more.settings"))
            SettingRow(icon: "chat", label: model.t("settings.lang")) { Seg(options: [("ar", "عربي"), ("en", "English")], selected: model.lang, compact: true) { model.setLang($0) } }
            SettingRow(icon: "sun", label: model.t("settings.theme")) {
                Seg(options: [("auto", model.t("settings.auto")), ("light", model.t("settings.light")), ("dark", model.t("settings.dark"))], selected: s.theme, compact: true) { v in model.update { $0.state.settings.theme = v } }
            }
            SettingRow(icon: "globe", label: model.t("settings.country")) {
                Select(value: s.country, options: ["KW", "SA", "AE", "QA", "BH", "OM"].map { ($0, model.t("country." + $0)) }, width: 200) { c in
                    model.update { b in
                        let before = Brain.countries[b.state.settings.country]?.cur
                        if b.state.settings.currency == before { b.state.settings.currency = Brain.countries[c]?.cur ?? "KWD" }
                        b.state.settings.country = c
                    }
                }
            }
            SettingRow(icon: "wallet", label: model.t("settings.currency")) {
                Select(value: s.currency, options: currencies.keys.sorted().map { ($0, "\($0) \(model.t("cur." + $0))") }, width: 200) { c in model.update { $0.state.settings.currency = c } }
            }
            SettingRow(icon: "snooze", label: model.t("settings.lead")) {
                Seg(options: [3, 7, 14].map { (String($0), w.dayCount($0)) }, selected: String(s.lead), compact: true) { v in model.update { $0.state.settings.lead = Int(v) ?? 7 } }
            }

            SmallHead(text: model.t("settings.calendar"))
            Lede(text: model.t("settings.calendar_body"), small: true)
            WideButton(title: model.t("act.ics"), primary: false, icon: "calendar") { if let u = model.calendarFile() { share = ShareItem(url: u) } }

            SmallHead(text: model.t("settings.notify"))
            Lede(text: s.notify == true ? model.t("notify.state_on") : model.t("notify.ios_ready"), small: true)
            if s.notify == true {
                WideButton(title: model.t("notify.off"), primary: false, icon: "snooze") { model.update { $0.state.settings.notify = false } }
            } else {
                WideButton(title: model.t("notify.on"), primary: false, icon: "bell") { Task { if !(await Reminders.enable(model: model)) { model.say("notify.denied") } } }
            }

            SmallHead(text: model.t("settings.backup"))
            Lede(text: model.t("settings.backup_body"), small: true)
            HStack(spacing: 8) {
                Image(systemName: s.lastBackup != nil ? "checkmark" : "info.circle").font(.system(size: 14, weight: .semibold)).foregroundStyle(s.lastBackup != nil ? Theme.ok : Theme.ink3)
                Text(s.lastBackup.flatMap { Day(iso: $0) }.map { model.t("settings.last_backup", ["date": w.date($0, today: model.today)]) } ?? model.t("settings.no_backup"))
                    .font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.ink2)
            }
            .padding(.bottom, 12)
            ButtonPair(a: model.t("act.backup"), onA: { sheet = "backup" }, b: model.t("act.restore"), onB: { sheet = "restore" }, aIcon: "download", bIcon: "upload")

            SmallHead(text: model.t("settings.data"))
            ButtonPair(a: model.t("welcome.demo"), onA: { confirm = "sample" }, b: model.t("act.wipe"), onB: { confirm = "wipe" }, aIcon: "spark", bIcon: "trash", bDanger: true)
        }
        .sheet(isPresented: Binding(get: { sheet != nil }, set: { if !$0 { sheet = nil } })) {
            if sheet == "backup" { BackupSheet { sheet = nil } } else { RestoreSheet { sheet = nil } }
        }
        .sheet(item: $share) { item in ShareSheet(url: item.url) }
        .alert(confirm == "wipe" ? model.t("confirm.wipe") : model.t("confirm.sample"), isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button(confirm == "wipe" ? model.t("act.wipe") : model.t("welcome.demo"), role: .destructive) {
                if confirm == "wipe" { model.eraseAll() } else { model.startWithSample(); model.page = nil; model.tab = "today" }
                confirm = nil
            }
            Button(model.t("act.cancel"), role: .cancel) { confirm = nil }
        }
    }
}

struct BackupSheet: View {
    @EnvironmentObject var model: AppModel
    let onClose: () -> Void
    @State private var pass = ""
    @State private var pass2 = ""
    @State private var busy = false
    @State private var share: ShareItem?

    var body: some View {
        SheetFrame(title: model.t("act.backup"), onClose: onClose) {
            Lede(text: model.t("backup.body"), small: true).padding(.top, 6)
            FieldLabel(text: model.t("backup.pass"))
            Input(text: $pass, placeholder: "", password: true)
            FieldLabel(text: model.t("backup.pass2"))
            Input(text: $pass2, placeholder: "", password: true)
            if busy {
                ProgressView().frame(maxWidth: .infinity).frame(height: 48).padding(.top, 12)
            } else {
                WideButton(title: model.t("backup.go"), icon: "lock") {
                    if pass.count < 8 { model.say("backup.short"); return }
                    if pass != pass2 { model.say("backup.mismatch"); return }
                    busy = true
                    Task {
                        let url = await model.backupFile(pass: pass)
                        busy = false
                        if let url { share = ShareItem(url: url); model.say("backup.done") } else { model.say("backup.failed") }
                    }
                }
                .padding(.top, 12)
            }
        }
        .sheet(item: $share, onDismiss: onClose) { item in ShareSheet(url: item.url) }
    }
}

struct RestoreSheet: View {
    @EnvironmentObject var model: AppModel
    let onClose: () -> Void
    @State private var file: URL?
    @State private var pass = ""
    @State private var busy = false
    @State private var picking = false

    var body: some View {
        SheetFrame(title: model.t("act.restore"), onClose: onClose) {
            Lede(text: model.t("restore.body"), small: true).padding(.top, 6)
            WideButton(title: file?.lastPathComponent ?? model.t("restore.pick"), primary: false, icon: "upload") { picking = true }
            FieldLabel(text: model.t("backup.pass"))
            Input(text: $pass, placeholder: "", password: true)
            if busy {
                ProgressView().frame(maxWidth: .infinity).frame(height: 48).padding(.top, 12)
            } else {
                WideButton(title: model.t("restore.go"), icon: "upload") {
                    guard let f = file else { model.say("restore.nofile"); return }
                    busy = true
                    Task {
                        let err = await model.restore(from: f, pass: pass)
                        busy = false
                        switch err {
                        case nil: model.say("restore.done"); onClose(); model.page = nil; model.tab = "today"
                        case "pass": model.say("restore.badpass")
                        default: model.say("restore.badfile")
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json, .plainText, .data]) { result in if case .success(let u) = result { file = u } }
    }
}

// MARK: - about

struct AboutScreen: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Page {
            SubHead(title: model.t("more.about"))
            VStack(spacing: 4) {
                Image("Mark").resizable().frame(width: 80, height: 80)
                Text(model.t("app.name")).font(Theme.title(30)).foregroundStyle(Theme.ink).padding(.top, 8)
                Text(model.t("about.version", ["v": model.version])).font(Theme.body(13)).foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 18)
            Lede(text: model.t("about.name"))
            SmallHead(text: model.t("about.privacy_h"))
            Lede(text: model.t("about.privacy"))
            Lede(text: model.t("about.keep"))
            SmallHead(text: model.t("about.open_h"))
            Lede(text: model.t("about.open"))
            ButtonPair(a: model.t("about.source"), onA: { model.openUrl("https://github.com/SiteQ8/Nokhatha") }, b: "nokhatha.3li.info", onB: { model.openUrl("https://nokhatha.3li.info") }, aIcon: "code", bIcon: "globe")
            Fine(text: model.t("about.copyright"))
        }
    }
}

// MARK: - warranties

struct WarrantiesScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var adding = false
    var body: some View {
        let ws = model.brain.warranties()
        let active = ws.filter { $0.status != "overdue" }
        let ended = ws.filter { $0.status == "overdue" }
        Page {
            SubHead(title: model.t("more.warranties"))
            Lede(text: model.t("w.lede"))
            if ws.isEmpty { EmptyNote(icon: "seal", text: model.t("empty.warranties")) }
            if !active.isEmpty { WarrantyList(list: active) }
            if !ended.isEmpty { SmallHead(text: model.t("w.ended_h")); WarrantyList(list: ended) }
            WideButton(title: model.t("act.add_warranty"), primary: false, icon: "plus") { adding = true }.padding(.top, 16)
        }
        .sheet(isPresented: $adding) { WarrantySheet(existing: nil) { adding = false } }
    }
}

struct WarrantyList: View {
    let list: [WarrantyView]
    var body: some View {
        ListCard {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, x in
                if i > 0 { RowLine() }
                WarrantyRow(x: x)
            }
        }
    }
}

struct WarrantyRow: View {
    @EnvironmentObject var model: AppModel
    let x: WarrantyView
    @State private var open = false
    var body: some View {
        let w = model.words
        let rel = x.status == "overdue" ? model.t("w.ended", ["rel": w.rel(x.days)]) : x.status == "today" ? model.t("w.today") : model.t("w.ends", ["rel": w.rel(x.days)])
        Button { open = true } label: {
            HStack(spacing: 12) {
                RowIcon(icon: "seal", tint: Theme.tint(x.status), bg: Theme.tintBg(x.status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(x.w.name).font(Theme.body(15.5, "SemiBold")).foregroundStyle(Theme.ink)
                    HStack(spacing: 10) {
                        Text(rel).font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.tint(x.status)).lineLimit(1)
                        Text(w.date(x.end, today: model.today)).font(Theme.body(13.5)).foregroundStyle(Theme.ink3).lineLimit(1)
                    }
                    if let store = x.w.store, !store.isEmpty { MetaTag(text: store) }
                }
                Spacer()
                if x.w.receipt != nil { Image(systemName: Symbol.name("receipt")).font(.system(size: 15)).foregroundStyle(Theme.ink3) }
            }
            .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) { WarrantySheet(existing: x.w) { open = false } }
    }
}

/// The camera, for a receipt photo.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage); picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onImage(nil); picker.dismiss(animated: true) }
    }
}

struct WarrantySheet: View {
    @EnvironmentObject var model: AppModel
    let existing: Warranty?
    let onClose: () -> Void
    @State private var name = ""
    @State private var store = ""
    @State private var bought = Day.today()
    @State private var months = 24
    @State private var photo: Data?
    @State private var picked: PhotosPickerItem?
    @State private var camera = false
    @State private var confirm = false

    var body: some View {
        let w = model.words
        let shown: UIImage? = photo.flatMap(UIImage.init(data:)) ?? existing?.receipt.flatMap(model.receiptImage)
        SheetFrame(title: existing?.name ?? model.t("act.add_warranty"), onClose: onClose) {
            FieldLabel(text: model.t("w.name"))
            Input(text: $name, placeholder: model.t("w.name_ph"))
            FieldLabel(text: model.t("w.store"))
            Input(text: $store, placeholder: "")
            HStack(alignment: .top, spacing: 12) {
                DayField(label: model.t("w.bought"), day: $bought)
                VStack(alignment: .leading, spacing: 0) {
                    FieldLabel(text: model.t("w.months"))
                    Seg(options: [12, 24, 36, 60].map { (String($0), w.monthCount($0)) }, selected: String(months)) { months = Int($0) ?? 24 }
                }
            }
            FieldLabel(text: model.t("w.receipt"))
            if let shown {
                Image(uiImage: shown).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 300)
                    .background(Theme.bg).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1)).padding(.bottom, 10)
            }
            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    WideButton(title: shown != nil ? model.t("w.receipt_change") : model.t("w.receipt_add"), primary: false, icon: "camera") { camera = true }
                }
                PhotosPicker(selection: $picked, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: Symbol.name("receipt")).font(.system(size: 15, weight: .semibold))
                        Text(model.t("w.receipt_pick")).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .font(Theme.body(15, "SemiBold")).foregroundStyle(Theme.ink).padding(.horizontal, 18).frame(maxWidth: .infinity).frame(height: 48)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
            }
            WideButton(title: model.t("act.save")) {
                let n = name.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty else { model.say("err.title"); return }
                model.saveWarranty(existing, name: n, store: store.trimmingCharacters(in: .whitespaces), bought: bought, months: months, photo: photo)
                onClose()
            }
            .padding(.top, 12)
            if existing != nil { WideButton(title: model.t("act.delete"), danger: true, icon: "trash") { confirm = true }.padding(.top, 4) }
        }
        .onAppear {
            if let x = existing { name = x.name; store = x.store ?? ""; bought = Day(iso: x.bought) ?? model.today; months = x.months } else { bought = model.today }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data), let c = AppModel.compress(img) { photo = c } else { model.say("err.photo") }
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { img in
                camera = false
                if let img, let c = AppModel.compress(img) { photo = c }
            }
            .ignoresSafeArea()
        }
        .alert(model.t("confirm.warranty"), isPresented: $confirm) {
            Button(model.t("act.delete"), role: .destructive) { if let x = existing { model.deleteWarranty(x); onClose() } }
            Button(model.t("act.cancel"), role: .cancel) {}
        }
    }
}

// MARK: - technicians

struct TechsScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var adding = false
    var body: some View {
        let techs = model.state?.techs ?? []
        Page {
            SubHead(title: model.t("more.techs"))
            Lede(text: model.t("tech.lede"))
            if techs.isEmpty { EmptyNote(icon: "wrench", text: model.t("empty.techs")) }
            ForEach(model.catalog.trades, id: \.id) { tr in
                let list = techs.filter { $0.trade == tr.id }
                if !list.isEmpty {
                    SmallHead(text: tr.name(model.lang))
                    ListCard {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, x in
                            if i > 0 { RowLine() }
                            TechRow(x: x)
                        }
                    }
                }
            }
            WideButton(title: model.t("act.add_tech"), primary: false, icon: "plus") { adding = true }.padding(.top, 16)
        }
        .sheet(isPresented: $adding) { TechSheet(existing: nil, trade0: "ac") { adding = false } }
    }
}

/// The web's technician row: name and number at the start, the two small buttons at the end.
struct TechRow: View {
    @EnvironmentObject var model: AppModel
    let x: Tech
    @State private var open = false
    var body: some View {
        HStack(spacing: 10) {
            Button { open = true } label: {
                HStack(spacing: 12) {
                    RowIcon(icon: "wrench", tint: Theme.ok, bg: Theme.ok.opacity(0.12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(x.name).font(Theme.body(15.5, "SemiBold")).foregroundStyle(Theme.ink)
                        Text(x.phone).font(Theme.body(13.5)).foregroundStyle(Theme.ink3).environment(\.layoutDirection, .leftToRight)
                        if let n = x.note, !n.isEmpty { Text(n).font(Theme.body(12)).foregroundStyle(Theme.ink2) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            TechButtons(x: x)
        }
        .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 10)
        .sheet(isPresented: $open) { TechSheet(existing: x, trade0: x.trade) { open = false } }
    }
}

/// The web's .tech-b: two 40 point buttons.
struct TechButtons: View {
    @EnvironmentObject var model: AppModel
    let x: Tech
    var body: some View {
        HStack(spacing: 8) {
            WideButton(title: model.t("tech.call"), primary: false, icon: "phone", height: 40, block: false) { model.dial(x.phone) }
            WideButton(title: model.t("tech.whatsapp"), primary: false, icon: "chat", height: 40, block: false) { model.whatsapp(x.phone) }
        }
    }
}

struct TechSheet: View {
    @EnvironmentObject var model: AppModel
    let existing: Tech?
    let trade0: String
    let onClose: () -> Void
    @State private var name = ""
    @State private var trade = "ac"
    @State private var phone = ""
    @State private var note = ""
    @State private var confirm = false

    var body: some View {
        SheetFrame(title: existing?.name ?? model.t("act.add_tech"), onClose: onClose) {
            FieldLabel(text: model.t("tech.name"))
            Input(text: $name, placeholder: "")
            FieldLabel(text: model.t("tech.trade"))
            ChoiceGrid(items: model.catalog.trades, columns: 3, isOn: { $0.id == trade }, label: { $0.name(model.lang) }) { trade = $0.id }
            FieldLabel(text: model.t("tech.phone"))
            Input(text: $phone, placeholder: "+" + (Brain.countries[model.country]?.cc ?? "965"), phone: true)
            FieldLabel(text: model.t("tech.note"))
            Input(text: $note, placeholder: "")
            WideButton(title: model.t("act.save")) {
                let n = name.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty else { model.say("err.title"); return }
                let nt = note.trimmingCharacters(in: .whitespaces)
                model.update("toast.saved") { b in
                    let t = Tech(id: existing?.id ?? newID(), name: n, trade: trade, phone: phone.trimmingCharacters(in: .whitespaces), note: nt.isEmpty ? nil : nt)
                    if let i = b.state.techs.firstIndex(where: { $0.id == t.id }) { b.state.techs[i] = t } else { b.state.techs.append(t) }
                }
                onClose()
            }
            .padding(.top, 12)
            if existing != nil { WideButton(title: model.t("act.delete"), danger: true, icon: "trash") { confirm = true }.padding(.top, 4) }
        }
        .onAppear {
            if let x = existing { name = x.name; trade = x.trade; phone = x.phone; note = x.note ?? "" } else { trade = trade0 }
        }
        .alert(model.t("confirm.tech"), isPresented: $confirm) {
            Button(model.t("act.delete"), role: .destructive) { if let x = existing { model.update("toast.deleted") { b in b.state.techs.removeAll { $0.id == x.id } }; onClose() } }
            Button(model.t("act.cancel"), role: .cancel) {}
        }
    }
}

// MARK: - travel

struct TravelScreen: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let done = Set(model.state?.travel.done ?? [])
        let list = model.catalog.travel
        Page {
            SubHead(title: model.t("more.travel"))
            Lede(text: model.t("travel.lede"))
            Text(model.t("travel.progress", ["n": String(done.count), "of": String(list.count)])).font(Theme.body(14, "Bold")).foregroundStyle(Theme.ink2).padding(.bottom, 10)
            ListCard {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, x in
                    if i > 0 { RowLine() }
                    let on = done.contains(x.id)
                    Button {
                        model.update { b in
                            var d = Set(b.state.travel.done)
                            if on { d.remove(x.id) } else { d.insert(x.id) }
                            b.state.travel.done = list.map(\.id).filter { d.contains($0) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            CheckBox(on: on)
                            Text(x.name(model.lang)).font(Theme.body(16)).foregroundStyle(on ? Theme.ink3 : Theme.ink).strikethrough(on).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            WideButton(title: model.t("travel.reset"), quiet: true, icon: "repeat") { model.update { $0.state.travel.done = [] } }.padding(.top, 16)
        }
    }
}

// MARK: - spend

struct SpendScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var year = Day.today().ymd.y
    var body: some View {
        let w = model.words
        let thisYear = model.today.ymd.y
        let r = model.brain.spend(year: year, lang: model.lang)
        Page {
            SubHead(title: model.t("more.spend"))
            HStack(spacing: 8) {
                YearButton(text: String(year - 1), forward: true) { year -= 1 }.frame(maxWidth: .infinity, alignment: .leading)
                Text(String(year)).font(Theme.title(22)).foregroundStyle(Theme.ink)
                Group { if year < thisYear { YearButton(text: String(year + 1), forward: false) { year += 1 } } }.frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.bottom, 14)
            if r.blocks.isEmpty { EmptyNote(icon: "wallet", text: model.t("empty.spend")) }
            ForEach(Array(r.blocks.enumerated()), id: \.element.id) { i, b in
                CardBox(padding: 18) {
                    Text(model.t("spend.total", ["year": String(year)])).font(Theme.body(13.5, "SemiBold")).foregroundStyle(Theme.ink3)
                    Text(w.money(b.total, b.currency)).font(Theme.title(40)).foregroundStyle(Theme.ink)
                    if year == thisYear { Text(model.t("spend.projected", ["amount": w.money(b.projected + b.home + b.car + b.things, b.currency)])).font(Theme.body(14)).foregroundStyle(Theme.ink2) }
                    let mx = max(b.home, b.car, b.things, b.subs, 1)
                    let bars: [(String, String, Int)] = [("home", "home", b.home), ("car", "car", b.car)] + (b.things > 0 ? [("things", "box", b.things)] : []) + [("subs", "repeat", b.subs)]
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                        HStack {
                            Image(systemName: Symbol.name(bar.1)).font(.system(size: 14)).foregroundStyle(Theme.ink3)
                            Text(model.t("spend." + bar.0)).font(Theme.body(14, "SemiBold")).foregroundStyle(Theme.ink2)
                            Spacer()
                            Text(w.money(bar.2, b.currency)).font(Theme.body(14, "Bold")).foregroundStyle(Theme.ink)
                        }
                        .padding(.top, 12)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Theme.ink.opacity(0.07))
                                RoundedRectangle(cornerRadius: 4).fill(Theme.ink).frame(width: g.size.width * CGFloat(bar.2) / CGFloat(mx))
                            }
                        }
                        .frame(height: 8).padding(.top, 4)
                    }
                }
                .padding(.top, i > 0 ? 12 : 0)
            }
            Lede(text: model.t("spend.note"), small: true).padding(.top, 14)
            if !r.logs.isEmpty {
                SmallHead(text: model.t("spend.logged"), top: 8)
                ListCard {
                    ForEach(Array(r.logs.enumerated()), id: \.offset) { i, l in
                        if i > 0 { RowLine() }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.title).font(Theme.body(15.5, "SemiBold")).foregroundStyle(Theme.ink)
                                HStack(spacing: 10) {
                                    Text(w.date(l.date, today: model.today)).font(Theme.body(13.5)).foregroundStyle(Theme.ink3)
                                    if let a = l.asset { MetaTag(text: a) }
                                }
                            }
                            Spacer()
                            Text(w.money(l.cost, l.currency)).font(Theme.body(15, "Bold")).foregroundStyle(Theme.ink)
                        }
                        .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 14)
                    }
                }
            }
        }
    }
}

/// The web's year link: a quiet 40 point button with the chevron after the year.
struct YearButton: View {
    let text: String
    let forward: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if !forward { Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold)) }
                Text(text).font(Theme.body(15, "SemiBold"))
                if forward { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)) }
            }
            .foregroundStyle(Theme.ink).padding(.horizontal, 10).frame(height: 40)
        }
        .buttonStyle(.plain)
    }
}
