import Foundation

public struct Forecast: Decodable {
    public struct Current: Decodable {
        public let temperature_2m: Double?
        public let relative_humidity_2m: Int?
        public let apparent_temperature: Double?
        public let weather_code: Int?
        public let is_day: Int?
        public let wind_speed_10m: Double?
    }
    public struct Daily: Decodable {
        public let time: [String]
        public let weather_code: [Int?]
        public let temperature_2m_max: [Double?]
        public let temperature_2m_min: [Double?]
        public let precipitation_probability_max: [Int?]
    }
    public let timezone: String
    public let current: Current
    public let daily: Daily

    public func day(_ key: String) -> WeatherDay? {
        guard let i = daily.time.firstIndex(of: key), i < daily.weather_code.count,
              i < daily.temperature_2m_max.count, i < daily.temperature_2m_min.count,
              i < daily.precipitation_probability_max.count,
              let code = daily.weather_code[i], let high = daily.temperature_2m_max[i],
              let low = daily.temperature_2m_min[i] else { return nil }
        return WeatherDay(code: code, high: high, low: low, rain: daily.precipitation_probability_max[i])
    }
}

public struct WeatherDay {
    public let code: Int
    public let high: Double
    public let low: Double
    public let rain: Int?
}

public enum WeatherCode {
    public static func label(_ code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1, 2: return "多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51...57: return "毛毛雨"
        case 61...67: return "雨"
        case 71...77: return "雪"
        case 80...82: return "阵雨"
        case 85, 86: return "阵雪"
        case 95...99: return "雷雨"
        default: return "未知"
        }
    }
    public static func symbol(_ code: Int, night: Bool = false) -> String {
        switch code {
        case 0: return night ? "moon.stars.fill" : "sun.max.fill"
        case 1, 2: return night ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }
}

public enum WeatherError: LocalizedError {
    case response
    public var errorDescription: String? { "天气服务暂时不可用，请稍后重试。" }
}

public struct WeatherClient {
    public init() {}
    public func forecast(city: WeatherCity) async throws -> Forecast {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "timezone", value: city.timezone),
            URLQueryItem(name: "forecast_days", value: "16"),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,is_day,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max")
        ]
        return try await request(url.url!)
    }

    public func search(_ query: String) async throws -> [WeatherCity] {
        struct Result: Decodable {
            struct City: Decodable {
                let name: String; let latitude: Double; let longitude: Double
                let timezone: String?; let admin1: String?; let country: String?
            }
            let results: [City]?
        }
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [URLQueryItem(name: "name", value: query), URLQueryItem(name: "count", value: "8"), URLQueryItem(name: "language", value: "zh")]
        let result: Result = try await request(url.url!)
        return (result.results ?? []).map {
            WeatherCity(name: [$0.name, $0.admin1, $0.country].compactMap { $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: " · "), latitude: $0.latitude, longitude: $0.longitude, timezone: $0.timezone ?? "GMT")
        }
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw WeatherError.response }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
