// More: belongings, language, reminders on the device, privacy.
import NokhathaKit
import SwiftUI

struct MoreView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Header()
                    Text(model.t("tab.more")).font(Theme.title(30)).foregroundStyle(Theme.ink)
                    NavigationLink { AssetsView(kind: .thing) } label: {
                        Card(padding: 14) {
                            HStack {
                                Image(systemName: Symbol.name("box")).foregroundStyle(Theme.ink)
                                Text(model.t("more.things")).font(Theme.body(16, "SemiBold")).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(verbatim: String(model.state?.things.count ?? 0)).font(Theme.body(13, "Bold")).foregroundStyle(Theme.ink3)
                                Image(systemName: model.isArabic ? "chevron.left" : "chevron.right").foregroundStyle(Theme.ink3)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    SectionTitle(text: model.t("settings.lang"))
                    Picker(model.t("settings.lang"), selection: Binding(get: { model.lang }, set: { model.setLang($0) })) {
                        Text("عربي").tag("ar")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)

                    SectionTitle(text: model.t("settings.country"))
                    Picker(model.t("settings.country"), selection: Binding(get: { model.state?.settings.country ?? "KW" }, set: { c in
                        model.update { b in
                            let before = Brain.countries[b.state.settings.country]?.cur
                            b.state.settings.country = c
                            if b.state.settings.currency == before { b.state.settings.currency = Brain.countries[c]?.cur ?? "KWD" }
                        }
                    })) {
                        ForEach(Brain.countryOrder, id: \.self) { c in Text(model.t("country." + c)).tag(c) }
                    }
                    .pickerStyle(.menu).tint(Theme.ink)
                    Picker(model.t("settings.currency"), selection: Binding(get: { model.state?.settings.currency ?? "KWD" }, set: { c in model.update { $0.state.settings.currency = c } })) {
                        ForEach(["KWD", "SAR", "AED", "QAR", "BHD", "OMR", "USD"], id: \.self) { c in Text("\(c)  \(model.t("cur." + c))").tag(c) }
                    }
                    .pickerStyle(.menu).tint(Theme.ink)
                    SectionTitle(text: model.t("settings.lead"))
                    Picker(model.t("settings.lead"), selection: Binding(get: { model.state?.settings.lead ?? 7 }, set: { n in model.update { $0.state.settings.lead = n } })) {
                        ForEach([3, 7, 14], id: \.self) { n in Text(model.words.dayCount(n)).tag(n) }
                    }
                    .pickerStyle(.segmented)

                    SectionTitle(text: model.t("settings.notify"))
                    Text(model.state?.settings.notify == true ? model.t("notify.state_on") : model.t("notify.ios_ready"))
                        .font(Theme.body(14)).foregroundStyle(Theme.ink2).lineSpacing(4)
                    if model.state?.settings.notify != true {
                        Button { Task { _ = await Reminders.enable(model: model) } } label: {
                            Label(model.t("notify.on"), systemImage: "bell").font(Theme.body(16, "SemiBold"))
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .foregroundStyle(Theme.onInk).background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    SectionTitle(text: model.t("about.privacy_h"))
                    Text(model.t("about.privacy")).font(Theme.body(14.5)).foregroundStyle(Theme.ink2).lineSpacing(5)

                    Button(role: .destructive) { confirmErase = true } label: {
                        Label(model.t("act.wipe"), systemImage: "trash").font(Theme.body(15, "SemiBold")).frame(maxWidth: .infinity).frame(height: 48)
                    }
                    .padding(.top, 16)
                    Text(model.t("about.copyright")).font(Theme.body(12.5)).foregroundStyle(Theme.ink3).frame(maxWidth: .infinity).padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(Theme.bg)
            .confirmationDialog(model.t("confirm.wipe"), isPresented: $confirmErase, titleVisibility: .visible) {
                Button(model.t("act.wipe"), role: .destructive) { model.eraseAll() }
            }
        }
    }
}
