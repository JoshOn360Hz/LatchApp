import SwiftUI

struct VaultItemDetailView: View {
    @Bindable var model: LatchAppModel
    @Environment(\.latchAccentPalette) private var accentPalette
    let item: VaultItem
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var revealedPassword: String?
    @State private var actionMessage: String?
    @State private var showingDeleteConfirmation = false

    private var passwordStrength: PasswordStrength {
        model.passwordStrength(for: item)
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 14) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(accentPalette.color.opacity(0.12))
                                .frame(width: 54, height: 54)
                                .overlay {
                                    Image(systemName: item.hasTOTP ? "lock.badge.clock.fill" : "lock.fill")
                                        .font(.title3)
                                        .foregroundStyle(accentPalette.color)
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.service)
                                    .font(.title2.weight(.bold))
                                Text(item.username)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        HStack(spacing: 8) {
                            StatusPill(title: item.hasTOTP ? "2FA Ready" : "2FA Missing", tone: item.hasTOTP ? .success : .warning)
                            StatusPill(title: passwordStrength.title, tone: strengthTone(passwordStrength))
                            if item.isFavorite {
                                StatusPill(title: "Favorite", tone: .accent)
                            }
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        LatchSectionHeader(
                            eyebrow: nil,
                            title: "Password",
                            detail: nil
                        )

                        HStack(spacing: 8) {
                            StatusPill(title: passwordStrength.title, tone: strengthTone(passwordStrength))
                            StatusPill(title: "Stored in Keychain", tone: .neutral)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(accentPalette.color.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: revealedPassword == nil ? "lock.fill" : "key.fill")
                                            .foregroundStyle(accentPalette.color)
                                    }

                                VStack(alignment: .leading, spacing: 8) {
                                    if let revealedPassword {
                                        Text(revealedPassword)
                                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("••••••••••••••••")
                                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(revealedPassword == nil ? "Hidden until you authenticate." : "Visible for this session.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accentPalette.color.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        HStack(spacing: 10) {
                            Button {
                                if revealedPassword != nil {
                                    revealedPassword = nil
                                } else {
                                    Task {
                                        guard await model.authorizeSensitiveAction(reason: "Reveal password for \(item.service)") else { return }
                                        revealedPassword = model.passwordValue(for: item)
                                    }
                                }
                            } label: {
                                sheetActionLabel(
                                    title: revealedPassword == nil ? "Reveal Password" : "Hide Password",
                                    systemImage: revealedPassword == nil ? "eye" : "eye.slash"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accentPalette.color)

                            Button {
                                Task {
                                    guard await model.authorizeSensitiveAction(reason: "Copy password for \(item.service)") else { return }
                                    if let password = model.passwordValue(for: item) {
                                        model.copyToPasteboard(password)
                                        actionMessage = "Password copied."
                                    }
                                }
                            } label: {
                                sheetActionLabel(title: "Copy Password", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if item.hasTOTP {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            LatchSectionHeader(
                                eyebrow: nil,
                                title: "Live two-factor code",
                                detail: ""
                            )

                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                if let snapshot = model.totpSnapshot(for: item, at: context.date) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(snapshot.code)
                                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                                        Text("Authenticator code")
                                            .font(.subheadline.weight(.semibold))
                                        StatusPill(title: "Refreshes in \(snapshot.secondsRemaining)s", tone: .accent)
                                    }
                                } else {
                                    Text("Unable to generate a code for this secret.")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Button("Copy Current Code") {
                                if let snapshot = model.totpSnapshot(for: item) {
                                    model.copyToPasteboard(snapshot.code.replacingOccurrences(of: " ", with: ""))
                                    actionMessage = "Code copied."
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if !item.notes.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LatchSectionHeader(eyebrow: nil, title: "Account context", detail: "")
                            Text(item.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !item.tags.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LatchSectionHeader(eyebrow: nil, title: "Organization", detail: "Quick visual grouping for search and browsing.")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(item.tags, id: \.self) { tag in
                                        StatusPill(title: tag, tone: .neutral)
                                    }
                                }
                            }
                        }
                    }
                }

                SurfaceCard {
                    HStack(spacing: 10) {
                        Button("Edit Entry") {
                            onEdit()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentPalette.color)
                        .frame(maxWidth: .infinity)

                        Button("Delete Entry", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Entry Detail")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete this entry?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    model.delete(item)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the saved metadata and deletes the associated Keychain secrets.")
            }
            .alert("Latch", isPresented: Binding(
                get: { actionMessage != nil },
                set: { if !$0 { actionMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionMessage ?? "")
            }
        }
    }

    private func strengthTone(_ strength: PasswordStrength) -> StatusPill.Tone {
        switch strength {
        case .strong:
            .success
        case .good:
            .warning
        case .needsAttention:
            .danger
        }
    }

    private func sheetActionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .imageScale(.medium)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 22)
    }
}
