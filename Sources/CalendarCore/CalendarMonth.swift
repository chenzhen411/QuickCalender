import Foundation

public struct CalendarDay: Identifiable {
    public var id: Date { date }
    public let date: Date
    public let key: String
    public let number: Int
    public let lunar: String
    public let fullLunar: String
    public let festivals: [String]
    public let accessibleDate: String
}

/// Immutable date metadata shared by cells, tooltips, and the selected-day detail.
public final class CalendarMonth {
    public let days: [CalendarDay]

    fileprivate init(month: Date, engine: CalendarEngine) {
        let formatter = DateFormatter()
        formatter.calendar = engine.calendar
        formatter.timeZone = engine.calendar.timeZone
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        days = engine.days(in: month).map { date in
            CalendarDay(date: date, key: engine.dayKey(date),
                        number: engine.calendar.component(.day, from: date),
                        lunar: engine.lunarLabel(date), fullLunar: engine.lunarLabel(date, full: true),
                        festivals: engine.festivals(date), accessibleDate: formatter.string(from: date))
        }
    }
}

/// Main-thread-owned cache. Clock ticks, selection, and weather updates reuse metadata.
public final class CalendarMonthCache {
    private struct Key: Equatable {
        let month: Date
        let timeZone: String
        let firstWeekday: Int
    }
    private var entries: [(key: Key, month: CalendarMonth)] = []
    private let capacity: Int

    public init(capacity: Int = 6) { self.capacity = max(1, capacity) }

    public func month(containing date: Date, engine: CalendarEngine) -> CalendarMonth {
        let key = Key(month: engine.monthStart(date), timeZone: engine.calendar.timeZone.identifier,
                      firstWeekday: engine.calendar.firstWeekday)
        if let index = entries.firstIndex(where: { $0.key == key }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.month
        }
        let month = CalendarMonth(month: key.month, engine: engine)
        entries.append((key, month))
        if entries.count > capacity { entries.removeFirst() }
        return month
    }
}
