import Foundation
import Combine
import ServiceManagement

public enum LoginItemStatus: Equatable {
    case notRegistered, enabled, requiresApproval, notFound
}

@MainActor
protocol LoginItemService {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() async throws
    func openSystemSettings()
}

@MainActor
private final class MainAppLoginItemService: LoginItemService {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() async throws { try await SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
public final class LoginItemController: ObservableObject {
    static let configuredKey = "QuickCalender.loginItemConfigured.v1"
    @Published public private(set) var status: LoginItemStatus = .notRegistered
    @Published public private(set) var isUpdating = false
    @Published public private(set) var errorMessage: String?
    public let canConfigure: Bool
    private let service: LoginItemService
    private let defaults: UserDefaults

    public convenience init() {
        let bundleURL = Bundle.main.bundleURL
        let readOnly = (try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly == true
        self.init(service: MainAppLoginItemService(), defaults: .standard,
                  canConfigure: bundleURL.pathExtension == "app" && !readOnly)
    }

    init(service: LoginItemService, defaults: UserDefaults, canConfigure: Bool = true) {
        self.service = service
        self.defaults = defaults
        self.canConfigure = canConfigure
        refreshStatus()
    }

    public var isEnabled: Bool { status == .enabled }

    public func refreshStatus() {
        status = canConfigure ? service.status : .notRegistered
    }

    public func configureOnFirstLaunch() async {
        // Running a command-line build or an app on a DMG must not consume the
        // first installed launch, or register a read-only/translocated bundle.
        guard canConfigure, !defaults.bool(forKey: Self.configuredKey) else { return }
        defaults.set(true, forKey: Self.configuredKey)
        refreshStatus()
        // Respect an existing registration or the user's denial in macOS.
        guard status != .enabled, status != .requiresApproval else { return }
        await setEnabled(true)
    }

    public func setEnabled(_ enabled: Bool) async {
        guard canConfigure, !isUpdating else { return }
        // Persist intent before touching the system, including failures, so an
        // explicit disable is never overridden on a later launch or upgrade.
        defaults.set(true, forKey: Self.configuredKey)
        isUpdating = true
        errorMessage = nil
        defer { refreshStatus(); isUpdating = false }
        refreshStatus()
        do {
            if enabled {
                if status != .enabled, status != .requiresApproval { try service.register() }
            } else if status == .enabled || status == .requiresApproval {
                try await service.unregister()
            }
        } catch {
            errorMessage = "无法更新开机启动：\(error.localizedDescription)"
        }
    }

    public func openSystemSettings() { service.openSystemSettings() }
}
