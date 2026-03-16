import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Bindable var model: LatchAppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCSVImporter = false
    @State private var importMessage: String?
    @State private var selectedAppIcon = AppIconOption.default
    @State private var appIconError: String?
    private let githubURL = URL(string: "https://github.com/JoshOn360Hz/LatchApp")

    var body: some View {
        NavigationStack {
            AppScrollView {
                appearanceSection
                accentSection
                importSection
                securitySection
                aboutSection
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $showingCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                handleImport(result)
            }
            .alert("Import CSV", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
            .alert("App Icon", isPresented: Binding(
                get: { appIconError != nil },
                set: { if !$0 { appIconError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appIconError ?? "")
            }
            .task {
                refreshSelectedAppIcon()
            }
        }
    }

    private var appearanceSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LatchSectionHeader(
                    eyebrow: nil,
                    title: "Appearance",
                    detail: nil
                )

                HStack(spacing: 8) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Button {
                            model.appearance = appearance
                        } label: {
                            Text(appearance.title)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(model.appearance == appearance ? model.accentPalette.color : AppTheme.secondaryCardFill(for: colorScheme))
                                )
                                .foregroundStyle(model.appearance == appearance ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var accentSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LatchSectionHeader(
                    eyebrow: nil,
                    title: "Color Theme",
                    detail: nil
                )

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 14) {
                    ForEach(AppAccentPalette.allCases) { palette in
                        Button {
                            model.accentPalette = palette
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(palette.color)
                                        .frame(width: 42, height: 42)

                                    if model.accentPalette == palette {
                                        Circle()
                                            .strokeBorder(Color.primary.opacity(0.28), lineWidth: 2)
                                            .frame(width: 52, height: 52)
                                    }
                                }

                                Text(palette.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var securitySection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LatchSectionHeader(
                    eyebrow: nil,
                    title: "Lock Behavior",
                    detail: nil
                )

                Toggle(isOn: $model.biometricUnlockEnabled) {
                    Label("Biometric Unlock", systemImage: "faceid")
                }

                Toggle(isOn: $model.clearClipboardEnabled) {
                    Label("Auto-Clear Clipboard", systemImage: "doc.on.clipboard")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Auto-lock")
                        Spacer()
                        StatusPill(title: "\(Int(model.autoLockInterval)) sec", tone: .neutral)
                    }

                    Slider(value: $model.autoLockInterval, in: 15...180, step: 15)
                        .tint(model.accentPalette.color)
                }

                Button("Lock Vault Now") {
                    model.lockNow()
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Alternate App Icon")
                        .font(.subheadline.weight(.semibold))

                    ForEach(AppIconOption.allCases) { icon in
                        Button {
                            Task {
                                await setAppIcon(icon)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                iconPreview(for: icon)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(icon.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(icon.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedAppIcon == icon {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(model.accentPalette.color)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppTheme.secondaryCardFill(for: colorScheme))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedAppIcon == icon)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LatchSectionHeader(
                    eyebrow: nil,
                    title: "Open Source",
                    detail: nil
                )

                Text("Latch is open source.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let githubURL {
                    Link(destination: githubURL) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var importSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LatchSectionHeader(
                    eyebrow: nil,
                    title: "Import Passwords",
                    detail: nil
                )

                Text("Import a CSV export from Apple Passwords, Google Password Manager, or another password manager.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    showingCSVImporter = true
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.accentPalette.color)
            }
        }
    }
    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let summary = try model.importPasswords(from: url)
            importMessage = summary.message
        } catch {
            importMessage = error.localizedDescription
        }
    }

    private func refreshSelectedAppIcon() {
        selectedAppIcon = AppIconOption(iconName: UIApplication.shared.alternateIconName)
    }

    @MainActor
    private func setAppIcon(_ icon: AppIconOption) async {
        guard UIApplication.shared.supportsAlternateIcons else {
            appIconError = "Alternate app icons are not available on this device."
            return
        }

        do {
            try await UIApplication.shared.setAlternateIconName(icon.iconName)
            selectedAppIcon = icon
        } catch {
            appIconError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func iconPreview(for icon: AppIconOption) -> some View {
        Image(icon.previewAssetName)
            .resizable()
            .scaledToFill()
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private enum AppIconOption: String, CaseIterable, Identifiable {
    case `default`
    case calc1 = "calc-icon-1"
    case calc2 = "calc-icon-2"

    var id: Self { self }

    var iconName: String? {
        switch self {
        case .default:
            nil
        case .calc1, .calc2:
            rawValue
        }
    }

    var title: String {
        switch self {
        case .default:
            "Default"
        case .calc1:
            "Calc 1"
        case .calc2:
            "Calc 2"
        }
    }

    var detail: String {
        switch self {
        case .default:
            "Use the default icon."
        case .calc1:
            "Use alternate icon 1."
        case .calc2:
            "Use alternate icon 2."
        }
    }

    var previewAssetName: String {
        switch self {
        case .default:
            "logo"
        case .calc1:
            "calc-1-preview"
        case .calc2:
            "calc-2-preview"
        }
    }

    init(iconName: String?) {
        self = AppIconOption(rawValue: iconName ?? "") ?? .default
    }
}
