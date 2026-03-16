import SwiftUI

struct StatusPill: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.latchAccentPalette) private var accentPalette

    let title: String
    let tone: Tone

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            .secondary
        case .accent:
            accentPalette.color
        case .success:
            AppTheme.success
        case .warning:
            AppTheme.warning
        case .danger:
            AppTheme.danger
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            AppTheme.pillFill(for: colorScheme)
        case .accent:
            accentPalette.color.opacity(colorScheme == .dark ? 0.18 : 0.14)
        case .success:
            AppTheme.success.opacity(colorScheme == .dark ? 0.18 : 0.14)
        case .warning:
            AppTheme.warning.opacity(colorScheme == .dark ? 0.20 : 0.14)
        case .danger:
            AppTheme.danger.opacity(colorScheme == .dark ? 0.18 : 0.14)
        }
    }

    enum Tone {
        case neutral
        case accent
        case success
        case warning
        case danger
    }
}
