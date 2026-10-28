import AppKit
import CalendarCore
import Combine

@MainActor
final class AppModel: ObservableObject {
    static let storageKey = "QuickCalender.preferences.v1"
    @Published var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
            applyAppearance()
            if oldValue.city != preferences.city || oldValue.showWeather != preferences.showWeather {
                weatherTask?.cancel()
                forecast = nil; updatedAt = nil; weatherError = nil; loadingWeather = false
                if preferences.showWeather { refreshWeather() }
            }
        }
    }
    @Published var now = Date()
    @Published var displayedMonth = Date()
    @Published var selectedDate = Date()
    @Published var forecast: Forecast?
    @Published var updatedAt: Date?
    @Published var weatherError: String?
    @Published var loadingWeather = false
    private var weatherTask: Task<Void, Never>?
    private var requestID = UUID()
    var showSettings: (() -> Void)?

    private var calendarEngine = CalendarEngine()
    private let monthCache = CalendarMonthCache()
    var engine: CalendarEngine {
        if calendarEngine.calendar.firstWeekday != (preferences.mondayFirst ? 2 : 1)
            || calendarEngine.calendar.timeZone != TimeZone.current {
            calendarEngine = CalendarEngine(mondayFirst: preferences.mondayFirst)
        }
        return calendarEngine
    }
    var month: CalendarMonth { monthCache.month(containing: displayedMonth, engine: engine) }
    var selectedDay: CalendarDay {
        monthCache.month(containing: selectedDate, engine: engine).days.first(where: {
            engine.calendar.isDate($0.date, inSameDayAs: selectedDate)
        })!
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey), let saved = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = saved
        } else { preferences = Preferences() }
        applyAppearance()
        _ = month
    }

    func applyAppearance() {
        switch preferences.appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    func today() {
        let date = Date()
        let start = engine.monthStart(date)
        if displayedMonth != start { displayedMonth = start }
        if !engine.calendar.isDate(selectedDate, inSameDayAs: date) { selectedDate = date }
        if preferences.showSeconds || Int(now.timeIntervalSince1970 / 60) != Int(date.timeIntervalSince1970 / 60) { now = date }
    }

    func moveMonth(_ amount: Int) {
        let next = engine.calendar.date(byAdding: .month, value: amount, to: engine.monthStart(displayedMonth))!
        let year = engine.calendar.component(.year, from: next)
        guard (1901...2099).contains(year) else { return }
        displayedMonth = next; selectedDate = next
    }

    func jump(year: Int, month: Int) {
        displayedMonth = engine.date(year: year, month: month)
        selectedDate = displayedMonth
    }

    func select(_ date: Date) {
        guard (1901...2099).contains(engine.calendar.component(.year, from: date)) else { return }
        selectedDate = date
        if !engine.calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) { displayedMonth = engine.monthStart(date) }
    }

    func tick() {
        let date = Date()
        if !engine.calendar.isDate(now, inSameDayAs: date) { today() }
        if preferences.showSeconds || Int(now.timeIntervalSince1970 / 60) != Int(date.timeIntervalSince1970 / 60) {
            now = date
        }
        if preferences.showWeather && !loadingWeather && date.timeIntervalSince(updatedAt ?? .distantPast) > 1800 {
            // Failed requests retry at most once every five minutes.
            if date.timeIntervalSince(lastAttempt) > 300 { refreshWeather() }
        }
    }

    private var lastAttempt = Date.distantPast
    func refreshWeather() {
        guard preferences.showWeather else { loadingWeather = false; return }
        weatherTask?.cancel()
        let id = UUID(); requestID = id
        let city = preferences.city
        lastAttempt = Date(); loadingWeather = true; weatherError = nil
        weatherTask = Task { [weak self] in
            do {
                let result = try await WeatherClient().forecast(city: city)
                guard let self, !Task.isCancelled, self.requestID == id, self.preferences.showWeather, self.preferences.city == city else { return }
                self.forecast = result; self.updatedAt = Date(); self.loadingWeather = false
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.weatherError = "连接失败，点击重试"; self.loadingWeather = false
            }
        }
    }

    func weatherDay(for date: Date) -> WeatherDay? {
        // A calendar cell is a civil date in the user's calendar, even for a city abroad.
        forecast?.day(engine.dayKey(date))
    }
}
