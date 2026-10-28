import Foundation
import Testing
@testable import CalendarCore

struct CalendarCoreTests {
    let engine = CalendarEngine(timeZone: TimeZone(identifier: "Asia/Shanghai")!)

    @Test func testGridAlwaysHas42ConsecutiveDaysAndCorrectWeekStart() {
        for year in [1901, 2000, 2024, 2026, 2099] {
            for month in 1...12 {
                for monday in [true, false] {
                    let e = CalendarEngine(timeZone: TimeZone(identifier: "Asia/Shanghai")!, mondayFirst: monday)
                    let grid = e.days(in: e.date(year: year, month: month))
                    #expect(grid.count == 42)
                    #expect(e.calendar.component(.weekday, from: grid[0]) == (monday ? 2 : 1))
                    #expect(Set(grid).count == 42)
                    for index in 1..<grid.count {
                        #expect(e.calendar.dateComponents([.day], from: grid[index - 1], to: grid[index]).day == 1)
                    }
                    let count = grid.filter { e.calendar.component(.month, from: $0) == month }.count
                    #expect(count == e.calendar.range(of: .day, in: .month, for: e.date(year: year, month: month))!.count)
                }
            }
        }
    }

    @Test func testLunarFestivalsAndNewYearsEveAcrossShortAndLongLunarMonths() {
        let cases: [(Int, Int, Int, String)] = [
            (2024, 2, 9, "除夕"), (2024, 2, 10, "春节"),
            (2025, 1, 28, "除夕"), (2025, 1, 29, "春节"),
            (2026, 2, 16, "除夕"), (2026, 2, 17, "春节"),
            (2026, 3, 3, "元宵节"), (2026, 6, 19, "端午节"),
            (2026, 9, 25, "中秋节"), (2026, 10, 18, "重阳节"),
            (2026, 10, 1, "国庆节"), (2026, 4, 5, "清明节"),
            (2024, 4, 4, "清明节"), (2025, 4, 4, "清明节")
        ]
        for (year, month, day, expected) in cases {
            #expect(engine.festivals(engine.date(year: year, month: month, day: day)).contains(expected), "\(year)-\(month)-\(day) expected \(expected)")
        }
    }

    @Test func testLeapLunarMonthDoesNotRepeatFestival() {
        // 2023 has a leap second lunar month. Dragon Head day is only in regular month 2.
        #expect(engine.festivals(engine.date(year: 2023, month: 2, day: 21)).contains("龙抬头"))
        #expect(!(engine.festivals(engine.date(year: 2023, month: 3, day: 23)).contains("龙抬头")))
    }

    @Test func testLunarLabelAndLeapMonth() {
        #expect(engine.lunarLabel(engine.date(year: 2026, month: 2, day: 17), full: true) == "正月初一")
        #expect(engine.lunarLabel(engine.date(year: 2023, month: 3, day: 22)) == "闰二月")
        #expect(engine.lunarLabel(engine.date(year: 2026, month: 2, day: 16)) == "廿九")
    }

    @Test func testQingmingStaysWithinModernDateRange() {
        for year in 1901...2099 {
            let matches = (3...7).filter { engine.festivals(engine.date(year: year, month: 4, day: $0)).contains("清明节") }
            #expect(matches.count == 1)
            #expect((4...6).contains(matches.first ?? 0), "Qingming outside expected range in \(year)")
        }
    }

    @Test func testGridCrossesDSTWithoutSkippingDates() {
        let e = CalendarEngine(timeZone: TimeZone(identifier: "America/New_York")!)
        let grid = e.days(in: e.date(year: 2026, month: 3))
        #expect(Set(grid.map { e.dayKey($0) }).count == 42)
        #expect(grid.contains(e.date(year: 2026, month: 3, day: 8)))
    }

    @Test func testStatusStylesIncludeDateWeekdayTimeAndHonorSeconds() {
        let date = engine.calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 13, minute: 5, second: 9))!
        for style in StatusStyle.allCases {
            var p = Preferences(); p.statusStyle = style
            let label = p.statusLabel(at: date, timeZone: engine.calendar.timeZone)
            #expect(label.contains("28")); #expect(label.contains("三")); #expect(label.contains("13:05"))
            p.showSeconds = true
            #expect(p.statusLabel(at: date, timeZone: engine.calendar.timeZone).contains("13:05:09"))
            p.use24Hour = false
            #expect(p.statusLabel(at: date, timeZone: engine.calendar.timeZone).contains("1:05:09"))
        }
    }

    @Test func testPreferencesRoundTrip() throws {
        var p = Preferences(); p.showLunar = false; p.statusStyle = .full; p.city = WeatherCity.presets[1]
        let result = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        #expect(!(result.showLunar)); #expect(result.statusStyle == .full); #expect(result.city == p.city)
    }

    @Test func themeSelectionPersistsWithoutChangingStatusBarTime() throws {
        let date = engine.calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 13, minute: 5))!
        for theme in ["light", "dark", "system"] {
            var preferences = Preferences()
            preferences.appearance = theme
            let saved = try JSONEncoder().encode(preferences)
            let restored = try JSONDecoder().decode(Preferences.self, from: saved)
            #expect(restored.appearance == theme)
            #expect(restored.statusLabel(at: date, timeZone: engine.calendar.timeZone).contains("13:05"))
        }
    }

    @Test func testForecastDecodingNullsMissingDatesAndShortArrays() throws {
        let data = #"{"timezone":"Asia/Shanghai","current":{"temperature_2m":19.5,"weather_code":2},"daily":{"time":["2026-10-28","2026-10-29","2026-10-30"],"weather_code":[2,null,3],"temperature_2m_max":[23,24],"temperature_2m_min":[16,17],"precipitation_probability_max":[10,null]}}"#.data(using: .utf8)!
        let f = try JSONDecoder().decode(Forecast.self, from: data)
        #expect(f.day("2026-10-28")?.high == 23)
        #expect(f.day("2026-10-28")?.rain == 10)
        #expect(f.day("2026-10-29") == nil); #expect(f.day("2026-10-30") == nil); #expect(f.day("2020-01-01") == nil)
        #expect(WeatherCode.label(95) == "雷雨")
        #expect(WeatherCode.symbol(0, night: true) == "moon.stars.fill")
        #expect(WeatherCode.label(999) == "未知")
    }
}
