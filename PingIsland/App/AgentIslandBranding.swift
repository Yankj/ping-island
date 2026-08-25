import AppKit
import Foundation
import SwiftUI

@MainActor
enum AgentIslandBrand {
    static let displayName = "AgentIsland"

    private static var bundledIconURL: URL? {
        let configuredName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String
        let normalizedName = configuredName?.hasSuffix(".icns") == true
            ? configuredName!
            : "\(configuredName ?? "AgentIslandIcon").icns"
        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent(normalizedName),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }
        return Bundle.main.url(forResource: "AgentIslandIcon", withExtension: "icns")
    }

    static var applicationIcon: NSImage {
        if let iconURL = bundledIconURL,
           let icon = NSImage(contentsOf: iconURL) {
            return icon
        }

        return NSApp.applicationIconImage
    }

    static func installApplicationIcon() {
        AgentIslandFontRegistry.registerBundledFonts()

        guard let iconURL = bundledIconURL,
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        _ = icon.setName(NSImage.Name("AgentIslandApplicationIcon"))
        NSApp.applicationIconImage = icon
    }
}

struct AgentIslandBrandIcon: View {
    var size: CGFloat
    var shadowRadius: CGFloat = 10

    var body: some View {
        Image(nsImage: AgentIslandBrand.applicationIcon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.28), radius: shadowRadius, y: shadowRadius * 0.45)
            .accessibilityLabel(AgentIslandBrand.displayName)
    }
}

@MainActor
enum AgentIslandOnboardingExperience {
    nonisolated static let completedExperienceDefaultsKey = "AgentIsland.completedOnboardingExperience"
    nonisolated static let infoDictionaryKey = "AgentIslandOnboardingExperience"

    @discardableResult
    static func prepareForLaunch(
        defaults: UserDefaults = .standard,
        currentIdentifier: String? = Bundle.main.infoDictionary?[infoDictionaryKey] as? String,
        markPending: (() -> Void)? = nil
    ) -> Bool {
        let identifier = currentIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !identifier.isEmpty,
              defaults.string(forKey: completedExperienceDefaultsKey) != identifier else {
            return false
        }

        if let markPending {
            markPending()
        } else {
            AppSettings.presentationModeOnboardingPending = true
        }
        return true
    }

    static func markCompleted(
        defaults: UserDefaults = .standard,
        currentIdentifier: String? = Bundle.main.infoDictionary?[infoDictionaryKey] as? String
    ) {
        let identifier = currentIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !identifier.isEmpty else { return }
        defaults.set(identifier, forKey: completedExperienceDefaultsKey)
    }
}
