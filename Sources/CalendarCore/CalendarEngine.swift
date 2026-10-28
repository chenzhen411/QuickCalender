import Foundation

public struct CalendarEngine {
    public var calendar: Calendar
    private var lunar: Calendar

    public init(timeZone: TimeZone = .current, mondayFirst: Bool = true) {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = mondayFirst ? 2 : 1
        lunar = Calendar(identifier: .chinese)
        lunar.timeZone = timeZone
    }

    public func monthStart(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    public func days(in month: Date) -> [Date] {
        let first = monthStart(month)
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: first)!
        return (0..<42).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }

    public func date(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func lunarLabel(_ date: Date, full: Bool = false) -> String {
        let c = lunar.dateComponents(in: lunar.timeZone, from: date)
        let months = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        let day = c.day ?? 1
        let month = "\(c.isLeapMonth == true ? "闰" : "")\(months[(c.month ?? 1) - 1])月"
        let label: String
        switch day {
        case 1...10: label = "初" + ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][day - 1]
        case 11...19: label = "十" + ["一", "二", "三", "四", "五", "六", "七", "八", "九"][day - 11]
        case 20: label = "二十"
        case 21...29: label = "廿" + ["一", "二", "三", "四", "五", "六", "七", "八", "九"][day - 21]
        default: label = "三十"
        }
        return full ? "\(month)\(label)" : (day == 1 ? month : label)
    }

    public func festivals(_ date: Date) -> [String] {
        let g = calendar.dateComponents([.year, .month, .day], from: date)
        let c = lunar.dateComponents(in: lunar.timeZone, from: date)
        let solar = ["1-1": "元旦", "3-8": "妇女节", "3-12": "植树节", "5-1": "劳动节", "5-4": "青年节", "6-1": "儿童节", "7-1": "建党节", "8-1": "建军节", "9-10": "教师节", "10-1": "国庆节"]
        let traditional = ["1-1": "春节", "1-15": "元宵节", "2-2": "龙抬头", "5-5": "端午节", "7-7": "七夕", "7-15": "中元节", "8-15": "中秋节", "9-9": "重阳节", "12-8": "腊八节", "12-23": "北方小年", "12-24": "南方小年"]
        var result: [String] = []
        if let value = solar["\(g.month!)-\(g.day!)"] { result.append(value) }
        if c.isLeapMonth != true, let value = traditional["\(c.month!)-\(c.day!)"] { result.append(value) }
        let next = calendar.date(byAdding: .day, value: 1, to: date)!
        let nc = lunar.dateComponents(in: lunar.timeZone, from: next)
        if nc.month == 1 && nc.day == 1 && nc.isLeapMonth != true { result.append("除夕") }
        // Qingming is the 15° solar-longitude crossing; calculate in China time.
        if g.month == 4, g.day == qingmingDay(year: g.year!) { result.append("清明节") }
        return result
    }

    private func qingmingDay(year: Int) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var low = utc.date(from: DateComponents(year: year, month: 4, day: 3))!.timeIntervalSince1970
        var high = low + 4 * 86400
        for _ in 0..<40 {
            let mid = (low + high) / 2
            let t = (mid / 86400 + 2440587.5 - 2451545.0) / 36525
            let rad = Double.pi / 180
            let m = (357.52911 + t * (35999.05029 - 0.0001537 * t)) * rad
            let l = 280.46646 + t * (36000.76983 + 0.0003032 * t)
            let c = (1.914602 - t * (0.004817 + 0.000014 * t)) * sin(m)
                + (0.019993 - 0.000101 * t) * sin(2 * m) + 0.000289 * sin(3 * m)
            let raw = (l + c - 0.00569 - 0.00478 * sin((125.04 - 1934.136 * t) * rad)).truncatingRemainder(dividingBy: 360)
            let longitude = (raw + 360).truncatingRemainder(dividingBy: 360)
            if longitude < 15 { low = mid } else { high = mid }
        }
        utc.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return utc.component(.day, from: Date(timeIntervalSince1970: (low + high) / 2))
    }

    public func dayKey(_ date: Date, timeZone: TimeZone? = nil) -> String {
        var civil = calendar
        if let timeZone { civil.timeZone = timeZone }
        let parts = civil.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}
