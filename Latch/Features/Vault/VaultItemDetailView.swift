import SwiftUI
import UniformTypeIdentifiers

struct VaultItemDetailView: View {
    @Bindable var model: LatchAppModel
    @Environment(\.latchAccentPalette) private var accentPalette
    let item: VaultItem
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var revealedPassword: String?
    @State private var actionMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var exportDocument: OTPCSVDocument?
    @State private var showingCSVExporter = false

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
                    otpCard
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
                        Button {
                            onEdit()
                        } label: {
                            sheetActionLabel(title: "Edit Entry", systemImage: "pencil")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentPalette.color)
                        .frame(maxWidth: .infinity)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            sheetActionLabel(title: "Delete Entry", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Details")
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
            .fileExporter(
                isPresented: $showingCSVExporter,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: exportFilename
            ) { result in
                switch result {
                case .success:
                    actionMessage = "2FA CSV exported."
                case .failure(let error):
                    actionMessage = error.localizedDescription
                }
                exportDocument = nil
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

    private var otpCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LatchSectionHeader(
                    eyebrow: nil,
                    title: "Code",
                    detail: ""
                )

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    otpTimelineContent(for: context.date)
                }
            }
        }
    }

    @ViewBuilder
    private func otpTimelineContent(for date: Date) -> some View {
        if let snapshot = model.totpSnapshot(for: item, at: date) {
            otpSnapshotContent(snapshot)
        } else {
            Text("Unable to generate a code for this secret.")
                .foregroundStyle(.secondary)
        }
    }

    private func otpSnapshotContent(_ snapshot: TOTPSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            otpCodePanel(snapshot)
            otpActionRow(snapshot)
        }
    }

    private func otpCodePanel(_ snapshot: TOTPSnapshot) -> some View {
        let period = item.otpConfiguration?.period ?? 30

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accentPalette.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "lock.badge.clock.fill")
                            .foregroundStyle(accentPalette.color)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    Text("Expires in \(snapshot.secondsRemaining)s")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ProgressView(
                value: Double(period - snapshot.secondsRemaining),
                total: Double(period)
            )
            .tint(accentPalette.color)

            HStack(spacing: 8) {
                StatusPill(title: "\(period)s cycle", tone: .accent)
                if let issuer = item.otpConfiguration?.issuer, !issuer.isEmpty {
                    StatusPill(title: issuer, tone: .neutral)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentPalette.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func otpActionRow(_ snapshot: TOTPSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    model.copyToPasteboard(snapshot.code.replacingOccurrences(of: " ", with: ""))
                    actionMessage = "Code copied."
                } label: {
                    sheetActionLabel(title: "Copy Current Code", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .tint(accentPalette.color)

                Button {
                    Task {
                        guard await model.authorizeSensitiveAction(reason: "Export 2FA setup for \(item.service)") else { return }
                        if let exportCSV = model.exportOTPCSV(for: item) {
                            exportDocument = OTPCSVDocument(text: exportCSV)
                            showingCSVExporter = true
                        } else {
                            actionMessage = "Unable to export this 2FA setup."
                        }
                    }
                } label: {
                    sheetActionLabel(title: "Export 2FA CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }

            Button {
                onEdit()
            } label: {
                sheetActionLabel(title: "Import / Replace 2FA", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
        }
    }

    private var exportFilename: String {
        let cleanedService = item.service
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        return "\(cleanedService.isEmpty ? "two-factor" : cleanedService)-2fa"
    }
}

private struct OTPCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard
            let data = configuration.file.regularFileContents,
            let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
