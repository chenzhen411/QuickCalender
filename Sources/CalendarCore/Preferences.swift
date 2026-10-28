import Foundation

public enum StatusStyle: String, CaseIterable, Identifiable, Codable {
    case standard, compact, full
    public var id: String { rawValue }
    public var title: String {
        switch self { case .standard: return "经典"; case .compact: return "简约"; case .full: return "完整" }
    }
}

public struct WeatherCity: Codable, Hashable, Identifiable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let timezone: String
    public var id: String { "\(latitude),\(longitude)" }
    public init(name: String, latitude: Double, longitude: Double, timezone: String = "Asia/Shanghai") {
        self.name = name; self.latitude = latitude; self.longitude = longitude; self.timezone = timezone
    }
    public static let presets = [
        WeatherCity(name: "上海", latitude: 31.2304, longitude: 121.4737),
        WeatherCity(name: "北京", latitude: 39.9042, longitude: 116.4074),
        WeatherCity(name: "杭州", latitude: 30.2741, longitude: 120.1551),
        WeatherCity(name: "深圳", latitude: 22.5431, longitude: 114.0579),
        WeatherCity(name: "广州", latitude: 23.1291, longitude: 113.2644),
        WeatherCity(name: "成都", latitude: 30.5728, longitude: 104.0668)
    ]
}

public struct Preferences: Codable {
    public var statusStyle: StatusStyle = .standard
    public var showSeconds = false
    public var use24Hour = true
    public var showStatusIcon = true
    public var showLunar = true
    public var showFestivals = true
    public var showWeather = true
    public var showDayWeather = true
    public var mondayFirst = true
    public var appearance = "system"
    public var city = WeatherCity.presets[0]
    public init() {}

    public func statusLabel(at date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = timeZone
        let time = (use24Hour ? "HH:mm" : "a h:mm") + (showSeconds ? ":ss" : "")
        switch statusStyle {
        case .standard: f.dateFormat = "M月d日 EEE  " + time
        case .compact: f.dateFormat = "M/d EEE " + time
        case .full: f.dateFormat = "yyyy年M月d日 EEEE  " + time
        }
        return f.string(from: date)
    }
}
