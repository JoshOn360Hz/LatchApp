import SwiftUI

struct PasswordGeneratorView: View {
    @Bindable var model: LatchAppModel
    @Environment(\.latchAccentPalette) private var accentPalette

    @State private var length = 18.0

    var body: some View {
        NavigationStack {
            AppScrollView {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        LatchSectionHeader(
                            eyebrow: nil,
                            title: "Generate a new Random password",
                            detail: ""
                        )

                        passwordOutputCard

                        HStack(spacing: 12) {
                            Button {
                                model.generatePassword(length: Int(length))
                            } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accentPalette.color)

                            Button {
                                model.copyToPasteboard(model.generatedPassword)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        LatchSectionHeader(
                            eyebrow: nil,
                            title: "Password Profile",
                            detail: "Adjust the passwords complexity"
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Length")
                                Spacer()
                                StatusPill(title: "\(Int(length)) characters", tone: .neutral)
                            }

                            Slider(value: $length, in: 12...32, step: 1)
                                .tint(accentPalette.color)
                        }

                        Toggle("Include numbers", isOn: $model.prefersNumbers)
                        Toggle("Include symbols", isOn: $model.prefersSymbols)
                    }
                }
            }
            .navigationTitle("Generator")
            .onAppear {
                model.generatePassword(length: Int(length))
            }
        }
    }

    private var passwordOutputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.generatedPassword)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Ready to move into a vault entry.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentPalette.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
