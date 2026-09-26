// The web app's building blocks, measured from its stylesheets: .top with the season pill,
// .ph and .band, .back, .segc, .chip grids, select, .nav-row, .setting, .empty, .actions.
import NokhathaKit
import SwiftUI

// MARK: - top bar, page head, band

/// The web's top bar: the brand at the start and, off Today, the current season in a pill.
struct TopBar: View {
    @EnvironmentObject var model: AppModel
    let season: Bool
    var body: some View {
        HStack {
            HStack(spacing: 9) {
                Image("Mark").resizable().frame(width: 30, height: 30)
                Text(model.t("app.name")).font(Theme.title(21)).foregroundStyle(Theme.ink)
            }
            Spacer()
            if season {
                let name = model.catalog.season(seasonAt(model.today, model.catalog.seasons).id)?.name(model.lang) ?? ""
                HStack(spacing: 7) {
                    Circle().fill(Theme.sadu).frame(width: 8, height: 8).padding(3).background(Theme.sadu.opacity(0.18), in: Circle())
                    Text(name).font(Theme.body(13, "SemiBold")).foregroundStyle(Theme.ink2)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Theme.bg.opacity(0.94).ignoresSafeArea(edges: .top))
    }
}

/// The Sadu bands the web draws under page titles, 10 points high: diamonds, triangles, circles or bars.
struct Band: View {
    let kind: String
    var body: some View {
        Canvas { ctx, size in
            let h = size.height
            let u = h / 10
            func diamond(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ c: Color) {
                var p = Path(); p.move(to: CGPoint(x: cx, y: cy - r)); p.addLine(to: CGPoint(x: cx + r, y: cy)); p.addLine(to: CGPoint(x: cx, y: cy + r)); p.addLine(to: CGPoint(x: cx - r, y: cy)); p.closeSubpath()
                ctx.fill(p, with: .color(c))
            }
            var x: CGFloat = 0
            switch kind {
            case "car":
                while x < size.width {
                    var t = Path(); t.move(to: CGPoint(x: x, y: h)); t.addLine(to: CGPoint(x: x + 6 * u, y: 0)); t.addLine(to: CGPoint(x: x + 12 * u, y: h)); t.closeSubpath()
                    ctx.fill(t, with: .color(Theme.sadu))
                    var a = Path(); a.move(to: CGPoint(x: x, y: 0)); a.addLine(to: CGPoint(x: x + 6 * u, y: 0)); a.addLine(to: CGPoint(x: x, y: h)); a.closeSubpath()
                    var b = Path(); b.move(to: CGPoint(x: x + 6 * u, y: 0)); b.addLine(to: CGPoint(x: x + 12 * u, y: 0)); b.addLine(to: CGPoint(x: x + 12 * u, y: h)); b.closeSubpath()
                    ctx.fill(a, with: .color(Theme.bandInk)); ctx.fill(b, with: .color(Theme.bandInk))
                    x += 12 * u
                }
            case "subs":
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x + 0.3 * u, y: 1.8 * u, width: 6.4 * u, height: 6.4 * u)), with: .color(Theme.sadu))
                    ctx.fill(Path(ellipseIn: CGRect(x: x + 7.3 * u, y: 1.8 * u, width: 6.4 * u, height: 6.4 * u)), with: .color(Theme.bandInk))
                    x += 14 * u
                }
            case "more":
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 4 * u, height: h)), with: .color(Theme.sadu))
                    ctx.fill(Path(CGRect(x: x + 8 * u, y: 0, width: 4 * u, height: h)), with: .color(Theme.bandInk))
                    ctx.fill(Path(CGRect(x: x + 4 * u, y: 4 * u, width: 4 * u, height: 2 * u)), with: .color(Theme.sand))
                    ctx.fill(Path(CGRect(x: x + 12 * u, y: 4 * u, width: 4 * u, height: 2 * u)), with: .color(Theme.sand))
                    x += 16 * u
                }
            default:
                while x < size.width {
                    diamond(x + 5 * u, 5 * u, 5 * u, Theme.sadu); diamond(x + 15 * u, 5 * u, 5 * u, Theme.bandInk)
                    diamond(x + 5 * u, 5 * u, 1.8 * u, Theme.sand); diamond(x + 15 * u, 5 * u, 1.8 * u, Theme.sand)
                    x += 20 * u
                }
            }
        }
        .frame(height: 10)
    }
}

/// The web's .back link above a page opened from More.
struct BackLink: View {
    @EnvironmentObject var model: AppModel
    let text: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: model.isArabic ? "chevron.right" : "chevron.left").font(.system(size: 13, weight: .semibold))
                Text(text)
            }
            .font(Theme.body(14, "SemiBold")).foregroundStyle(Theme.ink2)
        }
        .buttonStyle(.plain).padding(.top, 4)
    }
}

/// The web's page head: the title, anything that sits under it, then the band.
struct PageHead<Extra: View>: View {
    let title: String
    let band: String
    var back: (() -> Void)? = nil
    var backText = ""
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let back { BackLink(text: backText, action: back) }
            Text(title).font(Theme.title(30)).foregroundStyle(Theme.ink).padding(.top, 8).padding(.bottom, 12)
            extra
            Band(kind: band).padding(.top, 14).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension PageHead where Extra == EmptyView {
    init(title: String, band: String, back: (() -> Void)? = nil, backText: String = "") {
        self.init(title: title, band: band, back: back, backText: backText, extra: { EmptyView() })
    }
}

// MARK: - text

/// The web's .lede: 15.5 ink-2 with a tall line, or the small 14 one.
struct Lede: View {
    let text: String
    var small = false
    var body: some View {
        Text(text).font(Theme.body(small ? 14 : 15.5)).foregroundStyle(Theme.ink2).lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, small ? 10 : 14)
    }
}

struct Fine: View {
    let text: String
    var body: some View { Text(text).font(Theme.body(13)).foregroundStyle(Theme.ink3).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 18) }
}

/// The web's small heading over a group of rows: 13 bold, ink-3.
struct SmallHead: View {
    let text: String
    var top: CGFloat = 22
    var body: some View { Text(text).font(Theme.body(13, "Bold")).foregroundStyle(Theme.ink3).frame(maxWidth: .infinity, alignment: .leading).padding(.top, top).padding(.bottom, 8) }
}

/// The web's field label: 13.5 bold, 14 above, 7 below.
struct FieldLabel: View {
    let text: String
    var body: some View { Text(text).font(Theme.body(13.5, "Bold")).foregroundStyle(Theme.ink2).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14).padding(.bottom, 7) }
}

/// The web's .sec: a 20 Kufi heading with an optional count, 26 above and 10 below.
struct SectionTitle: View {
    let text: String
    var count: Int? = nil
    var body: some View {
        HStack {
            Text(text).font(Theme.title(20)).foregroundStyle(Theme.ink)
            Spacer()
            if let count, count > 0 { CountPill(count: count) }
        }
        .padding(.top, 26).padding(.bottom, 10)
    }
}

struct CountPill: View {
    let count: Int
    var body: some View {
        Text(String(count)).font(Theme.body(13, "Bold")).foregroundStyle(Theme.overdue)
            .padding(.horizontal, 8).frame(minWidth: 26, minHeight: 26).background(Theme.overdue.opacity(0.11), in: Capsule())
    }
}

/// The web's weave: a 5 point line under a row showing how much of the cycle has passed.
struct ProgressLine: View {
    let value: Double
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.08))
                Capsule().fill(color).frame(width: g.size.width * min(max(value, 0), 1))
            }
        }
        .frame(maxWidth: 240).frame(height: 5).padding(.top, 5)
    }
}

// MARK: - buttons

/// The web's .btn: 48 tall, 14 corners, 15 semibold; primary is filled ink, quiet has no frame.
struct WideButton: View {
    let title: String
    var primary = true
    var danger = false
    var quiet = false
    var icon: String? = nil
    var height: CGFloat = 48
    var block = true
    let action: () -> Void

    var body: some View {
        let filled = primary && !danger && !quiet
        let bare = quiet || danger
        let ink: Color = danger ? Theme.overdue : filled ? Theme.onInk : quiet ? Theme.ink2 : Theme.ink
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: Symbol.name(icon)).font(.system(size: 15, weight: .semibold)) }
                Text(title).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(Theme.body(15, "SemiBold")).foregroundStyle(ink)
            .padding(.horizontal, 18).frame(height: height).frame(maxWidth: block ? .infinity : nil)
            .background(filled ? Theme.ink : bare ? Color.clear : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: filled || bare ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

/// The web's .actions.two: two equal buttons side by side.
struct ButtonPair: View {
    let a: String
    let onA: () -> Void
    let b: String
    let onB: () -> Void
    var aPrimary = false
    var aIcon: String? = nil
    var bIcon: String? = nil
    var bQuiet = false
    var bDanger = false
    var height: CGFloat = 48
    var body: some View {
        HStack(spacing: 10) {
            WideButton(title: a, primary: aPrimary, icon: aIcon, height: height, action: onA)
            WideButton(title: b, primary: false, danger: bDanger, quiet: bQuiet, icon: bIcon, height: height, action: onB)
        }
    }
}

// MARK: - inputs

/// The web's .input: 48 tall, 13 corners, on the page colour.
struct Input: View {
    @Binding var text: String
    let placeholder: String
    var numbers = false
    var phone = false
    var password = false
    var body: some View {
        Group {
            if password { SecureField(placeholder, text: $text) } else { TextField(placeholder, text: $text) }
        }
        .font(Theme.body(16)).foregroundStyle(Theme.ink)
        .keyboardType(password ? .default : phone ? .phonePad : numbers ? .decimalPad : .default)
        .environment(\.layoutDirection, phone || password ? .leftToRight : .rightToLeft)
        .padding(.horizontal, 14).frame(height: 48)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// The web's .segc: equal parts in one tray, the chosen one raised.
struct Seg: View {
    let options: [(String, String)]
    let selected: String
    var compact = false
    let onSelect: (String) -> Void
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selected
                Button { onSelect(value) } label: {
                    Text(label).font(Theme.body(14, on ? "Bold" : "Medium")).foregroundStyle(on ? Theme.ink : Theme.ink2)
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .padding(.horizontal, compact ? 12 : 6).frame(maxWidth: compact ? nil : .infinity).frame(height: 38)
                        .background(on ? Theme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: on ? Color.black.opacity(0.14) : .clear, radius: 1.5, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// One of the web's chips, given the width of its column so every chip in a group is the same size.
struct ChoiceCell: View {
    let title: String
    var icon: String? = nil
    let on: Bool
    var small = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: Symbol.name(icon)).font(.system(size: 14)) }
                Text(title).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(Theme.body(small ? 14 : 14.5, on ? "SemiBold" : "Regular")).foregroundStyle(on ? Theme.onInk : Theme.ink2)
            .padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: small ? 36 : 40)
            .background(on ? Theme.ink : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(on ? Theme.ink : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Chips in equal columns; a short last row keeps its chips the same width.
struct ChoiceGrid<T: Hashable>: View {
    let items: [T]
    var columns = 3
    let isOn: (T) -> Bool
    let label: (T) -> String
    var icon: (T) -> String? = { _ in nil }
    var small = false
    let action: (T) -> Void
    var body: some View {
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { x in ChoiceCell(title: label(x), icon: icon(x), on: isOn(x), small: small) { action(x) } }
                    ForEach(0..<(columns - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity).frame(height: 1) }
                }
            }
        }
    }
}

/// The web's select: an input-shaped dropdown.
struct Select: View {
    let value: String
    let options: [(String, String)]
    var width: CGFloat? = nil
    let onSelect: (String) -> Void
    var body: some View {
        Menu {
            ForEach(options, id: \.0) { v, label in
                Button { onSelect(v) } label: { if v == value { Label(label, systemImage: "checkmark") } else { Text(label) } }
            }
        } label: {
            HStack(spacing: 6) {
                Text(options.first { $0.0 == value }?.1 ?? value).font(Theme.body(16)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 14).frame(height: 48).frame(maxWidth: width == nil ? .infinity : nil).frame(width: width)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }
}

/// A date field shaped like the web's input; it opens the calendar in a sheet.
struct DayField: View {
    @EnvironmentObject var model: AppModel
    let label: String
    @Binding var day: Day
    var body: some View {
        DayFieldBody(label: label, day: $day, lang: model.lang)
    }
}

private struct DayFieldBody: View {
    let label: String
    @Binding var day: Day
    let lang: String
    @State private var open = false
    @State private var picked = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldLabel(text: label)
            Button { picked = DayFieldBody.date(of: day); open = true } label: {
                HStack {
                    Text("\(formatDate(day, lang, refYear: 0)) \(day.ymd.y)").font(Theme.body(16)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    Image(systemName: "calendar").font(.system(size: 15)).foregroundStyle(Theme.ink3)
                }
                .padding(.horizontal, 14).frame(height: 48)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $open) {
            VStack {
                DatePicker("", selection: $picked, displayedComponents: .date).datePickerStyle(.graphical).tint(Theme.ink).padding()
                WideButton(title: "OK") {
                    let c = Calendar.current.dateComponents([.year, .month, .day], from: picked)
                    day = Day(y: c.year!, m: c.month!, d: c.day!)
                    open = false
                }
                .padding(.horizontal, 20)
            }
            .presentationDetents([.medium])
        }
    }

    static func date(of day: Day) -> Date {
        let p = day.ymd
        return Calendar.current.date(from: DateComponents(year: p.y, month: p.m, day: p.d)) ?? Date()
    }
}

// MARK: - rows and cards

struct ListCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct CardBox<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct RowLine: View {
    var body: some View { Rectangle().fill(Theme.line).frame(height: 1) }
}

/// The icon square at the start of a row.
struct RowIcon: View {
    let icon: String
    let tint: Color
    let bg: Color
    var body: some View {
        Image(systemName: Symbol.name(icon)).font(.system(size: 17, weight: .medium)).foregroundStyle(tint)
            .frame(width: 42, height: 42).background(bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

/// A tag inside a row's meta line, as the web's .asset.
struct MetaTag: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.body(12, "SemiBold")).foregroundStyle(Theme.ink2).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 1).background(Theme.ink.opacity(0.07), in: Capsule())
    }
}

/// A chevron that points forward in both directions of reading.
struct Chevron: View {
    @EnvironmentObject var model: AppModel
    var tint: Color = Theme.ink3
    var body: some View { Image(systemName: model.isArabic ? "chevron.left" : "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(tint) }
}

/// The web's .nav-row: icon, label, an optional count, and the chevron.
struct NavRow: View {
    let icon: String
    let label: String
    var count: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RowIcon(icon: icon, tint: Theme.ink, bg: Theme.ink.opacity(0.06))
                Text(label).font(Theme.body(16, "SemiBold")).foregroundStyle(Theme.ink)
                Spacer()
                if let count { MetaTag(text: count) }
                Chevron()
            }
            .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The web's .setting: label with its icon at the start, the control at the end, a line below.
struct SettingRow<Control: View>: View {
    let icon: String
    let label: String
    @ViewBuilder var control: Control
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: Symbol.name(icon)).font(.system(size: 16)).foregroundStyle(Theme.ink3)
                    Text(label).font(Theme.body(16, "SemiBold")).foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 8)
                control
            }
            .padding(.vertical, 14)
            RowLine()
        }
    }
}

/// The web's .empty: a dashed card with an icon and a line; big adds a button.
struct EmptyNote<Extra: View>: View {
    let icon: String
    let text: String
    var big = false
    @ViewBuilder var extra: Extra
    var body: some View {
        VStack(spacing: big ? 14 : 10) {
            Image(systemName: Symbol.name(icon)).font(.system(size: big ? 34 : 26)).foregroundStyle(big ? Theme.ink3 : Theme.ok)
            Text(text).font(Theme.body(16)).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
            extra
        }
        .frame(maxWidth: .infinity).padding(.horizontal, big ? 22 : 20).padding(.vertical, big ? 40 : 28)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: big ? [] : [6, 5])))
    }
}

extension EmptyNote where Extra == EmptyView {
    init(icon: String, text: String, big: Bool = false) { self.init(icon: icon, text: text, big: big, extra: { EmptyView() }) }
}

/// Toggle rows inside a card, as the web's feature and trial switches.
struct SwitchCard: View {
    let rows: [(String, Binding<Bool>)]
    var body: some View {
        ListCard {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if i > 0 { RowLine() }
                Toggle(isOn: row.1) { Text(row.0).font(Theme.body(15.5)).foregroundStyle(Theme.ink) }
                    .tint(Theme.ok).padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
    }
}

/// The web's .facts: small framed boxes, two to a row.
struct Facts: View {
    let items: [(String, String)]
    var body: some View {
        let rows = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, f in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.0).font(Theme.body(12.5, "SemiBold")).foregroundStyle(Theme.ink3)
                            Text(f.1).font(Theme.body(14.5, "SemiBold")).foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    }
                    if row.count == 1 { Color.clear.frame(maxWidth: .infinity).frame(height: 1) }
                }
            }
        }
        .padding(.top, 14)
    }
}

/// The frame of every sheet: the web's close button and title, on the surface colour.
struct SheetFrame<Content: View>: View {
    @EnvironmentObject var model: AppModel
    let title: String?
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let title { Text(title).font(Theme.title(22)).foregroundStyle(Theme.ink).padding(.trailing, 44) }
                    content
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 34)
            }
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink2)
                    .frame(width: 40, height: 40).background(Theme.ink.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain).padding(12)
        }
        .background(Theme.surface)
        .environment(\.layoutDirection, model.isArabic ? .rightToLeft : .leftToRight)
    }
}
