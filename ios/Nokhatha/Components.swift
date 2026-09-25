// Small shared pieces: chips that wrap, labelled fields, wide buttons.
import SwiftUI

struct Flow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { y += row + spacing; x = 0; row = 0 }
            x += s.width + spacing
            row = max(row, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + row)
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > b.minX && x + s.width > b.maxX { y += row + spacing; x = b.minX; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            row = max(row, s.height)
        }
    }
}

struct Chip: View {
    let title: String
    var icon: String? = nil
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: Symbol.name(icon)).font(.system(size: 14)) }
                Text(title)
            }
            .font(Theme.body(14.5, on ? "SemiBold" : "Regular"))
            .foregroundStyle(on ? Theme.onInk : Theme.ink2)
            .padding(.horizontal, 14).frame(height: 40)
            .background(on ? Theme.ink : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(on ? Theme.ink : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View { Text(text).font(Theme.body(13.5, "Bold")).foregroundStyle(Theme.ink2).padding(.top, 14) }
}

struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var numbers = false
    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.body(16))
            .keyboardType(numbers ? .decimalPad : .default)
            .padding(.horizontal, 14).frame(height: 48)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct WideButton: View {
    let title: String
    var primary = true
    var danger = false
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: Symbol.name(icon)).font(.system(size: 16, weight: .semibold)) }
                Text(title).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(Theme.body(16, "SemiBold")).padding(.horizontal, 12).frame(maxWidth: .infinity).frame(height: 50)
            .foregroundStyle(danger ? Theme.overdue : primary ? Theme.onInk : Theme.ink)
            .background(primary && !danger ? Theme.ink : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: primary && !danger ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

/// One choice in a grid: every cell the same width and height, whatever its words.
struct ChoiceCell: View {
    let title: String
    var icon: String? = nil
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: Symbol.name(icon)).font(.system(size: 14)) }
                Text(title).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(Theme.body(14.5, on ? "SemiBold" : "Regular"))
            .foregroundStyle(on ? Theme.onInk : Theme.ink2)
            .padding(.horizontal, 8).frame(maxWidth: .infinity).frame(height: 46)
            .background(on ? Theme.ink : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? Theme.ink : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Choices in equal columns, as the web lays them out.
struct ChoiceGrid<T: Hashable>: View {
    let items: [T]
    var columns = 3
    let isOn: (T) -> Bool
    let label: (T) -> String
    var icon: (T) -> String? = { _ in nil }
    let action: (T) -> Void
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(items, id: \.self) { x in ChoiceCell(title: label(x), icon: icon(x), on: isOn(x)) { action(x) } }
        }
    }
}

/// A card that holds rows separated by lines.
struct ListCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct RowLine: View {
    var body: some View { Divider().overlay(Theme.line) }
}

/// A row that opens a page: icon, label, an optional count, and the chevron.
struct NavRow<Destination: View>: View {
    @EnvironmentObject var model: AppModel
    let icon: String
    let label: String
    var count: String? = nil
    @ViewBuilder let destination: Destination
    var body: some View {
        NavigationLink { destination } label: {
            HStack(spacing: 12) {
                Image(systemName: Symbol.name(icon)).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42).background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(label).font(Theme.body(16, "SemiBold")).foregroundStyle(Theme.ink)
                Spacer()
                if let count {
                    Text(verbatim: count).font(Theme.body(13, "Bold")).foregroundStyle(Theme.ink2)
                        .padding(.horizontal, 10).frame(height: 24).background(Theme.ink.opacity(0.07), in: Capsule())
                }
                Image(systemName: model.isArabic ? "chevron.left" : "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

/// One setting: icon and name on one side, its control on the other, every control the same width.
struct SettingRow<Control: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let control: Control
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: Symbol.name(icon)).font(.system(size: 16)).foregroundStyle(Theme.ink2)
            Text(label).font(Theme.body(15, "SemiBold")).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            control.frame(width: 196)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

struct Lede: View {
    let text: String
    var small = false
    var body: some View { Text(text).font(Theme.body(small ? 14 : 15)).foregroundStyle(Theme.ink2).lineSpacing(4).padding(.top, 6) }
}

struct SmallHead: View {
    let text: String
    var body: some View { Text(text).font(Theme.body(15, "Bold")).foregroundStyle(Theme.ink).padding(.top, 20).padding(.bottom, 2) }
}

struct EmptyNote: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: Symbol.name(icon)).font(.system(size: 34)).foregroundStyle(Theme.ink3)
            Text(text).font(Theme.body(15)).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22)
    }
}

/// The title of a page opened from More.
struct PageHead: View {
    let text: String
    var body: some View { Text(text).font(Theme.title(28)).foregroundStyle(Theme.ink).padding(.top, 4) }
}

/// Reads digits typed in Arabic or Western numerals.
func wholeNumber(_ s: String) -> Int? {
    let digits = s.unicodeScalars.compactMap { u -> Character? in
        switch u.value {
        case 0x30...0x39: return Character(u)
        case 0x0660...0x0669: return Character(Unicode.Scalar(u.value - 0x0660 + 0x30)!)
        case 0x06F0...0x06F9: return Character(Unicode.Scalar(u.value - 0x06F0 + 0x30)!)
        default: return nil
        }
    }
    return digits.isEmpty ? nil : Int(String(digits))
}
