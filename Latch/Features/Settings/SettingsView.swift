import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var model: LatchAppModel
    @State private var showingCSVImporter = false
    @State private var importMessage: String?
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

                Picker("Appearance", selection: $model.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
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
}
