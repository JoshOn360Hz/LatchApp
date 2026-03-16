import SwiftUI

struct VaultLockView: View {
    @Bindable var model: LatchAppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.latchAccentPalette) private var accentPalette

    var body: some View {
        ZStack {
            AppTheme.background(for: colorScheme, palette: accentPalette)
                .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.95 : 0.95))
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(accentPalette.color.opacity(0.14))
                        .frame(width: 88, height: 88)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(accentPalette.color)
                }

                VStack(spacing: 8) {
                    Text("Latch Is Locked")
                        .font(.title.weight(.bold))

                    Text("Authenticate to access your vault.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await model.unlockVault()
                    }
                } label: {
                    Label("Authenticate", systemImage: "lock.open.fill")
                        .frame(minWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentPalette.color)

                if let authenticationError = model.authenticationError {
                    Text(authenticationError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.danger)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }
            }
            .task {
                await model.unlockVault()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }
}
