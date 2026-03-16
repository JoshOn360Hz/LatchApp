import SwiftUI

struct VaultEntryEditorView: View {
    @Bindable var model: LatchAppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.latchAccentPalette) private var accentPalette
    let editingItem: VaultItem?

    @Environment(\.dismiss) private var dismiss

    @State private var draft = VaultEntryDraft()
    @State private var errorMessage: String?
    @State private var showingScanner = false
    @State private var isPasswordVisible = false
    @State private var otpSetupMode: OTPSetupMode = .none
    @FocusState private var focusedField: EditorField?

    private var title: String {
        editingItem == nil ? "Add Entry" : "Edit Entry"
    }

    private var isSaveEnabled: Bool {
        !draft.service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                accountCard
                if shouldShowOTPCard {
                    otpCard
                } else {
                    addOTPCard
                }
                detailsCard
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isSaveEnabled)
                }
            }
            .onAppear {
                if editingItem == nil {
                    model.generatePassword(length: 18)
                }
                draft = editingItem.map(model.draft(for:)) ?? model.draftForNewItem()
                isPasswordVisible = false
                otpSetupMode = draft.otpSecret.isEmpty ? .none : .manual
            }
            .alert("Unable to Save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showingScanner) {
                QRCodeScannerView { scannedCode in
                    importScannedOTP(scannedCode)
                    showingScanner = false
                }
            }
            #endif
        }
    }

    private func save() {
        do {
            try model.saveVaultEntry(from: draft, editing: editingItem)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importScannedOTP(_ value: String) {
        do {
            let imported = try model.importedDraft(from: value, fallbackUsername: draft.username)
            draft.otpSecret = imported.secret
            draft.otpIssuer = imported.issuer ?? draft.service
            draft.otpAccountName = imported.accountName ?? draft.username
            draft.otpDigits = imported.digits
            draft.otpPeriod = imported.period
            otpSetupMode = .manual
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var accountCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("Account")

                EditorInputRow(title: "Service") {
                    TextField("Notion, GitHub, Bank", text: $draft.service)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .service)
                        .submitLabel(.next)
                }

                EditorInputRow(title: "Username") {
                    TextField(
                        "",
                        text: $draft.username,
                        prompt: Text("name@example.com").foregroundStyle(accentPalette.color.opacity(colorScheme == .dark ? 0.9 : 0.85))
                    )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Password")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Label(isPasswordVisible ? "Hide" : "Show", systemImage: isPasswordVisible ? "eye.slash" : "eye")
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accentPalette.color)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        Group {
                            if isPasswordVisible {
                                TextField("Password", text: $draft.password)
                                    .textContentType(.password)
                            } else {
                                SecureField("Password", text: $draft.password)
                                    .textContentType(.password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .focused($focusedField, equals: .password)

                        Button {
                            model.generatePassword(length: 18)
                            draft.password = model.generatedPassword
                            isPasswordVisible = true
                        } label: {
                            Image(systemName: "dice.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(accentPalette.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Generate New Password")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.secondaryCardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("Generate a strong password or enter one from an existing account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var addOTPCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Two-Factor Authentication")

                Text("Add a TOTP code if this account uses an authenticator app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    #if canImport(UIKit)
                    Button {
                        otpSetupMode = .scan
                        showingScanner = true
                    } label: {
                        otpActionTile(title: "Scan QR", systemImage: "qrcode.viewfinder", isProminent: true)
                    }
                    .buttonStyle(.plain)
                    #endif

                    Button {
                        otpSetupMode = .manual
                    } label: {
                        otpActionTile(title: "Enter Manually", systemImage: "keyboard", isProminent: false)
                    }
                    .buttonStyle(.plain)
                }

                #if !canImport(UIKit)
                Text("QR scanning is available on iPhone and iPad.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif
            }
        }
    }

    private var otpCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    sectionTitle("Two-Factor Authentication")
                    Spacer()
                    if !draft.otpSecret.isEmpty {
                        StatusPill(title: "Configured", tone: .success)
                    }
                }

                if draft.otpSecret.isEmpty {
                    HStack(spacing: 12) {
                        #if canImport(UIKit)
                        Button {
                            otpSetupMode = .scan
                            showingScanner = true
                        } label: {
                            otpActionTile(title: "Scan QR", systemImage: "qrcode.viewfinder", isProminent: true)
                        }
                        .buttonStyle(.plain)
                        #endif

                        Button {
                            otpSetupMode = .manual
                        } label: {
                            otpActionTile(title: "Enter Manually", systemImage: "keyboard", isProminent: false)
                        }
                        .buttonStyle(.plain)
                    }
                }

                EditorInputRow(title: "Secret") {
                    SecureField("Base32 Secret", text: $draft.otpSecret)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .otpSecret)
                }

                EditorInputRow(title: "Issuer") {
                    TextField("Optional", text: $draft.otpIssuer)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .otpIssuer)
                }

                EditorInputRow(title: "Account Label") {
                    TextField("Optional", text: $draft.otpAccountName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .otpAccountName)
                }

                HStack(spacing: 12) {
                    otpValueCard(title: "Digits", value: "\(draft.otpDigits)")
                    otpValueCard(title: "Period", value: "\(draft.otpPeriod)s")
                }

                VStack(spacing: 12) {
                    Stepper("Digits: \(draft.otpDigits)", value: $draft.otpDigits, in: 6...8)
                    Stepper("Period: \(draft.otpPeriod) sec", value: $draft.otpPeriod, in: 15...60, step: 15)
                }
                .font(.subheadline)

                Button("Remove Two-Factor Code", role: .destructive) {
                    draft.otpSecret = ""
                    draft.otpIssuer = ""
                    draft.otpAccountName = ""
                    draft.otpDigits = 6
                    draft.otpPeriod = 30
                    otpSetupMode = .none
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var detailsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("Details")

                Toggle(isOn: $draft.isFavorite) {
                    Label("Favorite Entry", systemImage: draft.isFavorite ? "star.fill" : "star")
                        .font(.subheadline.weight(.medium))
                }
                .tint(accentPalette.color)

                EditorInputRow(title: "Tags") {
                    TextField("Work, Finance, Personal", text: $draft.tagsText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .tags)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("Optional notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                        .textInputAutocapitalization(.sentences)
                        .padding(16)
                        .background(AppTheme.secondaryCardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .focused($focusedField, equals: .notes)
                }
            }
        }
    }

    private func otpActionTile(title: String, systemImage: String, isProminent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isProminent ? .white : accentPalette.color)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isProminent ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .background(isProminent ? accentPalette.color : AppTheme.secondaryCardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if !isProminent {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accentPalette.color.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private func otpValueCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.secondaryCardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private var shouldShowOTPCard: Bool {
        otpSetupMode != .none || !draft.otpSecret.isEmpty
    }
}

private enum OTPSetupMode {
    case none
    case scan
    case manual
}

private enum EditorField {
    case service
    case username
    case password
    case otpSecret
    case otpIssuer
    case otpAccountName
    case tags
    case notes
}

private struct EditorInputRow<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            content
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.secondaryCardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
