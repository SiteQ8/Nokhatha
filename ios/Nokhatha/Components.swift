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
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Theme.body(16, "SemiBold")).frame(maxWidth: .infinity).frame(height: 50)
                .foregroundStyle(danger ? Theme.overdue : primary ? Theme.onInk : Theme.ink)
                .background(primary && !danger ? Theme.ink : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: primary && !danger ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
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
