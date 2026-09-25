// First run: the mark, the promise, and two ways in.
import NokhathaKit
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image("Mark").resizable().frame(width: 108, height: 108)
            Text(model.t("app.name")).font(Theme.display(56)).foregroundStyle(Theme.ink)
            Text(model.t("welcome.tag")).font(Theme.title(21)).foregroundStyle(Theme.overdue)
            Text(model.t("welcome.body")).font(Theme.body(16)).foregroundStyle(Theme.ink2).multilineTextAlignment(.center).lineSpacing(5)
            Picker("", selection: Binding(get: { model.lang }, set: { model.setLang($0) })) {
                Text("عربي").tag("ar")
                Text("English").tag("en")
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .padding(.vertical, 6)
            Button { model.beginSetup() } label: {
                Text(model.t("welcome.start")).font(Theme.body(16, "SemiBold")).frame(maxWidth: .infinity).frame(height: 52)
                    .foregroundStyle(Theme.onInk).background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button(model.t("welcome.demo")) { model.startWithSample() }
                .font(Theme.body(15, "SemiBold")).foregroundStyle(Theme.ink2).frame(height: 44)
            Label(model.t("welcome.private"), systemImage: "lock").font(Theme.body(13.5)).foregroundStyle(Theme.ink3)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
    }
}
