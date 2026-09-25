// The bundled data (the same files the web app reads) and the person's state.
// AppState reads and writes exactly the JSON the web app keeps, so a backup made
// on the web opens on the iPhone and the other way round.

import Foundation

// MARK: - Catalog: docs/data/*.json

public struct Template: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let kind: String
    public let area: String
    public let icon: String
    public let trade: String?
    public let isDefault: Bool
    public let needs: String?
    public let forType: String?
    public let every: Every
    public let ar: String
    public let en: String
    public let why_ar: String
    public let why_en: String

    enum CodingKeys: String, CodingKey {
        case id, kind, area, icon, trade, needs, every, ar, en, why_ar, why_en
        case isDefault = "default"
        case forType = "for"
    }

    public func name(_ lang: String) -> String { lang == "ar" ? ar : en }
    public func why(_ lang: String) -> String { lang == "ar" ? why_ar : why_en }
}

public struct Named: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let ar: String
    public let en: String
    public let icon: String?
    public func name(_ lang: String) -> String { lang == "ar" ? ar : en }
}

public struct Place: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let country: String
    public let ar: String
    public let en: String
    public let lat: Double
    public let lon: Double
    public func name(_ lang: String) -> String { lang == "ar" ? ar : en }
}

struct TasksDoc: Codable {
    let templates: [Template]
    let areas: [String: [Named]]
    let trades: [Named]
    let travel: [Named]
    let thingTypes: [Named]
}

struct SeasonsDoc: Codable {
    let seasons: [Season]
    let groups: [String: [String: String]]
    let bawarih: Window
}

struct PlacesDoc: Codable { let places: [Place] }

public struct Catalog: Sendable {
    public let seasons: [Season]
    public let groups: [String: [String: String]]
    public let bawarih: Window
    public let templates: [Template]
    public let areas: [String: [Named]]
    public let trades: [Named]
    public let travel: [Named]
    public let thingTypes: [Named]
    public let places: [Place]
    public let strings: [String: [String: String]]

    public var template: [String: Template] { Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) }) }
    public func season(_ id: String) -> Season? { seasons.first { $0.id == id } }

    /// Reads seasons.json, tasks.json, strings.json and places.json from a folder.
    public static func load(from dir: URL) throws -> Catalog {
        func read<T: Decodable>(_ name: String, _ type: T.Type) throws -> T {
            try JSONDecoder().decode(T.self, from: Data(contentsOf: dir.appendingPathComponent(name)))
        }
        let s = try read("seasons.json", SeasonsDoc.self)
        let t = try read("tasks.json", TasksDoc.self)
        let p = try read("places.json", PlacesDoc.self)
        let strings = try read("strings.json", [String: [String: String]].self)
        return Catalog(seasons: s.seasons, groups: s.groups, bawarih: s.bawarih, templates: t.templates, areas: t.areas,
                       trades: t.trades, travel: t.travel, thingTypes: t.thingTypes, places: p.places, strings: strings)
    }
}

// MARK: - State, in the web app's shape

public struct LogEntry: Codable, Hashable, Sendable {
    public var date: String
    public var cost: Int?
    public var cur: String?
    public var km: Int?
    public init(date: String, cost: Int? = nil, cur: String? = nil, km: Int? = nil) {
        self.date = date; self.cost = cost; self.cur = cur; self.km = km
    }
}

public struct Item: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var asset: String
    public var tpl: String?
    public var enabled: Bool?
    public var lastDone: String?
    public var lastKm: Int?
    public var due: String?
    public var snoozeUntil: String?
    public var firstDue: String?
    public var title: String?
    public var every: Every?
    public var log: [LogEntry]?

    public init(id: String, asset: String, tpl: String?, title: String? = nil, every: Every? = nil) {
        self.id = id; self.asset = asset; self.tpl = tpl; self.enabled = true; self.title = title; self.every = every; self.log = []
    }

    public var isOn: Bool { enabled != false }
}

public struct Home: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: String? = "home"
    public var type: String
    public var name: String
    public var features: [String: Bool]?
}

public struct Car: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: String? = "car"
    public var name: String
    public var dailyKm: Int?
    public var readings: [Reading]?

    public var odometer: CarOdometer { CarOdometer(dailyKm: dailyKm ?? Engine.defaultDailyKm, readings: readings ?? []) }
}

public struct Thing: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: String? = "thing"
    public var type: String
    public var name: String
}

public struct Sub: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var amount: Int
    public var currency: String
    public var cycle: String
    public var anchor: String
    public var category: String?
    public var usage: [String: String]?
    public var trial: Bool?
    public var note: String?
    public var cancelled: Bool?
    public var cancelledOn: String?
}

public struct Warranty: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var store: String?
    public var bought: String
    public var months: Int
    public var receipt: String?
}

public struct Tech: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var trade: String
    public var phone: String
    public var note: String?
}

public struct WeatherSetting: Codable, Hashable, Sendable {
    public var on: Bool?
    public var place: String?
    public var lat: Double?
    public var lon: Double?
}

public struct Settings: Codable, Hashable, Sendable {
    public var lang = "ar"
    public var country = "KW"
    public var theme = "auto"
    public var currency = "KWD"
    public var lead = 7
    public var onboarded = false
    public var notify: Bool?
    public var lastBackup: String?
    public var weather: WeatherSetting?
    public var installTipOff: Bool?

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lang = try c.decodeIfPresent(String.self, forKey: .lang) ?? "ar"
        country = try c.decodeIfPresent(String.self, forKey: .country) ?? "KW"
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? "auto"
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "KWD"
        lead = try c.decodeIfPresent(Int.self, forKey: .lead) ?? 7
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify)
        lastBackup = try c.decodeIfPresent(String.self, forKey: .lastBackup)
        weather = try c.decodeIfPresent(WeatherSetting.self, forKey: .weather)
        installTipOff = try c.decodeIfPresent(Bool.self, forKey: .installTipOff)
    }
}

public struct Travel: Codable, Hashable, Sendable {
    public var done: [String] = []
}

public struct AppState: Codable, Hashable, Sendable {
    public var v = 1
    public var settings = Settings()
    public var homes: [Home] = []
    public var cars: [Car] = []
    public var things: [Thing] = []
    public var items: [Item] = []
    public var subs: [Sub] = []
    public var warranties: [Warranty] = []
    public var techs: [Tech] = []
    public var travel = Travel()
    public var sample: Bool?

    public init(lang: String = "ar") { settings.lang = lang }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = try c.decodeIfPresent(Int.self, forKey: .v) ?? 1
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        homes = try c.decodeIfPresent([Home].self, forKey: .homes) ?? []
        cars = try c.decodeIfPresent([Car].self, forKey: .cars) ?? []
        things = try c.decodeIfPresent([Thing].self, forKey: .things) ?? []
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        subs = try c.decodeIfPresent([Sub].self, forKey: .subs) ?? []
        warranties = try c.decodeIfPresent([Warranty].self, forKey: .warranties) ?? []
        techs = try c.decodeIfPresent([Tech].self, forKey: .techs) ?? []
        travel = try c.decodeIfPresent(Travel.self, forKey: .travel) ?? Travel()
        sample = try c.decodeIfPresent(Bool.self, forKey: .sample)
    }

    public var isEmpty: Bool { homes.isEmpty && cars.isEmpty && things.isEmpty && subs.isEmpty }
}

public func newID() -> String {
    (0..<6).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
}
