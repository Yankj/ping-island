import AppKit
import Carbon.HIToolbox
import QuartzCore
import SwiftUI

extension Notification.Name {
    static let settingsWindowVisibilityDidChange = Notification.Name("settingsWindowVisibilityDidChange")
    static let settingsWindowCategorySelectionRequested = Notification.Name("settingsWindowCategorySelectionRequested")
}

enum SettingsWindowLayout {
    @MainActor
    static func resetContentSize(of window: NSWindow?) {
        guard let window else { return }

        window.minSize = NSSize(
            width: AppSettings.minimumSettingsWindowSize.width,
            height: AppSettings.minimumSettingsWindowSize.height
        )
        window.maxSize = NSSize(
            width: AppSettings.maximumSettingsWindowSize.width,
            height: AppSettings.maximumSettingsWindowSize.height
        )
        window.setContentSize(NSSize(
            width: SettingsWindowDefaults.defaultContentSize.width,
            height: SettingsWindowDefaults.defaultContentSize.height
        ))
    }
}

enum SettingsWindowVisibilityNotification {
    static let isVisibleKey = "isVisible"
}

enum SettingsWindowCategorySelectionRequest {
    static let categoryKey = "category"
}

final class SettingsPanelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isCommandW(event) {
            requestCloseFromKeyboard()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if isCommandW(event) {
            requestCloseFromKeyboard()
            return
        }

        super.keyDown(with: event)
    }

    private func isCommandW(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == UInt16(kVK_ANSI_W) && flags == .command
    }

    private func requestCloseFromKeyboard() {
        if delegate?.windowShouldClose?(self) != false {
            close()
        }
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private let defaultContentSize = NSSize(
        width: SettingsWindowDefaults.defaultContentSize.width,
        height: SettingsWindowDefaults.defaultContentSize.height
    )
    private let minimumContentSize = NSSize(
        width: AppSettings.minimumSettingsWindowSize.width,
        height: AppSettings.minimumSettingsWindowSize.height
    )
    private let maximumContentSize = NSSize(
        width: AppSettings.maximumSettingsWindowSize.width,
        height: AppSettings.maximumSettingsWindowSize.height
    )

    private init() {
        let hostingController = NSHostingController(
            rootView: AppLocalizedRootView {
                SettingsWindowView()
            }
        )
        let window = SettingsPanelWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = NSColor(
            calibratedRed: 0.055,
            green: 0.065,
            blue: 0.085,
            alpha: 1
        )
        window.hasShadow = true
        window.minSize = minimumContentSize
        window.maxSize = maximumContentSize
        window.identifier = NSUserInterfaceItemIdentifier("settings.window")
        let toolbar = NSToolbar(identifier: "settings.toolbar")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .regular
        toolbar.showsBaselineSeparator = false
        toolbar.isVisible = true
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.showsToolbarButton = false
        window.titlebarSeparatorStyle = .none
        // Attaching a toolbar changes the content layout rect, so size the
        // window only after its complete titlebar hierarchy is installed.
        window.setContentSize(defaultContentSize)
        window.center()
        window.collectionBehavior = [.fullScreenPrimary, .moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        super.init(window: window)

        self.window?.delegate = self
        hostingController.rootView = AppLocalizedRootView {
            SettingsWindowView(
                onClose: { [weak self] in
                    self?.dismiss()
                }
            )
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }

        window.minSize = minimumContentSize
        window.maxSize = maximumContentSize
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        publishVisibilityDidChange(isVisible: true)
    }

    func present(category: SettingsCategory) {
        present()
        NotificationCenter.default.post(
            name: .settingsWindowCategorySelectionRequested,
            object: self,
            userInfo: [SettingsWindowCategorySelectionRequest.categoryKey: category.rawValue]
        )
    }

    func resetToDefaultContentSize() {
        SettingsWindowLayout.resetContentSize(of: window)
    }

    func dismiss() {
        window?.orderOut(nil)
        publishVisibilityDidChange(isVisible: false)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }

    func windowDidMiniaturize(_ notification: Notification) {
        publishVisibilityDidChange(isVisible: false)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        publishVisibilityDidChange(isVisible: window?.isVisible == true)
    }

    private func publishVisibilityDidChange(isVisible: Bool) {
        NotificationCenter.default.post(
            name: .settingsWindowVisibilityDidChange,
            object: self,
            userInfo: [SettingsWindowVisibilityNotification.isVisibleKey: isVisible]
        )
    }
}

@MainActor
final class PresentationModeWelcomeWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PresentationModeWelcomeWindowController()

    private let fallbackScreenSize = NSSize(width: 1440, height: 900)
    private let hostingController = NSHostingController(rootView: AnyView(EmptyView()))
    private let presentationAnimationDuration: TimeInterval = 0.22
    private let dismissalAnimationDuration: TimeInterval = 0.16
    private var completion: ((IslandSurfaceMode) -> Void)?
    private var isDismissing = false

    private init() {
        let window = SettingsPanelWindow(
            contentRect: NSRect(origin: .zero, size: fallbackScreenSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .mainMenu + 1
        window.identifier = NSUserInterfaceItemIdentifier("presentation-mode-welcome.window")
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)
        self.window?.delegate = self
        hostingController.view.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(onComplete: @escaping (IslandSurfaceMode) -> Void) {
        isDismissing = false
        completion = onComplete
        hostingController.rootView = AnyView(
            AppLocalizedRootView {
                PresentationModeWelcomeView(initialMode: AppSettings.surfaceMode) { [weak self] mode, analyticsOptIn in
                    AppSettings.analyticsEnabled = analyticsOptIn
                    AppSettings.analyticsConsentPromptCompleted = true
                    self?.finish(with: mode)
                }
            }
        )

        guard let window else { return }
        let targetScreen = ScreenSelector.shared.selectedScreen ?? NSScreen.main
        let targetFrame = targetScreen?.frame ?? NSRect(origin: .zero, size: fallbackScreenSize)
        window.minSize = targetFrame.size
        window.maxSize = targetFrame.size
        window.setFrame(targetFrame, display: true)
        window.alphaValue = 0
        setContentScale(1)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = presentationAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func dismiss() {
        dismissAnimated()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        false
    }

    private func finish(with mode: IslandSurfaceMode) {
        let completion = completion
        self.completion = nil
        dismissAnimated {
            completion?(mode)
        }
    }

    private func dismissAnimated(completion: (() -> Void)? = nil) {
        guard let window else {
            completion?()
            return
        }
        guard window.isVisible else {
            completion?()
            return
        }
        guard !isDismissing else { return }

        isDismissing = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = dismissalAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self, weak window] in
            MainActor.assumeIsolated {
                guard let self, let window else { return }
                window.orderOut(nil)
                window.alphaValue = 1
                self.setContentScale(1)
                self.isDismissing = false
                completion?()
            }
        }
    }

    private func setContentScale(_ scale: CGFloat) {
        guard let layer = hostingController.view.layer else { return }
        layer.removeAnimation(forKey: "presentationModeWelcomeScale")
        layer.transform = CATransform3DMakeScale(scale, scale, 1)
    }

    private func animateContentScale(from startScale: CGFloat, to endScale: CGFloat, duration: TimeInterval) {
        guard let layer = hostingController.view.layer else { return }
        layer.removeAnimation(forKey: "presentationModeWelcomeScale")
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = startScale
        animation.toValue = endScale
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: endScale >= startScale ? .easeOut : .easeIn)
        layer.transform = CATransform3DMakeScale(endScale, endScale, 1)
        layer.add(animation, forKey: "presentationModeWelcomeScale")
    }
}

enum HookInstallOnboardingDecision {
    case installDefaults
    case customize
    case skip
}

@MainActor
final class HookInstallWelcomeWindowController: NSWindowController, NSWindowDelegate {
    static let shared = HookInstallWelcomeWindowController()

#if APP_STORE
    private let fixedContentSize = NSSize(width: 560, height: 548)
#else
    private let fixedContentSize = NSSize(width: 540, height: 480)
#endif
    private let hostingController = NSHostingController(rootView: AnyView(EmptyView()))
    private var completion: ((HookInstallOnboardingDecision) -> Void)?

    private init() {
        let window = SettingsPanelWindow(
            contentRect: NSRect(origin: .zero, size: fixedContentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = fixedContentSize
        window.maxSize = fixedContentSize
        window.setContentSize(fixedContentSize)
        window.identifier = NSUserInterfaceItemIdentifier("hook-install-welcome.window")
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)
        self.window?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(onComplete: @escaping (HookInstallOnboardingDecision) -> Void) {
        completion = onComplete
        let profiles = HookInstaller.defaultEnabledManageableProfiles()
        hostingController.rootView = AnyView(
            AppLocalizedRootView {
                HookInstallWelcomeView(profiles: profiles) { [weak self] decision in
                    self?.finish(with: decision)
                }
            }
        )

        guard let window else { return }
        window.setContentSize(fixedContentSize)
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        false
    }

    private func finish(with decision: HookInstallOnboardingDecision) {
        let completion = completion
        self.completion = nil
        dismiss()
        completion?(decision)
    }
}

private struct HookInstallWelcomeView: View {
    let profiles: [ManagedHookClientProfile]
    let onComplete: (HookInstallOnboardingDecision) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.08, green: 0.11, blue: 0.20),
                    Color(red: 0.10, green: 0.16, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .padding(14)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appLocalized: title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(appLocalized: subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

#if APP_STORE
                appStoreAuthorizationNotice
#endif

                profileList

                Spacer(minLength: 0)

                actionButtons
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
        }
        .frame(width: contentSize.width, height: contentSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.24), radius: 24, y: 14)
        .preferredColorScheme(.dark)
    }

    private var title: String {
#if APP_STORE
        "授权后安装 Hooks"
#else
        "为以下客户端安装 Hooks"
#endif
    }

    private var subtitle: String {
#if APP_STORE
        "Mac App Store 版本不会自动写入 ~/.claude、~/.codex 等目录。选择安装时，AgentIsland 会请求你授权用户主目录后再写入配置。"
#else
        "AgentIsland 通过 Hooks 监听会话事件、显示通知与审批。可以一键安装默认配置，或选择仅启用部分事件。"
#endif
    }

    private var contentSize: CGSize {
#if APP_STORE
        CGSize(width: 560, height: 548)
#else
        CGSize(width: 540, height: 480)
#endif
    }

#if APP_STORE
    private var appStoreAuthorizationNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.open.display")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(TerminalColors.amber)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(appLocalized: "前往设置的 Hooks 管理")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.88))
                Text(appLocalized: "你也可以稍后到“设置 > 集成 > Hooks 管理”点击安装；系统会请求授权用户主目录后再写入配置。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(TerminalColors.amber.opacity(0.22), lineWidth: 1)
        )
    }
#endif

    private var profileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(profiles) { profile in
                HStack(spacing: 12) {
                    Image(systemName: profile.iconSymbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.white.opacity(0.06))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: profile.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(appLocalized: profile.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.50))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if profile.id != profiles.last?.id {
                    Divider().overlay(Color.white.opacity(0.08))
                        .padding(.horizontal, 14)
                }
            }

            if profiles.isEmpty {
                Text(appLocalized: "未检测到可自动安装的客户端，可在设置中手动添加。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                onComplete(.installDefaults)
            } label: {
                Text(appLocalized: primaryButtonTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
            .disabled(profiles.isEmpty)

            HStack(spacing: 8) {
                Button {
                    onComplete(.customize)
                } label: {
                    Text(appLocalized: secondaryButtonTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(profiles.isEmpty)

                Button {
                    onComplete(.skip)
                } label: {
                    Text(appLocalized: "暂不安装")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryButtonTitle: String {
#if APP_STORE
        "授权主目录并安装"
#else
        "使用默认配置安装（推荐）"
#endif
    }

    private var secondaryButtonTitle: String {
#if APP_STORE
        "打开设置并授权 Hooks…"
#else
        "自定义事件…"
#endif
    }
}

private enum AgentIslandWelcomeStep: Int, CaseIterable {
    case intro
    case overview
    case signals
    case jumpBack
    case control
    case theme
    case placement
}

private struct AgentIslandStoryHighlight: Identifiable {
    let id: String
    let systemImage: String
    let title: String
}

private struct AgentIslandStory {
    let systemImage: String
    let accent: Color
    let eyebrow: String
    let title: String
    let detail: String
    let highlights: [AgentIslandStoryHighlight]
}

private struct PresentationModeWelcomeView: View {
    let onComplete: (IslandSurfaceMode, Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedMode: IslandSurfaceMode
    @State private var analyticsOptIn = true
    @State private var step: AgentIslandWelcomeStep = .intro
    @State private var didReveal = false
    @State private var didPlayCeremony = false
    @State private var isMovingForward = true
    @State private var ceremonyPhase = 0
    @State private var isCeremonyVisible = true

    init(
        initialMode: IslandSurfaceMode,
        onComplete: @escaping (IslandSurfaceMode, Bool) -> Void
    ) {
        self.onComplete = onComplete
        _selectedMode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            onboardingPanel
            .opacity(isCeremonyVisible ? 0 : 1)
            .allowsHitTesting(!isCeremonyVisible)

            if isCeremonyVisible {
                AgentIslandLaunchCeremonyView(
                    phase: ceremonyPhase,
                    reduceMotion: reduceMotion,
                    soundEnabled: settings.soundEnabled,
                    onSkip: { finishCeremony(stopSound: true) }
                )
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .preferredColorScheme(.dark)
        .environment(\.agentIslandVisualTheme, settings.visualThemeMode)
        .onAppear(perform: beginCeremony)
    }

    private var onboardingPanel: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                brandHeader
                    .padding(.horizontal, 36)
                    .padding(.top, 28)

                ZStack {
                    switch step {
                    case .intro:
                        introPage
                            .transition(pageTransition)
                    case .overview, .signals, .jumpBack, .control:
                        AgentIslandStoryPage(story: story(for: step))
                            .transition(pageTransition)
                    case .theme:
                        themePage
                            .transition(pageTransition)
                    case .placement:
                        placementPage
                            .transition(pageTransition)
                    }
                }
                .id(step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 44)

                navigationBar
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 860, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: settings.visualThemeMode.isPixel ? 6 : 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: settings.visualThemeMode.isPixel ? 6 : 30, style: .continuous)
                .strokeBorder(
                    settings.visualThemeMode.isPixel
                        ? Color(red: 0.30, green: 0.92, blue: 0.70).opacity(0.64)
                        : Color.white.opacity(0.12),
                    lineWidth: settings.visualThemeMode.isPixel ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.32), radius: 32, y: 18)
    }

    private var onboardingBackground: some View {
        ZStack {
            AgentIslandThemeBackdrop()

            Circle()
                .fill(Color(red: 0.30, green: 0.48, blue: 1.0).opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 74)
                .offset(x: didReveal ? -280 : -340, y: didReveal ? -180 : -230)

            if !settings.visualThemeMode.isPixel {
                Circle()
                    .fill(Color(red: 0.96, green: 0.32, blue: 0.52).opacity(0.16))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: didReveal ? 310 : 360, y: didReveal ? 220 : 270)
            }

            LinearGradient(
                colors: [Color.white.opacity(0.035), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            AgentIslandBrandIcon(size: 34, shadowRadius: 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("AgentIsland")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(appLocalized: "你的 AI Agent 状态岛")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.52))
            }

            Spacer()

            Text("PREVIEW · 0.29.0")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.68))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var introPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 10)

            AgentIslandDemoCapsule(isRevealed: didReveal, reduceMotion: reduceMotion)

            VStack(spacing: 12) {
                Text(appLocalized: "所有 AI Agent，一个状态岛。")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(appLocalized: "审批、完成、错误和返回窗口，在你需要时自然出现。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }

            Text(appLocalized: "流光玻璃与 Pixel 登岛，视觉和声音都由你选择。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.48))

            Spacer(minLength: 8)
        }
        .opacity(didReveal ? 1 : 0)
        .offset(y: reduceMotion || didReveal ? 0 : 14)
    }

    private var placementPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(appLocalized: "最后，选择 AgentIsland 出现的位置")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(appLocalized: "之后可随时在“设置 → 显示”中切换；右键状态岛或悬浮宠物可打开设置与退出菜单。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
            }

            IslandSurfaceModeSelector(
                mode: $selectedMode,
                title: nil,
                subtitle: nil
            )

            Toggle(isOn: $analyticsOptIn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appLocalized: "帮助提升 AgentIsland 体验")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.88))
                    Text(appLocalized: "发送匿名使用统计；不包含会话内容、代码、路径、项目名或主机信息。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.56))
                }
            }
            .toggleStyle(.checkbox)
            .tint(.white)

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundColor(Color(red: 0.55, green: 0.76, blue: 1.0))
                Text(appLocalized: "完成后会单独询问是否安装 Hooks；跳过也可正常使用。")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.56))
            }
        }
    }

    private var themePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(appLocalized: "选择你的登岛风格")
                    .font(AgentIslandThemeFont.display(size: 29, theme: settings.visualThemeMode))
                    .foregroundColor(.white)
                Text(appLocalized: "视觉、文字、图标和声音会作为一个完整主题切换；之后可在“设置 → 通用”随时更改。")
                    .font(AgentIslandThemeFont.body(size: 13, theme: settings.visualThemeMode))
                    .foregroundColor(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            AgentIslandVisualThemeSelector(theme: $settings.visualThemeMode)
                .background(
                    RoundedRectangle(cornerRadius: settings.visualThemeMode.isPixel ? 4 : 18, style: .continuous)
                        .fill(Color.black.opacity(0.20))
                )

            HStack(spacing: 10) {
                AgentIslandThemeSymbol(
                    systemName: "speaker.wave.2.fill",
                    pixelGlyph: .sound,
                    size: 18,
                    color: settings.visualThemeMode.isPixel
                        ? Color(red: 0.30, green: 0.92, blue: 0.70)
                        : Color(red: 0.55, green: 0.76, blue: 1.0)
                )
                Text(appLocalized: settings.visualThemeMode.isPixel
                     ? "Pixel 登岛已启用：Silkscreen 字体、像素图标和完整 8-bit 阶段音。"
                     : "流光玻璃已启用：柔和光晕、圆角图标和语义合成音。")
                    .font(AgentIslandThemeFont.body(size: 11, theme: settings.visualThemeMode))
                    .foregroundColor(.white.opacity(0.68))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: settings.visualThemeMode.isPixel ? 3 : 13, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.top, 24)
    }

    private var navigationBar: some View {
        HStack(spacing: 16) {
            if step == .intro {
                Button {
                    move(to: .placement)
                } label: {
                    Text(appLocalized: "跳过介绍")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.62))
                        .frame(minWidth: 84, minHeight: 44)
                }
                .buttonStyle(AgentIslandOnboardingButtonStyle())
            } else {
                Button {
                    move(to: AgentIslandWelcomeStep(rawValue: step.rawValue - 1) ?? .intro)
                } label: {
                    Label(AppLocalization.string("返回"), systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.72))
                        .frame(minWidth: 84, minHeight: 44)
                }
                .buttonStyle(AgentIslandOnboardingButtonStyle())
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(AgentIslandWelcomeStep.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item == step ? Color.white.opacity(0.92) : Color.white.opacity(0.20))
                        .frame(width: item == step ? 22 : 7, height: 7)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: step)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(step.rawValue + 1) / \(AgentIslandWelcomeStep.allCases.count)")

            Spacer()

            Button {
                if step == .placement {
                    onComplete(selectedMode, analyticsOptIn)
                } else {
                    move(to: AgentIslandWelcomeStep(rawValue: step.rawValue + 1) ?? .placement)
                }
            } label: {
                HStack(spacing: 8) {
                    Text(appLocalized: step == .placement ? "开始使用 AgentIsland" : "继续")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: step == .placement ? "checkmark.circle.fill" : "chevron.right")
                }
                .font(AgentIslandThemeFont.display(size: 14, theme: settings.visualThemeMode))
                .foregroundColor(step == .placement ? Color(red: 0.02, green: 0.18, blue: 0.12) : .black.opacity(0.86))
                .padding(.horizontal, step == .placement ? 22 : 20)
                .frame(minWidth: step == .placement ? 224 : 132, minHeight: 48)
                .background(
                    Group {
                        if settings.visualThemeMode.isPixel {
                            Rectangle().fill(
                                step == .placement
                                    ? Color(red: 0.32, green: 0.94, blue: 0.69)
                                    : Color.white.opacity(0.94)
                            )
                        } else {
                            Capsule().fill(
                                step == .placement
                                    ? Color(red: 0.50, green: 0.96, blue: 0.76)
                                    : Color.white.opacity(0.94)
                            )
                        }
                    }
                )
                .overlay(
                    Group {
                        if settings.visualThemeMode.isPixel {
                            Rectangle().strokeBorder(Color.white.opacity(0.42), lineWidth: 2)
                        }
                    }
                )
            }
            .buttonStyle(AgentIslandOnboardingButtonStyle(pressedOpacity: 0.78))
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("onboarding.primaryAction")
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
            )
    }

    private func beginCeremony() {
        guard !didPlayCeremony else { return }
        didPlayCeremony = true

        AppSettings.prepareSoundPlayback()
        if reduceMotion {
            AppSettings.playOnboardingCeremonySound()
            finishCeremony()
            return
        }

        ceremonyPhase = 4
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            guard isCeremonyVisible else { return }
            AppSettings.playOnboardingCeremonySound()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.27) {
            guard isCeremonyVisible else { return }
            finishCeremony()
        }
    }

    private func finishCeremony(stopSound: Bool = false) {
        if stopSound {
            AppSettings.stopOnboardingCeremonySound()
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.58)) {
            isCeremonyVisible = false
            didReveal = true
        }
    }

    private func move(to destination: AgentIslandWelcomeStep) {
        isMovingForward = destination.rawValue > step.rawValue
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            step = destination
        }
        if destination != .intro {
            AppSettings.playOnboardingStageSound(destination.rawValue)
        }
    }

    private func story(for step: AgentIslandWelcomeStep) -> AgentIslandStory {
        switch step {
        case .overview:
            return AgentIslandStory(
                systemImage: "circle.hexagongrid.fill",
                accent: Color(red: 0.40, green: 0.65, blue: 1.0),
                eyebrow: "ONE ISLAND · MANY AGENTS",
                title: AppLocalization.string("所有 Agent 汇入同一个视野"),
                detail: AppLocalization.string("Claude、Codex、Gemini 与 IDE 会话统一显示；不用来回寻找哪个窗口正在等你。"),
                highlights: [
                    AgentIslandStoryHighlight(id: "agents", systemImage: "person.3.sequence.fill", title: AppLocalization.string("多 Agent")),
                    AgentIslandStoryHighlight(id: "sessions", systemImage: "rectangle.stack.fill", title: AppLocalization.string("多会话")),
                    AgentIslandStoryHighlight(id: "priority", systemImage: "scope", title: AppLocalization.string("自动排序"))
                ]
            )
        case .signals:
            return AgentIslandStory(
                systemImage: "waveform.path.ecg",
                accent: Color(red: 0.74, green: 0.48, blue: 1.0),
                eyebrow: "SEE · HEAR · ACT",
                title: AppLocalization.string("每种状态，都有自己的声音"),
                detail: AppLocalization.string("十个关键阶段使用不同语义提示；从会话开始到额度恢复，不盯屏幕也能判断发生了什么。"),
                highlights: [
                    AgentIslandStoryHighlight(id: "start", systemImage: "play.fill", title: AppLocalization.string("开始")),
                    AgentIslandStoryHighlight(id: "attention", systemImage: "hand.raised.fill", title: AppLocalization.string("需介入")),
                    AgentIslandStoryHighlight(id: "done", systemImage: "checkmark", title: AppLocalization.string("已完成"))
                ]
            )
        case .jumpBack:
            return AgentIslandStory(
                systemImage: "arrow.uturn.backward.circle.fill",
                accent: Color(red: 1.0, green: 0.46, blue: 0.62),
                eyebrow: "EXACT JUMP BACK",
                title: AppLocalization.string("点击，回到正确的工作现场"),
                detail: AppLocalization.string("从状态岛返回匹配的终端、IDE 窗口、标签页或会话，而不是只把应用带到前台。"),
                highlights: [
                    AgentIslandStoryHighlight(id: "terminal", systemImage: "terminal.fill", title: "Terminal"),
                    AgentIslandStoryHighlight(id: "ide", systemImage: "macwindow", title: "IDE"),
                    AgentIslandStoryHighlight(id: "session", systemImage: "bubble.left.and.bubble.right.fill", title: AppLocalization.string("会话"))
                ]
            )
        case .control:
            return AgentIslandStory(
                systemImage: "cursorarrow.motionlines",
                accent: Color(red: 0.30, green: 0.84, blue: 0.78),
                eyebrow: "QUIET BY DEFAULT",
                title: AppLocalization.string("迅速响应，也懂得保持安静"),
                detail: AppLocalization.string("150 ms Hover、离开容错、焦点抑制和减少动态效果，让提醒存在但不抢走注意力。"),
                highlights: [
                    AgentIslandStoryHighlight(id: "hover", systemImage: "cursorarrow", title: "150 ms"),
                    AgentIslandStoryHighlight(id: "grace", systemImage: "timer", title: AppLocalization.string("离开容错")),
                    AgentIslandStoryHighlight(id: "quiet", systemImage: "moon.zzz.fill", title: AppLocalization.string("智能安静"))
                ]
            )
        case .intro, .theme, .placement:
            preconditionFailure("No story page for \(step)")
        }
    }
}

private struct AgentIslandLaunchCeremonyView: View {
    let phase: Int
    let reduceMotion: Bool
    let soundEnabled: Bool
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let diagonal = sqrt(
                    proxy.size.width * proxy.size.width
                        + proxy.size.height * proxy.size.height
                )
                let fadeRadius = diagonal * 0.54

                ZStack {
                    RadialGradient(
                        colors: [
                            Color(red: 0.035, green: 0.055, blue: 0.14).opacity(0.97),
                            Color(red: 0.08, green: 0.05, blue: 0.16).opacity(0.72),
                            Color(red: 0.02, green: 0.08, blue: 0.12).opacity(0.24),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: fadeRadius
                    )

                    AgentIslandRadiance()
                        .opacity(phase >= 1 ? 0.92 : 0)
                        .scaleEffect(phase >= 1 ? 1 : 0.82)
                        .mask(
                            RadialGradient(
                                colors: [.white, .white.opacity(0.72), .clear],
                                center: .center,
                                startRadius: diagonal * 0.12,
                                endRadius: fadeRadius
                            )
                        )
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.72), value: phase)
                }
            }

            Circle()
                .fill(Color(red: 0.36, green: 0.55, blue: 1.0).opacity(phase >= 2 ? 0.34 : 0))
                .frame(width: 330, height: 330)
                .blur(radius: 72)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.72).delay(0.88), value: phase)

            VStack(spacing: 22) {
                Spacer(minLength: 120)

                AgentIslandBrandIcon(size: 112, shadowRadius: 24)
                    .scaleEffect(reduceMotion ? 1 : (phase >= 2 ? 1 : 0.68))
                    .opacity(phase >= 2 ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.72, dampingFraction: 0.78).delay(0.88),
                        value: phase
                    )

                VStack(spacing: 7) {
                    Text("AgentIsland")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 0.72, green: 0.82, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(appLocalized: "你的 Agent 正在汇入状态岛")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.64))
                }
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: reduceMotion || phase >= 3 ? 0 : 12)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.72).delay(2.0), value: phase)

                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(red: 0.38, green: 0.88, blue: 0.72))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(red: 0.38, green: 0.88, blue: 0.72).opacity(0.75), radius: 7)
                    Text(appLocalized: "十个声音阶段已就绪")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.78))
                }
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(Capsule().fill(Color.black.opacity(0.42)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .opacity(phase >= 4 ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (phase >= 4 ? 1 : 0.90))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.64, dampingFraction: 0.82).delay(3.36),
                    value: phase
                )

                Spacer(minLength: 110)
            }

            VStack {
                Spacer()
                HStack {
                    Button {
                        if !AppSettings.soundEnabled {
                            AppSettings.soundEnabled = true
                        }
                        AppSettings.prepareSoundPlayback()
                        AppSettings.playOnboardingCeremonySound()
                    } label: {
                        Label(
                            AppLocalization.string(soundEnabled ? "重播启动音效" : "开启并播放启动音效"),
                            systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                        )
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.54))
                        .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.replayLaunchSound")
                    Spacer()
                    Button(action: onSkip) {
                        Label(AppLocalization.string("跳过动画"), systemImage: "forward.end.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.82))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Capsule().fill(Color.black.opacity(0.48)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(AgentIslandOnboardingButtonStyle())
                    .accessibilityIdentifier("onboarding.skipLaunchCeremony")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppLocalization.string("AgentIsland 启动动画"))
    }
}

private struct AgentIslandRadiance: View {
    private let beamColors: [Color] = [
        Color(red: 0.30, green: 0.54, blue: 1.0),
        Color(red: 0.55, green: 0.38, blue: 0.96),
        Color(red: 0.96, green: 0.34, blue: 0.62),
        Color(red: 0.34, green: 0.82, blue: 0.84),
        Color(red: 0.72, green: 0.46, blue: 1.0),
        Color(red: 1.0, green: 0.47, blue: 0.40)
    ]

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
            let beamWidth = size.width * 0.14

            for (index, color) in beamColors.enumerated() {
                let normalized = CGFloat(index) / CGFloat(max(beamColors.count - 1, 1))
                let centerX = (normalized * size.width * 1.5) - (size.width * 0.25)
                var path = Path()
                path.move(to: origin)
                path.addLine(to: CGPoint(x: centerX - beamWidth, y: size.height * 1.08))
                path.addLine(to: CGPoint(x: centerX + beamWidth, y: size.height * 1.08))
                path.closeSubpath()
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.70), color.opacity(0.05)]),
                        startPoint: origin,
                        endPoint: CGPoint(x: centerX, y: size.height)
                    )
                )
            }
        }
        .blur(radius: 7)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct AgentIslandDemoCapsule: View {
    let isRevealed: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.42, green: 0.62, blue: 1.0).opacity(0.24))
                Image(systemName: "terminal.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.66, green: 0.78, blue: 1.0))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Codex")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(appLocalized: "等待你的批准")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
            }

            Spacer(minLength: 24)

            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Color(red: 0.56, green: 0.76, blue: 1.0).opacity(0.82))
                        .frame(width: 3, height: CGFloat(8 + (index % 2) * 7))
                }
            }

            Text(appLocalized: "查看")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.92)))
        }
        .padding(.horizontal, 15)
        .frame(width: 380, height: 64)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: Color.black.opacity(0.40), radius: 22, y: 12)
        .scaleEffect(reduceMotion ? 1 : (isRevealed ? 1 : 0.92))
    }
}

private struct AgentIslandStoryPage: View {
    let story: AgentIslandStory

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(story.eyebrow)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(story.accent.opacity(0.92))
                Text(story.title)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(story.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 640)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )

                Circle()
                    .fill(story.accent.opacity(0.18))
                    .frame(width: 170, height: 170)
                    .blur(radius: 26)

                Circle()
                    .strokeBorder(story.accent.opacity(0.24), lineWidth: 1)
                    .frame(width: 134, height: 134)

                Image(systemName: story.systemImage)
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, story.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 10) {
                    ForEach(story.highlights) { highlight in
                        HStack(spacing: 7) {
                            Image(systemName: highlight.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(story.accent)
                            Text(highlight.title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.82))
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(Capsule().fill(Color.black.opacity(0.34)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
                    }
                }
                .offset(y: 78)
            }
            .frame(maxWidth: .infinity, minHeight: 220)

        }
    }
}

private struct AgentIslandOnboardingButtonStyle: ButtonStyle {
    var pressedOpacity: Double = 0.58

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}
