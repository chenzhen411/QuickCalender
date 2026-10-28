import AppKit
import SwiftUI
import Combine
import CalendarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var item: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var previewWindow: NSWindow?
    private var model: AppModel!
    private var timer: Timer?
    private var subscriptions = Set<AnyCancellable>()
    private var calendarHost: NSHostingController<CalendarView>!
    private var viewportSize = CalendarPopupLayout.preferredSize
    private var popupScreen: NSScreen?
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        model.showSettings = { [weak self] in self?.openSettings() }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggleCalendar)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.imagePosition = .imageLeading
        item.button?.toolTip = "快捷日历 · 点击查看日历，右键打开菜单"
        popover = NSPopover()
        // A transient popover can close on mouse-down before the status button's
        // mouse-up action toggles it. Own all dismissal to avoid that race.
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.delegate = self
        calendarHost = NSHostingController(rootView: CalendarView(model: model, viewportSize: viewportSize))
        calendarHost.sizingOptions = []
        popover.contentViewController = calendarHost
        preparePopup()
        installDismissMonitors()
        model.$preferences.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatus() }
        }.store(in: &subscriptions)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.tick(); self?.updateStatus() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        updateStatus()
        model.refreshWeather()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if CommandLine.arguments.contains("--preview") || Bundle.main.object(forInfoDictionaryKey: "QuickCalenderPreview") as? Bool == true { showPreview() }
        if CommandLine.arguments.contains("--settings") { openSettings() }
    }

    private func updateStatus() {
        guard let button = item.button else { return }
        let title = model.preferences.statusLabel(at: model.now)
        if button.title != title {
            button.title = title
            button.setAccessibilityLabel("快捷日历，\(title)")
        }
        if model.preferences.showStatusIcon != (button.image != nil) {
            button.image = model.preferences.showStatusIcon ? NSImage(systemSymbolName: "calendar", accessibilityDescription: nil) : nil
            button.image?.isTemplate = true
        }
    }

    @objc private func didWake() { model.tick(); model.refreshWeather(); updateStatus() }

    @objc private func screensChanged() { popover.close(); preparePopup() }

    private func preparePopup() {
        popupScreen = item.button?.window?.screen ?? NSScreen.main
        guard let screen = popupScreen else { return }
        let size = CalendarPopupLayout.contentSize(visibleFrame: screen.visibleFrame)
        if viewportSize != size {
            viewportSize = size
            calendarHost.rootView = CalendarView(model: model, viewportSize: size)
        }
        popover.contentSize = size
        calendarHost.view.setFrameSize(size)
        calendarHost.view.layoutSubtreeIfNeeded()
    }

    func popoverDidShow(_ notification: Notification) {
        guard let screen = popupScreen, let window = calendarHost.view.window else { return }
        let frame = CalendarPopupLayout.constrainedFrame(window.frame, visibleFrame: screen.visibleFrame)
        if frame != window.frame { window.setFrame(frame, display: true, animate: false) }
    }

    private var pointerIsOverStatusItem: Bool {
        guard let button = item.button, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(NSEvent.mouseLocation)
    }

    private func containsPointer(_ window: NSWindow) -> Bool {
        window.frame.contains(NSEvent.mouseLocation)
            || (window.childWindows ?? []).contains(where: containsPointer)
    }

    private func installDismissMonitors() {
        localDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if event.type == .keyDown {
                // Let a nested month picker handle its own Escape first.
                if event.keyCode == 53, event.window === self.calendarHost.view.window {
                    self.popover.close()
                    return nil
                }
            } else if !self.pointerIsOverStatusItem,
                      let window = self.calendarHost.view.window, !self.containsPointer(window) {
                self.popover.close()
            }
            return event
        }
        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown, !self.pointerIsOverStatusItem else { return }
            self.popover.close()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localDismissMonitor { NSEvent.removeMonitor(localDismissMonitor) }
        if let globalDismissMonitor { NSEvent.removeMonitor(globalDismissMonitor) }
    }

    @objc private func toggleCalendar() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.close()
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
        if popover.isShown { popover.close() }
        else if let button = item.button {
            model.today()
            preparePopup()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func openSettings() {
        popover.close()
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
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: CalendarPopupLayout.preferredSize), styleMask: [.titled, .closable], backing: .buffered, defer: false)
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
