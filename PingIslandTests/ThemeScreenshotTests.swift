import AppKit
import XCTest
@testable import Ping_Island

@MainActor
final class ThemeScreenshotTests: XCTestCase {
    func testWriteSettingsThemeScreenshotsWhenRequested() throws {
        ExperienceThemeFontRegistry.registerBundledFonts()

        let settings = AppSettings.shared
        let originalTheme = settings.experienceThemeID
        let originalPixelPalette = settings.pixelThemePaletteID
        let originalConsent = settings.analyticsConsentPromptCompleted
        defer {
            settings.experienceThemeID = originalTheme
            settings.pixelThemePaletteID = originalPixelPalette
            settings.analyticsConsentPromptCompleted = originalConsent
            SettingsWindowController.shared.dismiss()
        }

        settings.analyticsConsentPromptCompleted = true
        let variants: [(String, ExperienceThemeID, PixelThemePaletteID)] = [
            ("settings-ping-island", .standard, .arcadeNeon),
            ("settings-macos", .macOS, .arcadeNeon),
            ("settings-pixel-arcade", .pixel, .arcadeNeon),
            ("settings-pixel-game-boy", .pixel, .gameBoyOlive)
        ]

        for (filename, themeID, paletteID) in variants {
            settings.experienceThemeID = themeID
            settings.pixelThemePaletteID = paletteID

            let controller = SettingsWindowController.shared
            controller.resetToDefaultContentSize()
            controller.present(category: .sound)
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))

            let window = try XCTUnwrap(controller.window)
            window.displayIfNeeded()
            let data = try pngData(for: window)
            let attachment = XCTAttachment(
                data: data,
                uniformTypeIdentifier: "public.png"
            )
            attachment.name = filename
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func pngData(for window: NSWindow) throws -> Data {
        let frameView = try XCTUnwrap(window.contentView?.superview)
        frameView.layoutSubtreeIfNeeded()
        frameView.displayIfNeeded()

        let bounds = frameView.bounds
        let representation = try XCTUnwrap(
            frameView.bitmapImageRepForCachingDisplay(in: bounds)
        )
        frameView.cacheDisplay(in: bounds, to: representation)
        return try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    }
}
