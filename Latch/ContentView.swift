import SwiftUI

struct ContentView: View {
    @Bindable var model: LatchAppModel

    var body: some View {
        TabView {
            VaultHomeView(model: model)
                .tabItem {
                    Label("Vault", systemImage: "lock.shield")
                }

            PasswordGeneratorView(model: model)
                .tabItem {
                    Label("Generator", systemImage: "key.horizontal")
                }

            SecurityCenterView(model: model)
                .tabItem {
                    Label("Security", systemImage: "checkmark.shield")
                }

            SettingsView(model: model)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .tint(model.accentPalette.color)
        .environment(\.latchAccentPalette, model.accentPalette)
        .overlay {
            if model.isLocked {
                VaultLockView(model: model)
                    .transition(.opacity)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !model.hasCompletedOnboarding },
                set: { _ in }
            )
        ) {
            OnboardingView(model: model)
                .interactiveDismissDisabled()
        }
        .animation(.smooth, value: model.isLocked)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    model.registerUserInteraction()
                },
            including: .all
        )
    }
}

#Preview {
    ContentView(model: LatchAppModel())
}
