import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var previewWindow: NSWindow?
    private var model: AppModel!
    private var timer: Timer?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        model.showSettings = { [weak self] in self?.openSettings() }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggleCalendar)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: CalendarView(model: model))
        model.$preferences.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatus() }
        }.store(in: &subscriptions)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.tick(); self?.updateStatus() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        updateStatus()
        model.refreshWeather()
        if CommandLine.arguments.contains("--preview") || Bundle.main.object(forInfoDictionaryKey: "QuickCalenderPreview") as? Bool == true { showPreview() }
        if CommandLine.arguments.contains("--settings") { openSettings() }
    }

    private func updateStatus() {
        guard let button = item.button else { return }
        button.title = model.preferences.statusLabel(at: model.now)
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.image = model.preferences.showStatusIcon ? NSImage(systemSymbolName: "calendar", accessibilityDescription: nil) : nil
        button.imagePosition = .imageLeading
        button.image?.isTemplate = true
        button.toolTip = "快捷日历 · 点击查看日历，右键打开菜单"
        button.setAccessibilityLabel("快捷日历，\(button.title)")
    }

    @objc private func didWake() { model.tick(); model.refreshWeather(); updateStatus() }

    @objc private func toggleCalendar() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
            settings.target = self; menu.addItem(settings)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "退出快捷日历", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.addItem(quit)
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
            return
        }
        if popover.isShown { popover.performClose(nil) }
        else if let button = item.button {
            model.today()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 590), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "快捷日历设置"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
            window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showPreview() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 650), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "快捷日历"
        window.contentViewController = NSHostingController(rootView: CalendarView(model: model))
        window.center(); window.makeKeyAndOrderFront(nil)
        previewWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
enum QuickCalenderApplication {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
