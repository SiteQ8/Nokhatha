// نُوخذة on iPhone.
import NokhathaKit
import SwiftUI

@main
struct NokhathaApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onChange(of: phase) { _, now in
                    if now == .active { model.refreshDay(); Reminders.schedule(model: model) }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.state?.settings.onboarded == true {
                TabView(selection: $model.tab) {
                    TodayView().tabItem { Label(model.t("tab.today"), systemImage: Symbol.name("today")) }.tag("today")
                    NavigationStack { AssetsView(kind: .home) }.tabItem { Label(model.t("tab.home"), systemImage: Symbol.name("home")) }.tag("home")
                    NavigationStack { AssetsView(kind: .car) }.tabItem { Label(model.t("tab.car"), systemImage: Symbol.name("car")) }.tag("car")
                    SubsView().tabItem { Label(model.t("tab.subs"), systemImage: Symbol.name("repeat")) }.tag("subs")
                    MoreView().tabItem { Label(model.t("tab.more"), systemImage: Symbol.name("more")) }.tag("more")
                }
                .tint(Theme.ink)
            } else if model.onboarding == .setup {
                SetupView()
            } else if case .last(let created) = model.onboarding {
                LastTimeView(created: created)
            } else {
                WelcomeView()
            }
        }
        .environment(\.layoutDirection, model.isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: model.isArabic ? "ar_KW@numbers=latn" : "en_GB"))
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                HStack {
                    Text(toast.text).font(Theme.body(14.5, "Medium")).foregroundStyle(Theme.onInk)
                    Spacer()
                    if toast.undo != nil {
                        Button(model.t("act.undo")) { model.undo() }.font(Theme.body(14.5, "Bold")).foregroundStyle(Theme.soon)
                    }
                }
                .padding(.horizontal, 16).frame(height: 50)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 14).padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(5))
                    if model.toast?.id == toast.id { withAnimation { model.toast = nil } }
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.toast)
    }
}
