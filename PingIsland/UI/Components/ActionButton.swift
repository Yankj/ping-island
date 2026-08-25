//
//  ActionButton.swift
//  PingIsland
//
//  Reusable action button component
//

import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @Environment(\.agentIslandVisualTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                AgentIslandThemeSymbol(
                    systemName: icon,
                    pixelGlyph: pixelGlyph,
                    size: 10,
                    color: isHovered ? .black : color
                )
                Text(title)
                    .font(AgentIslandThemeFont.display(size: 10, theme: theme))
            }
            .foregroundColor(isHovered ? .black : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: theme.isPixel ? 2 : 6)
                    .fill(isHovered ? color : color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.isPixel ? 2 : 6)
                    .strokeBorder(color.opacity(theme.isPixel ? 0.72 : 0.3), lineWidth: theme.isPixel ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var pixelGlyph: AgentIslandPixelGlyph {
        if icon.contains("xmark") || icon.contains("trash") {
            return .deny
        }
        if icon.contains("check") || icon.contains("play") {
            return .approve
        }
        if icon.contains("speaker") {
            return .sound
        }
        if icon.contains("shield") || icon.contains("lock") {
            return .session
        }
        return .sparkle
    }
}
