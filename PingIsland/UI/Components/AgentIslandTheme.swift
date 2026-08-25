import CoreText
import SwiftUI

enum AgentIslandVisualTheme: String, CaseIterable, Identifiable {
    case radiantGlass
    case pixelLanding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .radiantGlass: return "流光玻璃"
        case .pixelLanding: return "Pixel 登岛"
        }
    }

    var subtitle: String {
        switch self {
        case .radiantGlass:
            return "柔和光晕、圆角玻璃和语义合成音。"
        case .pixelLanding:
            return "Silkscreen 像素文字、游戏机图标和完整 8-bit 声音阶段。"
        }
    }

    var isPixel: Bool { self == .pixelLanding }
}

private struct AgentIslandVisualThemeKey: EnvironmentKey {
    static let defaultValue = AgentIslandVisualTheme.radiantGlass
}

extension EnvironmentValues {
    var agentIslandVisualTheme: AgentIslandVisualTheme {
        get { self[AgentIslandVisualThemeKey.self] }
        set { self[AgentIslandVisualThemeKey.self] = newValue }
    }
}

enum AgentIslandThemeFont {
    static let pixelPostScriptName = "Silkscreen-Bold"

    static func display(
        size: CGFloat,
        weight: Font.Weight = .bold,
        theme: AgentIslandVisualTheme
    ) -> Font {
        theme.isPixel
            ? .custom(pixelPostScriptName, size: size)
            : .system(size: size, weight: weight, design: .rounded)
    }

    static func body(
        size: CGFloat,
        weight: Font.Weight = .medium,
        theme: AgentIslandVisualTheme
    ) -> Font {
        theme.isPixel
            ? .custom(pixelPostScriptName, size: size)
            : .system(size: size, weight: weight)
    }
}

enum AgentIslandFontRegistry {
    @MainActor
    static func registerBundledFonts() {
        let candidates = [
            Bundle.main.url(forResource: "Silkscreen-Bold", withExtension: "ttf", subdirectory: "Fonts"),
            Bundle.main.url(forResource: "Silkscreen-Bold", withExtension: "ttf")
        ]

        for case let url? in candidates {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            return
        }
    }
}

enum AgentIslandPixelGlyph {
    case settings
    case shortcuts
    case display
    case mascot
    case sound
    case analytics
    case integration
    case remote
    case labs
    case info
    case approve
    case deny
    case session
    case sparkle

    fileprivate var rows: [String] {
        switch self {
        case .settings:
            return ["0011100", "0111110", "1100011", "1110111", "1100011", "0111110", "0011100"]
        case .shortcuts:
            return ["0100010", "1110111", "0100010", "0011100", "0100010", "1110111", "0100010"]
        case .display:
            return ["1111111", "1000001", "1011101", "1011101", "1000001", "1111111", "0011100"]
        case .mascot:
            return ["0111110", "1101011", "1111111", "1010101", "1111111", "0111110", "0101010"]
        case .sound:
            return ["0001000", "0011001", "0111011", "1111011", "0111011", "0011001", "0001000"]
        case .analytics:
            return ["1000001", "1001001", "1011001", "1011011", "1111011", "1111111", "1111111"]
        case .integration:
            return ["0111000", "1101100", "1000110", "0000011", "0110001", "1101011", "0011100"]
        case .remote:
            return ["0011100", "0100010", "1010101", "1000001", "1010101", "0100010", "0011100"]
        case .labs:
            return ["0011100", "0001000", "0001000", "0011100", "0111110", "1111111", "0111110"]
        case .info:
            return ["0011100", "0100010", "0001000", "0011000", "0001000", "0001000", "0011100"]
        case .approve:
            return ["0000000", "0000001", "0000011", "1000110", "1101100", "0111000", "0010000"]
        case .deny:
            return ["1000001", "1100011", "0110110", "0011100", "0110110", "1100011", "1000001"]
        case .session:
            return ["0111110", "1100011", "1000001", "1011101", "1000001", "1100011", "0111110"]
        case .sparkle:
            return ["0001000", "0001000", "0101010", "0011100", "1111111", "0011100", "0101010"]
        }
    }
}

struct AgentIslandThemeSymbol: View {
    let systemName: String
    let pixelGlyph: AgentIslandPixelGlyph
    var size: CGFloat = 16
    var color: Color = .white

    @Environment(\.agentIslandVisualTheme) private var theme

    var body: some View {
        Group {
            if theme.isPixel {
                AgentIslandPixelGlyphView(glyph: pixelGlyph, color: color)
            } else {
                Image(systemName: systemName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct AgentIslandPixelGlyphView: View {
    let glyph: AgentIslandPixelGlyph
    let color: Color

    var body: some View {
        Canvas { context, size in
            let rows = glyph.rows
            let columnCount = rows.first?.count ?? 7
            let pixel = floor(min(size.width / CGFloat(columnCount), size.height / CGFloat(rows.count)))
            let originX = floor((size.width - CGFloat(columnCount) * pixel) / 2)
            let originY = floor((size.height - CGFloat(rows.count) * pixel) / 2)

            for (rowIndex, row) in rows.enumerated() {
                for (columnIndex, value) in row.enumerated() where value == "1" {
                    let rect = CGRect(
                        x: originX + CGFloat(columnIndex) * pixel,
                        y: originY + CGFloat(rowIndex) * pixel,
                        width: pixel,
                        height: pixel
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .drawingGroup(opaque: false)
    }
}

struct AgentIslandThemeBackdrop: View {
    @Environment(\.agentIslandVisualTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.isPixel
                    ? [Color(red: 0.025, green: 0.035, blue: 0.09), Color(red: 0.08, green: 0.035, blue: 0.12)]
                    : [Color(red: 0.025, green: 0.045, blue: 0.11), Color(red: 0.11, green: 0.045, blue: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if theme.isPixel {
                Canvas { context, size in
                    let grid: CGFloat = 16
                    for x in stride(from: CGFloat.zero, through: size.width, by: grid) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 1)
                    }
                    for y in stride(from: CGFloat.zero, through: size.height, by: grid) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
