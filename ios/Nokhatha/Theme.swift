// The web identity on iPhone: pearl, night, Sadu red, sea and ripe dates, light and dark.
import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

enum Theme {
    static let bg = Color.adaptive(0xEEF1F4, 0x121728)
    static let surface = Color.adaptive(0xFFFFFF, 0x1B2238)
    static let ink = Color.adaptive(0x1C2340, 0xEEF1F4)
    static let ink2 = Color.adaptive(0x3A4263, 0xBAC1D5)
    static let ink3 = Color.adaptive(0x5F6886, 0x8B94AE)
    static let line = Color.adaptive(0xD9DEE7, 0x2B3453)
    static let sadu = Color.adaptive(0xA4262C, 0xD8474D)
    static let overdue = Color.adaptive(0xA4262C, 0xE8676C)
    static let soon = Color.adaptive(0xC98A1B, 0xE7AF4B)
    static let soonInk = Color.adaptive(0x8C5A08, 0xE7AF4B)
    static let ok = Color.adaptive(0x127A74, 0x41B8AC)
    static let onInk = Color.adaptive(0xEEF1F4, 0x121728)
    static let gold = Color(hex: 0xC98A1B)
    static let rutab = Color.adaptive(0xC98A1B, 0xE7AF4B)
    static let sand = Color.adaptive(0xE4D8C4, 0x121728)
    static let bandInk = Color.adaptive(0x1C2340, 0xEEF1F4)

    /// The soft background behind a row's icon, as the web's tint colours.
    static func tintBg(_ status: String) -> Color { tint(status).opacity(0.12) }

    static let safari = Color.adaptive(0xA3C8C8, 0x204750)
    static let shita = Color.adaptive(0xB8BCC8, 0x363C50)
    static let rabi = Color.adaptive(0xC0CEBD, 0x394841)
    static let qaith = Color.adaptive(0xE1CCA6, 0x564833)

    static func tint(_ status: String) -> Color {
        switch status {
        case "overdue": return overdue
        case "today", "soon": return soonInk
        case "unset", "off": return ink3
        default: return ok
        }
    }

    static func group(_ g: String) -> Color {
        switch g {
        case "safari": return safari
        case "shita": return shita
        case "rabi": return rabi
        default: return qaith
        }
    }

    static func display(_ size: CGFloat) -> Font { .custom("ReemKufi-Bold", size: size) }
    static func title(_ size: CGFloat) -> Font { .custom("ReemKufi-SemiBold", size: size) }
    static func body(_ size: CGFloat = 16, _ weight: String = "Regular") -> Font { .custom("IBMPlexSansArabic-\(weight)", size: size) }
}

/// SF Symbols for the icon names the templates and the web app use.
enum Symbol {
    static let map: [String: String] = [
        "today": "circle.circle", "home": "house", "car": "car", "repeat": "arrow.triangle.2.circlepath", "more": "ellipsis",
        "filter": "square.grid.3x3", "ac": "air.conditioner.horizontal", "duct": "wind", "tank": "cylinder", "drop": "drop",
        "heater": "flame", "leak": "drop.triangle", "roof": "house.lodge", "window": "window.vertical.closed", "smoke": "smoke",
        "extinguisher": "fire.extinguisher", "gas": "flame", "hood": "fan", "bug": "ant", "bolt": "bolt", "oil": "oilcan",
        "air": "wind", "fan": "fanblades", "snow": "snowflake", "thermo": "thermometer.high", "tire": "circle.circle",
        "gauge": "gauge.with.dots.needle.33percent", "brake": "circle.dashed", "battery": "minus.plus.batteryblock",
        "wiper": "windshield.front.and.wiper", "doc": "doc.text", "shield": "checkmark.shield", "check": "checklist",
        "wrench": "wrench.and.screwdriver", "seal": "seal", "plane": "airplane", "wallet": "wallet.pass", "receipt": "receipt",
        "boat": "sailboat", "bike": "scooter", "waves": "water.waves", "leaf": "leaf", "tent": "tent", "paw": "pawprint",
        "box": "shippingbox", "dust": "aqi.medium", "rain": "cloud.rain", "sun": "sun.max", "spark": "sparkle", "bell": "bell",
        "play": "play.circle", "music": "music.note", "cloud": "cloud", "game": "gamecontroller", "gym": "dumbbell",
        "wifi": "wifi", "phone": "phone", "apps": "square.grid.2x2", "close": "xmark", "plus": "plus", "edit": "pencil", "trash": "trash",
        "sliders": "slider.horizontal.3", "info": "info.circle", "chat": "message", "globe": "globe", "snooze": "clock.badge",
        "calendar": "calendar", "lock": "lock", "upload": "square.and.arrow.up", "download": "square.and.arrow.down", "code": "chevron.left.forwardslash.chevron.right",
        "camera": "camera", "photo": "photo.on.rectangle", "done": "checkmark", "next": "chevron.right", "back": "chevron.left",
        "id": "person.text.rectangle", "passport": "book.closed", "licence": "creditcard", "stamp": "checkmark.seal", "heart": "heart",
        "briefcase": "briefcase", "alert": "exclamationmark.triangle", "link": "arrow.up.right.square",
    ]
    static func name(_ icon: String) -> String { map[icon] ?? "sparkle" }
}
