import SwiftUI

enum AppTheme {
    static let success = Color(red: 0.20, green: 0.74, blue: 0.45)
    static let warning = Color(red: 0.95, green: 0.62, blue: 0.18)
    static let danger = Color(red: 0.90, green: 0.30, blue: 0.33)
    static let cardRadius: CGFloat = 24
    static let contentSpacing: CGFloat = 18
    static let horizontalPadding: CGFloat = 20

    static func background(for colorScheme: ColorScheme, palette: AppAccentPalette) -> LinearGradient {
        let colors: [Color] = colorScheme == .dark
            ? [
                Color(red: 0.03, green: 0.05, blue: 0.09),
                palette.color.opacity(0.14),
                palette.secondaryColor.opacity(0.22)
            ]
            : [
                Color.white,
                palette.color.opacity(0.10),
                palette.secondaryColor.opacity(0.14)
            ]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func cardFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.78)
    }

    static func secondaryCardFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.52)
    }

    static func pillFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72)
    }
}

enum AppAccentPalette: String, CaseIterable, Codable, Identifiable {
    case mint
    case blue
    case coral
    case amber
    case rose
    case violet
    case emerald
    case indigo
    case copper
    case slate

    var id: Self { self }

    var color: Color {
        switch self {
        case .mint: Color(red: 0.08, green: 0.66, blue: 0.56)
        case .blue: Color(red: 0.16, green: 0.52, blue: 0.95)
        case .coral: Color(red: 0.92, green: 0.41, blue: 0.35)
        case .amber: Color(red: 0.90, green: 0.62, blue: 0.14)
        case .rose: Color(red: 0.83, green: 0.29, blue: 0.47)
        case .violet: Color(red: 0.48, green: 0.33, blue: 0.88)
        case .emerald: Color(red: 0.11, green: 0.57, blue: 0.43)
        case .indigo: Color(red: 0.24, green: 0.38, blue: 0.78)
        case .copper: Color(red: 0.67, green: 0.42, blue: 0.26)
        case .slate: Color(red: 0.30, green: 0.44, blue: 0.54)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .mint: Color(red: 0.16, green: 0.52, blue: 0.95)
        case .blue: Color(red: 0.24, green: 0.70, blue: 0.74)
        case .coral: Color(red: 0.99, green: 0.66, blue: 0.41)
        case .amber: Color(red: 0.69, green: 0.42, blue: 0.14)
        case .rose: Color(red: 0.98, green: 0.63, blue: 0.67)
        case .violet: Color(red: 0.75, green: 0.56, blue: 0.98)
        case .emerald: Color(red: 0.23, green: 0.72, blue: 0.60)
        case .indigo: Color(red: 0.42, green: 0.60, blue: 0.96)
        case .copper: Color(red: 0.83, green: 0.62, blue: 0.43)
        case .slate: Color(red: 0.55, green: 0.66, blue: 0.73)
        }
    }

    var title: String {
        rawValue.capitalized
    }
}

private struct LatchAccentPaletteKey: EnvironmentKey {
    static let defaultValue: AppAccentPalette = .mint
}

extension EnvironmentValues {
    var latchAccentPalette: AppAccentPalette {
        get { self[LatchAccentPaletteKey.self] }
        set { self[LatchAccentPaletteKey.self] = newValue }
    }
}
