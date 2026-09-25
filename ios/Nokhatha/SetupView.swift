// First run: what do you have, then when was the last time.
import NokhathaKit
import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var d = Brain.Setup()
    @State private var extraName = ""
    @State private var extraMonths = 6
    @State private var kmText = ""
    @State private var ready = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.t("setup.step", ["n": "1", "of": "2"])).font(Theme.body(13, "Bold")).foregroundStyle(Theme.overdue).padding(.top, 24)
                Text(model.t("setup.title")).font(Theme.title(30)).foregroundStyle(Theme.ink)

                FieldLabel(text: model.t("setup.country"))
                Flow { ForEach(Brain.countryOrder, id: \.self) { c in Chip(title: model.t("country." + c), on: d.country == c) { d.country = c } } }

                FieldLabel(text: model.t("setup.type"))
                Flow {
                    ForEach(["house", "flat", "chalet", "farm", "jakhoor"], id: \.self) { ty in
                        Chip(title: model.t("type." + ty), on: d.homeType == ty) { d.homeType = ty; d.features["tank"] = ty != "flat" }
                    }
                }
                FieldLabel(text: model.t("setup.name"))
                InputField(placeholder: model.t("type." + d.homeType), text: $d.homeName)

                FieldLabel(text: model.t("setup.has"))
                VStack(spacing: 0) {
                    ForEach(["central_ac", "tank", "filter"], id: \.self) { f in
                        Toggle(model.t("feat." + f), isOn: Binding(get: { d.features[f] ?? false }, set: { d.features[f] = $0 }))
                            .font(Theme.body(15.5)).tint(Theme.ok).padding(.horizontal, 14).frame(height: 52)
                        if f != "filter" { Divider().overlay(Theme.line) }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))

                FieldLabel(text: model.t("setup.extra"))
                if !d.extras.isEmpty {
                    Flow {
                        ForEach(Array(d.extras.enumerated()), id: \.offset) { i, x in
                            Chip(title: "\(x.title)  \(model.t("setup.every_\(x.months)"))", icon: "close", on: true) { d.extras.remove(at: i) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    InputField(placeholder: model.t("setup.extra_ph"), text: $extraName)
                    Picker("", selection: $extraMonths) {
                        ForEach([1, 3, 6, 12], id: \.self) { n in Text(model.t("setup.every_\(n)")).tag(n) }
                    }
                    .pickerStyle(.menu).tint(Theme.ink)
                    Button {
                        let title = extraName.trimmingCharacters(in: .whitespaces)
                        if !title.isEmpty { d.extras.append((title: title, months: extraMonths)); extraName = "" }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).frame(width: 48, height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    }
                    .accessibilityLabel(model.t("act.add"))
                }

                FieldLabel(text: model.t("setup.car"))
                Toggle(model.t("setup.has_car"), isOn: $d.hasCar).font(Theme.body(15.5)).tint(Theme.ok)
                    .padding(.horizontal, 14).frame(height: 52)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
                if d.hasCar {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading) { FieldLabel(text: model.t("car.name")); InputField(placeholder: model.t("car.default"), text: $d.carName) }
                        VStack(alignment: .leading) { FieldLabel(text: model.t("car.km_now")); InputField(placeholder: "84000", text: $kmText, numbers: true) }
                    }
                }

                FieldLabel(text: model.t("setup.things"))
                Flow {
                    ForEach(model.catalog.thingTypes, id: \.id) { tt in
                        Chip(title: tt.name(model.lang), icon: tt.icon, on: d.things.contains(tt.id)) {
                            if let i = d.things.firstIndex(of: tt.id) { d.things.remove(at: i) } else { d.things.append(tt.id) }
                        }
                    }
                }
                if d.things.contains("other") {
                    FieldLabel(text: model.t("setup.other"))
                    InputField(placeholder: model.t("setup.other_ph"), text: $d.otherName)
                }

                WideButton(title: model.t("act.next")) {
                    d.km = wholeNumber(kmText)
                    model.runSetup(d)
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .onAppear {
            if !ready { d.country = AppModel.guessCountry(); ready = true }
        }
    }
}

struct LastTimeView: View {
    @EnvironmentObject var model: AppModel
    let created: [String]
    @State private var answers: [String: String] = [:]

    var body: some View {
        let questions = model.brain.lastQuestions(created: created)
        let templates = model.catalog.template
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.t("setup.step", ["n": "2", "of": "2"])).font(Theme.body(13, "Bold")).foregroundStyle(Theme.overdue).padding(.top, 24)
                Text(model.t("last.title")).font(Theme.title(30)).foregroundStyle(Theme.ink)
                Text(model.t("last.body")).font(Theme.body(15)).foregroundStyle(Theme.ink2).lineSpacing(4)
                ForEach(questions) { q in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(q.tpl.flatMap { templates[$0]?.name(model.lang) } ?? "").font(Theme.body(15.5, "SemiBold")).foregroundStyle(Theme.ink)
                        Flow {
                            ForEach(Brain.lastOptions, id: \.key) { o in
                                Chip(title: model.t("last." + o.key), on: (answers[q.id] ?? "unknown") == o.key) { answers[q.id] = o.key }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(Theme.line)
                }
                WideButton(title: model.t("act.finish")) { model.finishSetup(created, answers: answers) }.padding(.top, 20)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
    }
}
