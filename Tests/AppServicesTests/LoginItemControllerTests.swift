import Foundation
import Testing
@testable import AppServices

@MainActor
struct LoginItemControllerTests {
    private func isolatedDefaults() -> (UserDefaults, String) {
        let name = "QuickCalender.LoginItemTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func firstLaunchRegistersOnceAndKeepsManualDisableAcrossRelaunch() async {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service, defaults: defaults)
        await controller.configureOnFirstLaunch()
        #expect(controller.isEnabled)
        #expect(service.registrations == 1)
        await controller.configureOnFirstLaunch()
        #expect(service.registrations == 1)

        await controller.setEnabled(false)
        #expect(!controller.isEnabled)
        #expect(service.unregistrations == 1)
        let relaunched = LoginItemController(service: service, defaults: defaults)
        await relaunched.configureOnFirstLaunch()
        #expect(!relaunched.isEnabled)
        #expect(service.registrations == 1)
    }

    @Test func existingServiceChoicesAreNotOverridden() async {
        for state in [LoginItemStatus.enabled, .requiresApproval] {
            let (defaults, name) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            let service = FakeLoginItemService(status: state)
            let controller = LoginItemController(service: service, defaults: defaults)
            await controller.configureOnFirstLaunch()
            #expect(controller.status == state)
            #expect(service.registrations == 0)
        }
    }

    @Test func registrationFailureCanBeRetriedExplicitly() async {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = FakeLoginItemService()
        service.registrationFails = true
        let controller = LoginItemController(service: service, defaults: defaults)
        await controller.configureOnFirstLaunch()
        #expect(!controller.isEnabled)
        #expect(controller.errorMessage != nil)
        #expect(!controller.isUpdating)

        service.registrationFails = false
        let relaunched = LoginItemController(service: service, defaults: defaults)
        await relaunched.configureOnFirstLaunch()
        #expect(service.registrations == 1)
        await controller.setEnabled(true)
        #expect(service.registrations == 2)
        #expect(controller.isEnabled)
        #expect(controller.errorMessage == nil)
    }

    @Test func unregisterFailureDoesNotPretendDisabled() async {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = FakeLoginItemService(status: .enabled)
        service.unregistrationFails = true
        let controller = LoginItemController(service: service, defaults: defaults)
        await controller.setEnabled(false)
        #expect(controller.isEnabled)
        #expect(controller.errorMessage != nil)
        service.unregistrationFails = false
        await controller.setEnabled(false)
        #expect(!controller.isEnabled)
        #expect(controller.errorMessage == nil)
    }

    @Test func systemChangesAreReflectedWithoutReregistering() async {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = FakeLoginItemService(status: .enabled)
        let controller = LoginItemController(service: service, defaults: defaults)
        await controller.configureOnFirstLaunch()
        service.status = .requiresApproval
        controller.refreshStatus()
        #expect(!controller.isEnabled)
        #expect(controller.status == .requiresApproval)
        await controller.configureOnFirstLaunch()
        #expect(service.registrations == 0)
    }

    @Test func developmentLaunchDoesNotConsumeFirstInstalledLaunch() async {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = FakeLoginItemService()
        let development = LoginItemController(service: service, defaults: defaults, canConfigure: false)
        await development.configureOnFirstLaunch()
        #expect(service.registrations == 0)
        #expect(!defaults.bool(forKey: LoginItemController.configuredKey))
        let installed = LoginItemController(service: service, defaults: defaults)
        await installed.configureOnFirstLaunch()
        #expect(installed.isEnabled)
        #expect(service.registrations == 1)
    }

    @Test func approvalRequiredIsNotReportedAsEnabledAndCanBeCancelled() async {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = FakeLoginItemService()
        service.registrationResult = .requiresApproval
        let controller = LoginItemController(service: service, defaults: defaults)
        await controller.configureOnFirstLaunch()
        #expect(controller.status == .requiresApproval)
        #expect(!controller.isEnabled)
        await controller.setEnabled(true)
        #expect(service.registrations == 1)
        controller.openSystemSettings()
        #expect(service.settingsOpened == 1)
        await controller.setEnabled(false)
        #expect(controller.status == .notRegistered)
    }
}

@MainActor
private final class FakeLoginItemService: LoginItemService {
    var status: LoginItemStatus
    var registrations = 0
    var unregistrations = 0
    var settingsOpened = 0
    var registrationFails = false
    var unregistrationFails = false
    var registrationResult = LoginItemStatus.enabled

    init(status: LoginItemStatus = .notRegistered) { self.status = status }
    func register() throws {
        registrations += 1
        if registrationFails { throw Failure.expected }
        status = registrationResult
    }
    func unregister() async throws {
        unregistrations += 1
        if unregistrationFails { throw Failure.expected }
        status = .notRegistered
    }
    func openSystemSettings() { settingsOpened += 1 }
    private enum Failure: Error { case expected }
}
