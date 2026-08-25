import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: WindowManager?
    private var screenObserver: ScreenObserver?
    private let launchConfiguration = AppLaunchConfiguration()
    private let startupSessionMonitor = SessionMonitor()
    private let globalShortcutManager = GlobalShortcutManager.shared
    private var shouldPresentSettingsAfterOnboarding = false
    private var shouldRunHookWalkthroughAfterOnboarding = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AgentIslandBrand.installApplicationIcon()

        if launchConfiguration.shouldEnforceSingleInstance && !ensureSingleInstance() {
            NSApplication.shared.terminate(nil)
            return
        }

        // Touch the settings store early so the bridge runtime config is on disk
        // before any hook fires.
        _ = AppSettings.shared
        AppSettings.prepareSoundPlayback()
#if APP_STORE
        HookInstaller.restoreAppStoreHookDirectoryAuthorizationIfAvailable()
#endif

        if !launchConfiguration.isRunningTests {
            UpdateManager.shared.start()
            UserIdleAutoProtection.shared.start()
            Task {
                await SoundPackCatalog.shared.refreshInBackground()
            }
            Task {
                await TelemetryService.shared.start()
            }
        }

        if launchConfiguration.shouldInstallIntegrations {
            HookInstaller.installIfNeeded(
                markPresentationOnboardingPending: {
                    AppSettings.presentationModeOnboardingPending = true
                },
                markHookInstallOnboardingPending: {
                    AppSettings.hookInstallOnboardingPending = true
                }
            )
            IDEExtensionInstaller.cleanupLegacyTraeExtension()
            NotchDetachmentHintExperience.prepareForLaunch(
                previousVersion: HookInstaller.getVersionMetadata()?["previousVersion"] as? String,
                markHintsPending: {
                    AppSettings.notchDetachmentHintPending = true
                    AppSettings.floatingPetSettingsHintPending = true
                }
            )

            // AgentIsland preview builds carry a versioned welcome experience.
            // Upgrading over an older preview must still show the new launch
            // ceremony once; the original first-install marker is not enough.
            AgentIslandOnboardingExperience.prepareForLaunch()
        }

        NSApplication.shared.setActivationPolicy(launchConfiguration.activationPolicy)

        let launchFlow = AppLaunchFlow(
            configuration: launchConfiguration,
            presentationModeOnboardingPending: AppSettings.presentationModeOnboardingPending
        )
        shouldPresentSettingsAfterOnboarding = launchFlow.shouldPresentSettingsWindowAfterOnboarding
        shouldRunHookWalkthroughAfterOnboarding = launchFlow.shouldPresentSurfaceModeOnboarding

        if launchFlow.shouldStartMonitoringImmediately {
            // Keep hook and app-server ingestion alive even when first-run onboarding
            // defers the initial Island window.
            startupSessionMonitor.startMonitoring()
        }

        if launchFlow.shouldCreateInitialIslandWindow {
            startWindowManagerIfNeeded()
        }

        if launchConfiguration.shouldObserveScreens {
            screenObserver = ScreenObserver { [weak self] in
                self?.handleScreenChange()
            }
        }

        globalShortcutManager.start()

        if launchFlow.shouldPresentSurfaceModeOnboarding {
            PresentationModeWelcomeWindowController.shared.present { [weak self] selectedMode in
                self?.completePresentationModeOnboarding(with: selectedMode)
            }
        } else if launchFlow.shouldPresentSettingsWindowImmediately {
            SettingsWindowController.shared.present()
        } else {
            presentHookInstallOnboardingIfNeeded()
        }

        // Play the fixed client startup sound for the bundled 8-bit theme.
        Task { @MainActor in
            AppSettings.playClientStartupSound()
        }

        if !launchConfiguration.isRunningTests {
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await TelemetryService.shared.recordAppLaunch()
                await TelemetryService.shared.recordIntegrationSnapshot()
            }
        }
    }

    @MainActor
    @discardableResult
    private func presentHookInstallOnboardingIfNeeded() -> Bool {
        guard AppSettings.hookInstallOnboardingPending else {
            startHookWalkthroughAfterOnboardingIfNeeded()
            return false
        }
        HookInstallWelcomeWindowController.shared.present { decision in
            switch decision {
            case .installDefaults:
#if APP_STORE
                let didInstall = HookInstaller.performFirstRunDefaultInstallWithUserAuthorization()
                AppSettings.hookInstallOnboardingPending = !didInstall
                if didInstall {
                    self.startHookWalkthroughAfterOnboardingIfNeeded()
                }
#else
                HookInstaller.performFirstRunDefaultInstall()
                AppSettings.hookInstallOnboardingPending = false
                self.startHookWalkthroughAfterOnboardingIfNeeded()
#endif
            case .customize:
#if APP_STORE
                AppSettings.hookInstallOnboardingPending = true
                self.shouldRunHookWalkthroughAfterOnboarding = false
                SettingsWindowController.shared.present(category: .integration)
#else
                HookInstaller.performFirstRunDefaultInstall()
                AppSettings.hookInstallOnboardingPending = false
                self.shouldRunHookWalkthroughAfterOnboarding = false
                SettingsWindowController.shared.present()
#endif
            case .skip:
                AppSettings.hookInstallOnboardingPending = false
                self.startHookWalkthroughAfterOnboardingIfNeeded()
            }
        }
        return true
    }

    @MainActor
    private func handleScreenChange() {
        guard !AppSettings.presentationModeOnboardingPending else { return }
        startWindowManagerIfNeeded()
    }

    @MainActor
    private func completePresentationModeOnboarding(with selectedMode: IslandSurfaceMode) {
        AppSettings.surfaceMode = selectedMode
        AgentIslandOnboardingExperience.markCompleted()
        AppSettings.presentationModeOnboardingPending = false
        AppSettings.notchDetachmentHintPending = false
        AppSettings.floatingPetSettingsHintPending = false
        startWindowManagerIfNeeded()

        if shouldRunHookWalkthroughAfterOnboarding {
            shouldRunHookWalkthroughAfterOnboarding = false
            _ = presentHookInstallOnboardingIfNeeded()
            return
        }

        if shouldPresentSettingsAfterOnboarding {
            SettingsWindowController.shared.present()
            shouldPresentSettingsAfterOnboarding = false
        } else {
            presentHookInstallOnboardingIfNeeded()
        }
    }

    @MainActor
    private func startHookWalkthroughAfterOnboardingIfNeeded() {
        guard shouldRunHookWalkthroughAfterOnboarding else { return }
        shouldRunHookWalkthroughAfterOnboarding = false
        HookWalkthroughDemoRunner.shared.start()
    }

    @MainActor
    private func startWindowManagerIfNeeded() {
        if windowManager == nil {
            windowManager = WindowManager()
        }
        _ = windowManager?.setupNotchWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        screenObserver = nil
        UserIdleAutoProtection.shared.stop()
        if !launchConfiguration.isRunningTests {
            startupSessionMonitor.stopMonitoring()
        }
        Task {
            await TelemetryService.shared.stop()
        }
    }
    private func ensureSingleInstance() -> Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.agentisland.app"
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID || $0.bundleIdentifier == "com.wudanwu.PingIsland"
        }

        if bundleID != "com.wudanwu.PingIsland",
           runningApps.contains(where: { $0.bundleIdentifier == "com.wudanwu.PingIsland" }) {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = AppLocalization.string("请先退出 Ping Island")
            alert.informativeText = AppLocalization.string(
                "AgentIsland 与 Ping Island 共用 Hooks 和本地 Bridge，一次只能运行一个。退出原版后再启动 AgentIsland。"
            )
            alert.addButton(withTitle: AppLocalization.string("知道了"))
            alert.runModal()
            return false
        }

        if runningApps.count > 1 {
            if let existingApp = runningApps.first(where: { $0.processIdentifier != getpid() }) {
                existingApp.activate()
            }
            return false
        }

        return true
    }
}
