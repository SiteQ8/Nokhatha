// Home, car and belongings: pick one, see its tasks grouped by area.
import NokhathaKit
import SwiftUI

struct AssetsView: View {
    @EnvironmentObject var model: AppModel
    let kind: AssetKind
    @State private var selected: String?
    @State private var sheet: SheetKind?

    enum SheetKind: Identifiable {
        case addAsset, editAsset(String), addTask(String), odo(String)
        var id: String {
            switch self {
            case .addAsset: return "add"
            case .editAsset(let i): return "edit" + i
            case .addTask(let i): return "task" + i
            case .odo(let i): return "odo" + i
            }
        }
    }

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
                        Button { sheet = .addAsset } label: {
                            Label(model.t(kind == .home ? "act.add_home" : kind == .car ? "act.add_car" : "act.add_thing"), systemImage: "plus")
                                .font(Theme.body(14.5)).foregroundStyle(Theme.ink3).padding(.horizontal, 14).frame(height: 40)
                                .overlay(Capsule().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if kind == .car, let c = current, let car = state.cars.first(where: { $0.id == c.0 }) {
                    Card {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.t("car.odo")).font(Theme.body(13, "SemiBold")).foregroundStyle(Theme.ink3)
                            Text(kmOn(car.odometer, model.today).map { model.words.km($0) } ?? model.t("car.odo_unknown"))
                                .font(Theme.title(28)).foregroundStyle(Theme.ink)
                            Button { sheet = .odo(car.id) } label: {
                                Label(model.t("act.update_odo"), systemImage: "gauge.with.dots.needle.33percent").font(Theme.body(14.5, "SemiBold"))
                            }
                            .tint(Theme.ink).padding(.top, 6)
                        }
                    }
                }
                if tasks.isEmpty {
                    Card { Text(model.t(kind == .thing ? "empty.thing" : "empty.\(kind.rawValue)")).font(Theme.body(15)).foregroundStyle(Theme.ink2) }
                }
                if let c = current {
                    HStack(spacing: 10) {
                        WideButton(title: model.t("act.add_task")) { sheet = .addTask(c.0) }
                        WideButton(title: model.t(kind == .home ? "act.edit_home" : kind == .car ? "act.edit_car" : "act.edit_thing"), primary: false) { sheet = .editAsset(c.0) }
                    }
                    .padding(.top, 6)
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
        .sheet(item: $sheet) { s in
            Group {
                switch s {
                case .addAsset: AssetSheet(kind: kind, existingId: nil)
                case .editAsset(let id): AssetSheet(kind: kind, existingId: id)
                case .addTask(let id): AddTaskSheet(assetId: id)
                case .odo(let id): OdoSheet(carId: id)
                }
            }
            .environmentObject(model)
            .presentationDetents([.medium, .large])
        }
    }
}
