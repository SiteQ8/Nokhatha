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
            if model.onboarding == .setup {
                SetupScreen()
            } else if case .last(let created) = model.onboarding {
                LastTimeScreen(created: created)
            } else if model.state?.settings.onboarded == true {
                Tabs()
            } else {
                WelcomeScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .environment(\.layoutDirection, model.isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: model.isArabic ? "ar_KW@numbers=latn" : "en_GB"))
        .preferredColorScheme(model.colorScheme)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                HStack(spacing: 14) {
                    Text(toast.text).font(Theme.body(14.5, "Medium")).foregroundStyle(Theme.onInk)
                    Spacer()
                    if toast.undo != nil {
                        Button(model.t("act.undo")) { model.undo() }.font(Theme.body(14.5, "Bold")).foregroundStyle(Theme.soon)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 14).padding(.bottom, 100)
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

/// The five tabs under the web's top bar, with More opening its own pages.
struct Tabs: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(season: model.tab != "today")
            Group {
                switch model.tab {
                case "today": TodayScreen()
                case "home": AssetsScreen(kind: .home)
                case "car": AssetsScreen(kind: .car)
                case "subs": SubsScreen()
                default:
                    switch model.page {
                    case "things": AssetsScreen(kind: .thing) { model.page = nil }
                    case "docs": DocsScreen()
                    case "warranties": WarrantiesScreen()
                    case "techs": TechsScreen()
                    case "travel": TravelScreen()
                    case "spend": SpendScreen()
                    case "settings": SettingsScreen()
                    case "about": AboutScreen()
                    default: MoreScreen()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBar()
        }
    }
}

/// The web's tab bar: five equal columns, an icon over an 11.5 label, a red dot over the one that is on.
struct TabBar: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            RowLine()
            HStack(spacing: 0) {
                ForEach([("today", "today"), ("home", "home"), ("car", "car"), ("subs", "repeat"), ("more", "more")], id: \.0) { key, icon in
                    let on = model.tab == key
                    Button { model.tab = key; model.page = nil } label: {
                        VStack(spacing: 3) {
                            ZStack(alignment: .top) {
                                Image(systemName: Symbol.name(icon)).font(.system(size: 20)).foregroundStyle(on ? Theme.ink : Theme.ink3).frame(height: 24).padding(.top, 4)
                                if on { Circle().fill(Theme.sadu).frame(width: 6, height: 6).offset(y: -3) }
                            }
                            Text(model.t("tab." + key)).font(Theme.body(11.5, "SemiBold")).foregroundStyle(on ? Theme.ink : Theme.ink3).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 9).padding(.bottom, 5).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
        }
        .background(Theme.surface.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }
}
