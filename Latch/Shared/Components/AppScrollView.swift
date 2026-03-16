import SwiftUI

struct AppScrollView<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.latchAccentPalette) private var accentPalette

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppTheme.background(for: colorScheme, palette: accentPalette)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.contentSpacing) {
                    content
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.vertical, 16)
            }
        }
    }
}
