import SwiftUI

struct OnboardingView: View {
    @Bindable var model: LatchAppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.latchAccentPalette) private var accentPalette

    @State private var currentPage = 0
    @State private var enableBiometricUnlock: Bool
    @State private var autoLockInterval: Double

    init(model: LatchAppModel) {
        self.model = model
        _enableBiometricUnlock = State(initialValue: model.biometricUnlockEnabled)
        _autoLockInterval = State(initialValue: model.autoLockInterval)
    }

    var body: some View {
        ZStack {
            AppTheme.background(for: colorScheme, palette: accentPalette)
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage
                    .tag(0)

                howToUsePage
                    .tag(1)

                setupPage
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth, value: currentPage)
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            VStack(spacing: 14) {
                Text("Welcome to Latch")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Protect passwords and two-factor codes in one local-first vault")
                    .font(.title3)
                    .foregroundStyle(.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            VStack(spacing: 14) {
                OnboardingFeatureRow(icon: "lock.doc", text: "Store passwords with Keychain-backed secret storage")
                OnboardingFeatureRow(icon: "qrcode.viewfinder", text: "Scan authenticator QR codes and keep 2FA nearby")
                OnboardingFeatureRow(icon: "shield.lefthalf.filled", text: "Customise Face ID and auto-lock behavior.")
            }
            .padding(.horizontal, 34)
            .padding(.top, 10)

            Spacer()

            Text("Swipe to continue")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.bottom, 50)
        }
    }

    private var howToUsePage: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(accentPalette.color)
                    .padding(.bottom, 10)

                Text("How to Use Latch")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 24) {
                InstructionStepRow(
                    number: "1",
                    title: "Add your accounts",
                    description: "Create a vault entry for each service and save usernames, passwords, notes, and tags in one place."
                )

                InstructionStepRow(
                    number: "2",
                    title: "Attach your 2FA codes",
                    description: "Scan an authenticator QR code or paste a secret so Latch can generate your rotating sign-in codes."
                )

                InstructionStepRow(
                    number: "3",
                    title: "Unlock and copy quickly",
                    description: "Use Face ID when enabled, then open any item to copy a password or view the latest TOTP code."
                )
            }
            .padding(.horizontal, 30)

            Spacer()

            Text("Swipe to continue")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.bottom, 50)
        }
    }

    private var setupPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(accentPalette.color)
                    .padding(.bottom, 10)

                Text("Security Defaults")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                PermissionStyleRow(
                    icon: "faceid",
                    title: "Biometric unlock",
                    description: enableBiometricUnlock
                        ? "Face ID will be required before someone can re-open your vault."
                        : "Latch will open directly until you enable biometric unlock in Settings."
                )

                PermissionStyleRow(
                    icon: "timer",
                    title: "Auto-lock after \(lockLabel)",
                    description: "If the app stays in the background longer than this, the vault locks on your next return."
                )

                PermissionStyleRow(
                    icon: "key.fill",
                    title: "Secrets stay local",
                    description: "Passwords and OTP secrets are stored on-device with Keychain-backed protection."
                )
            }
            .padding(.horizontal, 30)

            VStack(spacing: 18) {
                Toggle("Use Face ID to unlock Latch", isOn: $enableBiometricUnlock)
                    .tint(accentPalette.color)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Lock after")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(lockLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentPalette.color)
                    }

                    Slider(value: $autoLockInterval, in: 15...180, step: 15)
                        .tint(accentPalette.color)
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            VStack(spacing: 16) {
                Button(action: completeOnboarding) {
                    HStack {
                        Text("Get Started")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentPalette.color)

                Text("You can change these settings later from the Settings tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }

    private var lockLabel: String {
        "\(Int(autoLockInterval)) sec"
    }

    private func completeOnboarding() {
        model.completeOnboarding(
            enableBiometricUnlock: enableBiometricUnlock,
            autoLockInterval: autoLockInterval
        )
    }
}

private struct OnboardingFeatureRow: View {
    @Environment(\.latchAccentPalette) private var accentPalette

    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(accentPalette.color)
                .frame(width: 40)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

private struct InstructionStepRow: View {
    @Environment(\.latchAccentPalette) private var accentPalette

    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentPalette.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Text(number)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accentPalette.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

private struct PermissionStyleRow: View {
    @Environment(\.latchAccentPalette) private var accentPalette

    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentPalette.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(accentPalette.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(accentPalette.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    OnboardingView(model: LatchAppModel())
}
