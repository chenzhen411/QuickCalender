import Foundation
import CoreGraphics
import Testing
@testable import CalendarCore

struct CalendarPopupTests {
    @Test func popupFitsVisibleScreenAtEveryEdge() {
        let screens = [
            CGRect(x: 0, y: 48, width: 1440, height: 824),
            CGRect(x: 0, y: 0, width: 800, height: 560),
            CGRect(x: -1280, y: 220, width: 1280, height: 700),
            CGRect(x: 1440, y: -900, width: 1024, height: 728),
            CGRect(x: 0, y: 0, width: 320, height: 400)
        ]
        for screen in screens {
            let content = CalendarPopupLayout.contentSize(visibleFrame: screen)
            #expect(content.width <= CalendarPopupLayout.preferredSize.width)
            #expect(content.height <= CalendarPopupLayout.preferredSize.height)
            // Include a larger-than-usual border and arrow in the native window.
            for x in [screen.minX - 100, screen.minX, screen.maxX - 30, screen.maxX + 100] {
                for y in [screen.minY - 100, screen.minY, screen.maxY - 20, screen.maxY + 100] {
                    let frame = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: content.width + 20, height: content.height + 24))
                    let result = CalendarPopupLayout.constrainedFrame(frame, visibleFrame: screen)
                    #expect(screen.insetBy(dx: 8, dy: 8).contains(result))
                    #expect(result.size == frame.size)
                }
            }
        }
    }

    @Test func oversizedNativeFrameIsBoundedAndPlacementIsStable() {
        let visible = CGRect(x: -1600, y: -200, width: 800, height: 500)
        let result = CalendarPopupLayout.constrainedFrame(CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: visible)
        #expect(visible.insetBy(dx: 8, dy: 8).contains(result))
        #expect(CalendarPopupLayout.constrainedFrame(result, visibleFrame: visible) == result)
    }

    @Test func repeatedRenderingReusesMonthMetadata() {
        let engine = CalendarEngine(timeZone: TimeZone(identifier: "Asia/Shanghai")!)
        let cache = CalendarMonthCache()
        let date = engine.date(year: 2026, month: 10, day: 28)
        let month = cache.month(containing: date, engine: engine)
        for hour in 0..<24 {
            let tick = engine.calendar.date(byAdding: .hour, value: hour, to: date)!
            #expect(cache.month(containing: tick, engine: engine) === month)
        }
        #expect(month.days.count == 42)
        let nationalDay = month.days.first { $0.key == "2026-10-01" }
        #expect(nationalDay?.festivals == ["国庆节"])
        #expect(nationalDay?.accessibleDate.contains("星期四") == true)
        #expect(nationalDay?.fullLunar == "八月廿一")
    }

    @Test func cacheSeparatesWeekStartsTimeZonesAndEvictsOldMonths() {
        let monday = CalendarEngine(timeZone: TimeZone(identifier: "Asia/Shanghai")!)
        let sunday = CalendarEngine(timeZone: monday.calendar.timeZone, mondayFirst: false)
        let newYork = CalendarEngine(timeZone: TimeZone(identifier: "America/New_York")!)
        let cache = CalendarMonthCache(capacity: 2)
        let date = monday.date(year: 2026, month: 10)
        let original = cache.month(containing: date, engine: monday)
        let shifted = cache.month(containing: date, engine: sunday)
        #expect(shifted !== original)
        #expect(sunday.calendar.component(.weekday, from: shifted.days[0].date) == 1)
        let overseas = cache.month(containing: newYork.date(year: 2026, month: 10), engine: newYork)
        #expect(overseas !== shifted)
        #expect(cache.month(containing: date, engine: monday) !== original)
    }

    @Test func dayKeyKeepsCivilDateAcrossTimeZonesAndDST() {
        let shanghai = CalendarEngine(timeZone: TimeZone(identifier: "Asia/Shanghai")!)
        let date = shanghai.date(year: 2026, month: 3, day: 8)
        #expect(shanghai.dayKey(date) == "2026-03-08")
        #expect(shanghai.dayKey(date, timeZone: TimeZone(identifier: "America/New_York")!) == "2026-03-07")
    }
}
