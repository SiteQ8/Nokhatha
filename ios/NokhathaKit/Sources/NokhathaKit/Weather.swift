// Weather alerts for the Gulf, the same rules as the web's weather.js and Android's Weather.kt:
// Open-Meteo forecast and air quality, dust judged against the place's own last 60 days.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum Weather {
    public static let forecastBase = "https://api.open-meteo.com/v1/forecast"
    public static let airBase = "https://air-quality-api.open-meteo.com/v1/air-quality"
    public static let dustFloor = 150.0
    public static let rainMm = 0.5
    public static let rainChance = 50.0
    public static let heat = 48.0
    public static let cold = 4.0
    public static let gust = 60.0
    static let order = ["dust_heavy", "rain", "wind", "dust", "heat", "cold"]
    public static let icons = ["dust": "dust", "dust_heavy": "dust", "rain": "rain", "wind": "air", "heat": "thermo", "cold": "snow"]

    public struct DayWx: Codable, Hashable, Sendable {
        public var date: String
        public var tmax: Double?
        public var tmin: Double?
        public var rain: Double?
        public var chance: Double?
        public var gust: Double?
        public var dust: Int?
    }

    /// The reading at the time of the fetch: degrees, how it feels, humidity.
    public struct Now: Codable, Hashable, Sendable {
        public var temp: Int
        public var feels: Int?
        public var humidity: Int?
        public var time: String?
    }

    public struct Summary: Codable, Hashable, Sendable {
        public var days: [DayWx]
        public var dusty: Int
        public var heavy: Int
        public var history: Int
        public var now: Now?
    }

    public struct Alert: Hashable, Sendable {
        public let kind: String
        public let day: Int
        public let value: Int?
    }

    public static func urls(lat: Double, lon: Double) -> (forecast: URL, air: URL) {
        let at = "latitude=\(lat)&longitude=\(lon)&timezone=auto"
        return (URL(string: "\(forecastBase)?\(at)&current=temperature_2m,apparent_temperature,relative_humidity_2m&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_gusts_10m_max&forecast_days=3")!,
                URL(string: "\(airBase)?\(at)&hourly=pm10&past_days=60&forecast_days=3")!)
    }

    static func num(_ a: Any?, _ i: Int) -> Double? {
        guard let arr = a as? [Any], i < arr.count else { return nil }
        return arr[i] as? Double ?? (arr[i] as? Int).map(Double.init)
    }

    /// Daily maxima of dust per day, the thresholds from the days before the forecast, and the reading now.
    public static func summarize(forecast: [String: Any]?, air: [String: Any]?) -> Summary {
        var dust: [String: Double] = [:]
        if let hourly = air?["hourly"] as? [String: Any], let times = hourly["time"] as? [String] {
            for (i, t) in times.enumerated() {
                guard let v = num(hourly["pm10"], i) else { continue }
                let day = String(t.prefix(10))
                dust[day] = max(dust[day] ?? 0, v)
            }
        }
        var days: [DayWx] = []
        if let f = forecast?["daily"] as? [String: Any], let dates = f["time"] as? [String] {
            for (i, date) in dates.enumerated() {
                days.append(DayWx(date: date, tmax: num(f["temperature_2m_max"], i), tmin: num(f["temperature_2m_min"], i), rain: num(f["precipitation_sum"], i),
                                  chance: num(f["precipitation_probability_max"], i), gust: num(f["wind_gusts_10m_max"], i), dust: dust[date].map { Int($0.rounded()) }))
            }
        }
        let first = days.first?.date ?? "9999-12-31"
        let history = dust.keys.filter { $0 < first }.map { dust[$0]! }.sorted()
        let p90 = percentile(history, 0.9)
        let p97 = percentile(history, 0.97)
        let dusty = max(dustFloor, p90 ?? .infinity)
        let heavy = max(dusty * 1.25, p97 ?? .infinity)
        var now: Now? = nil
        if let c = forecast?["current"] as? [String: Any], let t = c["temperature_2m"] as? Double ?? (c["temperature_2m"] as? Int).map(Double.init) {
            let feels = (c["apparent_temperature"] as? Double ?? (c["apparent_temperature"] as? Int).map(Double.init)).map { Int($0.rounded()) }
            let hum = (c["relative_humidity_2m"] as? Double ?? (c["relative_humidity_2m"] as? Int).map(Double.init)).map { Int($0.rounded()) }
            now = Now(temp: Int(t.rounded()), feels: feels, humidity: hum, time: c["time"] as? String)
        }
        return Summary(days: days, dusty: roundOrMax(dusty), heavy: roundOrMax(heavy), history: history.count, now: now)
    }

    static func roundOrMax(_ v: Double) -> Int { v.isFinite ? Int(v.rounded()) : Int.max }

    static func percentile(_ sorted: [Double], _ p: Double) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let pos = p * Double(sorted.count - 1)
        let lo = Int(pos.rounded(.down)), hi = min(lo + 1, sorted.count - 1)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - Double(lo))
    }

    /// Alerts for today and tomorrow, most serious first.
    public static func alerts(_ s: Summary, today: Day) -> [Alert] {
        var out: [Alert] = []
        for (dayIndex, date) in [(0, today.iso), (1, today.adding(1).iso)] {
            guard let d = s.days.first(where: { $0.date == date }) else { continue }
            if let dust = d.dust, s.history >= 20 {
                if dust >= s.heavy { out.append(Alert(kind: "dust_heavy", day: dayIndex, value: nil)) }
                else if dust >= s.dusty { out.append(Alert(kind: "dust", day: dayIndex, value: nil)) }
            }
            if (d.rain ?? 0) >= rainMm || (d.chance ?? 0) >= rainChance { out.append(Alert(kind: "rain", day: dayIndex, value: nil)) }
            if (d.gust ?? 0) >= gust { out.append(Alert(kind: "wind", day: dayIndex, value: nil)) }
            if let t = d.tmax, t >= heat { out.append(Alert(kind: "heat", day: dayIndex, value: Int(t.rounded()))) }
            if let t = d.tmin, t <= cold { out.append(Alert(kind: "cold", day: dayIndex, value: Int(t.rounded()))) }
        }
        return out.sorted { a, b in a.day != b.day ? a.day < b.day : (order.firstIndex(of: a.kind) ?? 9) < (order.firstIndex(of: b.kind) ?? 9) }
    }

    /// Both feeds fetched and summarised; nil when either fails.
    public static func fetch(lat: Double, lon: Double) async -> Summary? {
        let u = urls(lat: lat, lon: lon)
        var req1 = URLRequest(url: u.forecast); req1.timeoutInterval = 12
        var req2 = URLRequest(url: u.air); req2.timeoutInterval = 12
        do {
            async let a = URLSession.shared.data(for: req1)
            async let b = URLSession.shared.data(for: req2)
            let (fa, fb) = try await (a, b)
            guard (fa.1 as? HTTPURLResponse)?.statusCode == 200, (fb.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let f = try JSONSerialization.jsonObject(with: fa.0) as? [String: Any]
            let air = try JSONSerialization.jsonObject(with: fb.0) as? [String: Any]
            return summarize(forecast: f, air: air)
        } catch { return nil }
    }
}

/// The cached weather, kept beside the app's state.
public struct WeatherCache: Codable, Hashable, Sendable {
    public var lat: Double
    public var lon: Double
    public var at: Double
    public var sum: Weather.Summary
    public init(lat: Double, lon: Double, at: Double, sum: Weather.Summary) { self.lat = lat; self.lon = lon; self.at = at; self.sum = sum }
}
