import AppKit
import SwiftUI
import CalendarCore

/// Opt-in native-window regression check; never runs during a normal launch.
@MainActor
final class PopupCheck {
    private let popover: NSPopover
    private let host: NSHostingController<CalendarView>
    private let model: AppModel
    private let button: NSStatusBarButton
    private let screen: NSScreen
    private let path: String
    private var results: [[String: Any]] = []
    private var readinessAttempts = 0
    private let sizes: [CGSize]

    init(popover: NSPopover, host: NSHostingController<CalendarView>, model: AppModel,
         button: NSStatusBarButton, screen: NSScreen, path: String) {
        self.popover = popover; self.host = host; self.model = model
        self.button = button; self.screen = screen; self.path = path
        let normal = CalendarPopupLayout.contentSize(visibleFrame: screen.visibleFrame)
        sizes = [normal, normal, CGSize(width: min(normal.width, 400), height: min(normal.height, 480)),
                 CGSize(width: min(normal.width, 300), height: min(normal.height, 340)), normal]
    }

    func run(_ index: Int = 0) {
        guard index < sizes.count else { finish(); return }
        if button.window == nil || button.bounds.width == 0 {
            readinessAttempts += 1
            guard readinessAttempts < 40 else { finish(error: "Status item did not become ready"); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in run(index) }
            return
        }
        popover.behavior = .applicationDefined
        popover.performClose(nil)
        if index == 1 {
            // Loaded weather must not grow the window.
            let key = model.engine.dayKey(model.now)
            let data = """
            {"timezone":"Asia/Shanghai","current":{"temperature_2m":20,"weather_code":2,"relative_humidity_2m":55,"apparent_temperature":19,"wind_speed_10m":7},"daily":{"time":["\(key)"],"weather_code":[2],"temperature_2m_max":[23],"temperature_2m_min":[12],"precipitation_probability_max":[10]}}
            """.data(using: .utf8)!
            model.forecast = try? JSONDecoder().decode(Forecast.self, from: data)
        }
        let size = sizes[index]
        host.rootView = CalendarView(model: model, viewportSize: size)
        popover.contentSize = size
        host.view.setFrameSize(size)
        host.view.layoutSubtreeIfNeeded()
        let start = ProcessInfo.processInfo.systemUptime
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        let showTime = (ProcessInfo.processInfo.systemUptime - start) * 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            host.view.layoutSubtreeIfNeeded()
            guard let window = host.view.window else {
                finish(error: "Popover did not create a native window; shown=\(popover.isShown), buttonWindow=\(String(describing: button.window)), bounds=\(button.bounds), active=\(NSApp.isActive)")
                return
            }
            let frame = window.frame
            let root = host.view.bounds.size
            results.append([
                "viewport": [size.width, size.height], "root": [root.width, root.height],
                "window": [frame.minX, frame.minY, frame.width, frame.height],
                "fitsScreen": screen.visibleFrame.insetBy(dx: 8, dy: 8).contains(frame),
                "rootMatchesViewport": abs(root.width - size.width) < 1 && abs(root.height - size.height) < 1,
                "showMilliseconds": showTime, "weatherLoaded": model.forecast != nil
            ])
            if let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) {
                host.view.cacheDisplay(in: host.view.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + ".\(index).png"))
            }
            DispatchQueue.main.async { [self] in run(index + 1) }
        }
    }

    private func finish(error: String? = nil) {
        popover.performClose(nil)
        let success = error == nil && results.count == sizes.count && results.allSatisfy {
            $0["fitsScreen"] as? Bool == true && $0["rootMatchesViewport"] as? Bool == true
        }
        let report: [String: Any] = ["success": success, "error": error ?? "", "cases": results,
            "visibleScreen": [screen.visibleFrame.minX, screen.visibleFrame.minY, screen.visibleFrame.width, screen.visibleFrame.height]]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: path))
        } catch { fputs("Popup check could not write its report: \(error)\n", stderr); exit(1) }
        if success { NSApp.terminate(nil) } else { exit(1) }
    }
}
