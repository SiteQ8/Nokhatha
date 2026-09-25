// Home, car and belongings: pick one, see its tasks grouped by area.
import NokhathaKit
import SwiftUI

struct AssetsView: View {
    @EnvironmentObject var model: AppModel
    let kind: AssetKind
    @State private var selected: String?

    var body: some View {
        let state = model.state ?? AppState()
        let list: [(String, String)] = kind == .home ? state.homes.map { ($0.id, $0.name) }
            : kind == .car ? state.cars.map { ($0.id, $0.name) } : state.things.map { ($0.id, $0.name) }
        let current = selected.flatMap { id in list.first { $0.0 == id } } ?? list.first
        let areas = model.catalog.areas[kind.rawValue] ?? []
        let tasks = current.map { c in model.brain.tasks { $0.asset == c.0 } } ?? []
        let title = kind == .home ? model.t("tab.home") : kind == .car ? model.t("tab.car") : model.t("more.things")

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Header()
                Text(title).font(Theme.title(30)).foregroundStyle(Theme.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(list, id: \.0) { item in
                            let on = item.0 == current?.0
                            Button(item.1) { selected = item.0 }
                                .font(Theme.body(14.5, on ? "SemiBold" : "Regular"))
                                .foregroundStyle(on ? Theme.onInk : Theme.ink2)
                                .padding(.horizontal, 15).frame(height: 40)
                                .background(on ? Theme.ink : Theme.surface, in: Capsule())
                                .overlay(Capsule().stroke(on ? Theme.ink : Theme.line, lineWidth: 1))
                        }
                    }
                }
                if kind == .car, let c = current, let car = state.cars.first(where: { $0.id == c.0 }) {
                    Card {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.t("car.odo")).font(Theme.body(13, "SemiBold")).foregroundStyle(Theme.ink3)
                            Text(kmOn(car.odometer, model.today).map { model.words.km($0) } ?? model.t("car.odo_unknown"))
                                .font(Theme.title(28)).foregroundStyle(Theme.ink)
                        }
                    }
                }
                if tasks.isEmpty {
                    Card { Text(model.t(kind == .thing ? "empty.thing" : "empty.\(kind.rawValue)")).font(Theme.body(15)).foregroundStyle(Theme.ink2) }
                }
                ForEach(areas, id: \.id) { area in
                    let rows = tasks.filter { ($0.tpl?.area ?? "custom") == area.id }
                    if !rows.isEmpty {
                        Text(area.name(model.lang)).font(Theme.body(13, "Bold")).foregroundStyle(Theme.ink3).padding(.top, 10)
                        TaskList(rows: rows)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Theme.bg)
    }
}
