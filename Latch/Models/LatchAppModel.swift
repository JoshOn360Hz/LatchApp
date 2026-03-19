import Observation
import SwiftUI

@MainActor
@Observable
final class LatchAppModel {
    @ObservationIgnored private static let clipboardClearDelay: Duration = .seconds(60)
    @ObservationIgnored private let repository: VaultRepository
    @ObservationIgnored private let keychain: KeychainService
    @ObservationIgnored private let biometricAuth: BiometricAuthService
    @ObservationIgnored private let totpService: TOTPService
    @ObservationIgnored private let otpAuthParser: OTPAuthParser
    @ObservationIgnored private let csvImportService: CSVPasswordImportService
    @ObservationIgnored private let settingsStore: AppSettingsStore
    @ObservationIgnored private var didFinishBootstrapping = false
    @ObservationIgnored private var autoLockTask: Task<Void, Never>?
    @ObservationIgnored private var lastInteractionDate: Date?
    @ObservationIgnored private var lastScenePhase: ScenePhase = .inactive
    @ObservationIgnored private var isUnlockInProgress = false
    @ObservationIgnored private var shouldSkipNextActivationLock = false

    var searchText = ""
    var appearance: AppAppearance = .system {
        didSet { persistSettingsIfNeeded() }
    }
    var accentPalette: AppAccentPalette = .mint {
        didSet { persistSettingsIfNeeded() }
    }
    var autoLockInterval: Double = 60 {
        didSet {
            persistSettingsIfNeeded()
            restartAutoLockTimerIfNeeded()
        }
    }
    var biometricUnlockEnabled = true {
        didSet {
            persistSettingsIfNeeded()
            if biometricUnlockEnabled {
                isLocked = true
            } else {
                isLocked = false
                authenticationError = nil
                autoLockTask?.cancel()
            }
        }
    }
    var clearClipboardEnabled = true {
        didSet { persistSettingsIfNeeded() }
    }
    var prefersSymbols = true {
        didSet { persistSettingsIfNeeded() }
    }
    var prefersNumbers = true {
        didSet { persistSettingsIfNeeded() }
    }
    var hasCompletedOnboarding = false {
        didSet { persistSettingsIfNeeded() }
    }
    var generatedPassword = "V4ult#Signal!28"
    var vaultItems: [VaultItem] = []
    var securityFindings: [SecurityFinding] = []
    var isShowingOnboarding = false
    var isLocked = false {
        didSet {
            if isLocked {
                authenticationError = nil
                autoLockTask?.cancel()
            } else {
                lastInteractionDate = .now
                restartAutoLockTimerIfNeeded()
            }
        }
    }
    var authenticationError: String?

    init() {
        self.repository = VaultRepository()
        self.keychain = KeychainService()
        self.biometricAuth = BiometricAuthService()
        self.totpService = TOTPService()
        self.otpAuthParser = OTPAuthParser()
        self.csvImportService = CSVPasswordImportService()
        self.settingsStore = AppSettingsStore()

        loadSettings()
        loadVault()

        isLocked = hasCompletedOnboarding && biometricUnlockEnabled
        didFinishBootstrapping = true
    }

    var filteredVaultItems: [VaultItem] {
        guard !searchText.isEmpty else { return vaultItems }
        return vaultItems.filter {
            $0.service.localizedCaseInsensitiveContains(searchText)
                || $0.username.localizedCaseInsensitiveContains(searchText)
                || $0.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
        }
    }

    var favoriteItems: [VaultItem] {
        vaultItems.filter(\.isFavorite)
    }

    var totpEnabledCount: Int {
        vaultItems.filter(\.hasTOTP).count
    }

    var healthScore: Int {
        max(12, 100 - securityFindings.reduce(into: 0) { partialResult, finding in
            switch finding.severity {
            case .low:
                partialResult += 4
            case .medium:
                partialResult += 10
            case .high:
                partialResult += 18
            }
        })
    }

    func generatePassword(length: Int) {
        let lowercase = Array("abcdefghjkmnpqrstuvwxyz")
        let uppercase = Array("ABCDEFGHJKMNPQRSTUVWXYZ")
        let numbers = Array("23456789")
        let symbols = Array("!@#$%&*?")

        var pool = lowercase + uppercase
        if prefersNumbers {
            pool += numbers
        }
        if prefersSymbols {
            pool += symbols
        }

        generatedPassword = String((0..<max(length, 8)).map { _ in
            pool.randomElement() ?? "A"
        })
    }

    func draftForNewItem() -> VaultEntryDraft {
        var draft = VaultEntryDraft()
        draft.password = generatedPassword
        return draft
    }

    func draft(for item: VaultItem) -> VaultEntryDraft {
        VaultEntryDraft(
            item: item,
            password: keychain.string(forKey: item.passwordReference),
            otpSecret: item.otpReference.flatMap { keychain.string(forKey: $0) }
        )
    }

    func saveVaultEntry(from draft: VaultEntryDraft, editing item: VaultItem?) throws {
        let normalizedService = draft.service.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = draft.password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedService.isEmpty else {
            throw VaultModelError.missingService
        }
        guard !normalizedUsername.isEmpty else {
            throw VaultModelError.missingUsername
        }
        guard !normalizedPassword.isEmpty else {
            throw VaultModelError.missingPassword
        }

        let passwordReference = item?.passwordReference ?? "pwd-\(UUID().uuidString)"
        try keychain.setString(normalizedPassword, forKey: passwordReference)

        var otpReference = item?.otpReference
        var otpConfiguration: OTPConfiguration?
        if let cleanedSecret = draft.cleanedOTPSecret {
            if otpReference == nil {
                otpReference = "otp-\(UUID().uuidString)"
            }
            try keychain.setString(cleanedSecret, forKey: otpReference!)
            otpConfiguration = OTPConfiguration(
                issuer: emptyToNil(draft.otpIssuer),
                accountName: emptyToNil(draft.otpAccountName) ?? normalizedUsername,
                digits: draft.otpDigits,
                period: draft.otpPeriod
            )
        } else if let existingReference = item?.otpReference {
            keychain.deleteValue(forKey: existingReference)
            otpReference = nil
        }

        let now = Date()
        let updatedItem = VaultItem(
            id: item?.id ?? UUID(),
            service: normalizedService,
            username: normalizedUsername,
            passwordReference: passwordReference,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: draft.tags,
            isFavorite: draft.isFavorite,
            otpReference: otpReference,
            otpConfiguration: otpConfiguration,
            createdAt: item?.createdAt ?? now,
            updatedAt: now
        )

        if let item {
            if let index = vaultItems.firstIndex(where: { $0.id == item.id }) {
                vaultItems[index] = updatedItem
            }
        } else {
            vaultItems.insert(updatedItem, at: 0)
        }

        persistVault()
        refreshSecurityFindings()
    }

    func delete(_ item: VaultItem) {
        keychain.deleteValue(forKey: item.passwordReference)
        if let otpReference = item.otpReference {
            keychain.deleteValue(forKey: otpReference)
        }
        vaultItems.removeAll { $0.id == item.id }
        persistVault()
        refreshSecurityFindings()
    }

    func passwordStrength(for item: VaultItem) -> PasswordStrength {
        guard let password = keychain.string(forKey: item.passwordReference) else {
            return .needsAttention
        }
        return Self.passwordStrength(for: password)
    }

    func passwordValue(for item: VaultItem) -> String? {
        keychain.string(forKey: item.passwordReference)
    }

    func totpSnapshot(for item: VaultItem, at date: Date = .now) -> TOTPSnapshot? {
        guard
            let otpReference = item.otpReference,
            let configuration = item.otpConfiguration,
            let secret = keychain.string(forKey: otpReference)
        else {
            return nil
        }

        return try? totpService.generate(secret: secret, digits: configuration.digits, period: configuration.period, at: date)
    }

    func copyToPasteboard(_ value: String) {
        PasteboardClient.copy(value)

        guard clearClipboardEnabled else { return }

        Task.detached(priority: .utility) {
            try? await Task.sleep(for: Self.clipboardClearDelay)
            PasteboardClient.clearIfUnchanged(value)
        }
    }

    func importedDraft(from scannedCode: String, fallbackUsername: String) throws -> OTPImportedData {
        try otpAuthParser.parse(scannedCode, fallbackAccountName: fallbackUsername)
    }

    func exportOTPCSV(for item: VaultItem) -> String? {
        guard
            let otpReference = item.otpReference,
            let configuration = item.otpConfiguration,
            let secret = keychain.string(forKey: otpReference)
        else {
            return nil
        }

        let accountName = configuration.accountName ?? item.username
        let issuer = emptyToNil(configuration.issuer ?? item.service)
        let otpAuthURL = otpAuthURL(
            secret: secret,
            issuer: issuer,
            accountName: accountName,
            digits: configuration.digits,
            period: configuration.period
        )

        let fields = [
            item.service,
            item.username,
            issuer ?? "",
            accountName,
            secret,
            String(configuration.digits),
            String(configuration.period),
            otpAuthURL
        ]

        let header = "service,username,issuer,account_name,secret,digits,period,otpauth_url"
        let row = fields.map(Self.escapeCSVField).joined(separator: ",")
        return "\(header)\n\(row)"
    }

    private func otpAuthURL(
        secret: String,
        issuer: String?,
        accountName: String,
        digits: Int,
        period: Int
    ) -> String {
        let label = issuer.map { "\($0):\(accountName)" } ?? accountName

        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = "totp"
        components.path = "/\(label)"

        var queryItems = [
            URLQueryItem(name: "secret", value: secret),
            URLQueryItem(name: "digits", value: String(digits)),
            URLQueryItem(name: "period", value: String(period))
        ]

        if let issuer {
            queryItems.append(URLQueryItem(name: "issuer", value: issuer))
        }

        components.queryItems = queryItems
        return components.string ?? ""
    }

    func importPasswords(from url: URL) throws -> PasswordImportSummary {
        let shouldStopAccess = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let records = try csvImportService.parse(data: data)
        var importedCount = 0

        for record in records {
            let passwordReference = "pwd-\(UUID().uuidString)"
            try keychain.setString(record.password, forKey: passwordReference)

            let item = VaultItem(
                id: UUID(),
                service: record.service,
                username: record.username,
                passwordReference: passwordReference,
                notes: record.notes,
                tags: record.tags,
                isFavorite: false,
                otpReference: nil,
                otpConfiguration: nil,
                createdAt: .now,
                updatedAt: .now
            )

            vaultItems.insert(item, at: 0)
            importedCount += 1
        }

        persistVault()
        refreshSecurityFindings()
        return PasswordImportSummary(importedCount: importedCount, skippedCount: max(0, records.count - importedCount))
    }

    func unlockVault() async {
        guard !isUnlockInProgress else { return }

        guard biometricUnlockEnabled else {
            isLocked = false
            authenticationError = nil
            return
        }

        isUnlockInProgress = true
        defer { isUnlockInProgress = false }

        do {
            try await biometricAuth.authenticate(reason: "Unlock your private vault")
            authenticationError = nil
            shouldSkipNextActivationLock = true
            isLocked = false
        } catch {
            authenticationError = error.localizedDescription
        }
    }

    func authorizeSensitiveAction(reason: String) async -> Bool {
        guard biometricUnlockEnabled else {
            return true
        }

        do {
            try await biometricAuth.authenticate(reason: reason)
            authenticationError = nil
            return true
        } catch {
            authenticationError = error.localizedDescription
            return false
        }
    }

    func lockNow() {
        isLocked = biometricUnlockEnabled
    }

    func registerUserInteraction() {
        guard hasCompletedOnboarding, biometricUnlockEnabled, !isLocked else { return }

        let now = Date()
        if let lastInteractionDate, now.timeIntervalSince(lastInteractionDate) < 0.75 {
            return
        }

        lastInteractionDate = now
        restartAutoLockTimerIfNeeded()
    }

    func completeOnboarding(enableBiometricUnlock: Bool, autoLockInterval: Double) {
        biometricUnlockEnabled = enableBiometricUnlock
        self.autoLockInterval = autoLockInterval
        hasCompletedOnboarding = true
        isShowingOnboarding = false
        authenticationError = nil
        shouldSkipNextActivationLock = false
        isLocked = false
    }

    func replayOnboarding() {
        isShowingOnboarding = true
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        let previousScenePhase = lastScenePhase
        lastScenePhase = scenePhase

        switch scenePhase {
        case .background:
            autoLockTask?.cancel()
        case .inactive:
            autoLockTask?.cancel()
        case .active:
            guard hasCompletedOnboarding else { return }

            if isUnlockInProgress {
                return
            }

            if shouldLockOnActivation(previousScenePhase: previousScenePhase) {
                lockForAppOpen()
                return
            }

            if shouldSkipNextActivationLock {
                shouldSkipNextActivationLock = false
            }

            if !evaluateIdleLockIfNeeded() {
                restartAutoLockTimerIfNeeded()
            }
        @unknown default:
            break
        }
    }

    private func restartAutoLockTimerIfNeeded() {
        autoLockTask?.cancel()

        guard hasCompletedOnboarding, biometricUnlockEnabled, !isLocked else { return }

        if lastInteractionDate == nil {
            lastInteractionDate = .now
        }

        autoLockTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    _ = self.evaluateIdleLockIfNeeded()
                }
            }
        }
    }

    private func shouldLockOnActivation(previousScenePhase: ScenePhase) -> Bool {
        guard biometricUnlockEnabled, previousScenePhase != .active else { return false }
        guard !shouldSkipNextActivationLock else { return false }
        return true
    }

    private func lockForAppOpen() {
        isLocked = biometricUnlockEnabled
    }

    private func evaluateIdleLockIfNeeded(referenceDate: Date = .now) -> Bool {
        guard hasCompletedOnboarding, biometricUnlockEnabled, !isLocked else { return false }

        let lastInteraction = lastInteractionDate ?? referenceDate
        guard referenceDate.timeIntervalSince(lastInteraction) >= autoLockInterval else {
            return false
        }

        isLocked = true
        return true
    }

    private func loadSettings() {
        let settings = settingsStore.load()
        appearance = settings.appearance
        accentPalette = settings.accentPalette
        autoLockInterval = settings.autoLockInterval
        biometricUnlockEnabled = settings.biometricUnlockEnabled
        clearClipboardEnabled = settings.clearClipboardEnabled
        prefersSymbols = settings.prefersSymbols
        prefersNumbers = settings.prefersNumbers
        hasCompletedOnboarding = settings.hasCompletedOnboarding
    }

    private func persistSettingsIfNeeded() {
        guard didFinishBootstrapping else { return }
        settingsStore.save(
            AppSettings(
                appearance: appearance,
                accentPalette: accentPalette,
                autoLockInterval: autoLockInterval,
                biometricUnlockEnabled: biometricUnlockEnabled,
                clearClipboardEnabled: clearClipboardEnabled,
                prefersSymbols: prefersSymbols,
                prefersNumbers: prefersNumbers,
                hasCompletedOnboarding: hasCompletedOnboarding
            )
        )
    }

    private func loadVault() {
        if let storedItems = try? repository.load(), !storedItems.isEmpty {
            vaultItems = storedItems.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            vaultItems = []
        }
        refreshSecurityFindings()
    }

    private func persistVault() {
        vaultItems.sort { $0.updatedAt > $1.updatedAt }
        try? repository.save(vaultItems)
    }

    private func refreshSecurityFindings() {
        var findings: [SecurityFinding] = []
        var passwordUsage: [String: [VaultItem]] = [:]

        for item in vaultItems {
            let password = keychain.string(forKey: item.passwordReference) ?? ""
            passwordUsage[password, default: []].append(item)

            let strength = Self.passwordStrength(for: password)
            if strength == .needsAttention {
                findings.append(
                    SecurityFinding(
                        title: "Weak Password",
                        detail: "\(item.service) should use a longer generated password with more variety.",
                        severity: .high,
                        affectedItem: item.service
                    )
                )
            }

            if !item.hasTOTP {
                findings.append(
                    SecurityFinding(
                        title: "Missing 2FA",
                        detail: "\(item.service) does not have a TOTP secret configured yet.",
                        severity: .medium,
                        affectedItem: item.service
                    )
                )
            }
        }

        for (password, items) in passwordUsage where !password.isEmpty && items.count > 1 {
            let services = items.map(\.service).joined(separator: ", ")
            findings.append(
                SecurityFinding(
                    title: "Reused Password",
                    detail: "The same password appears in multiple accounts: \(services).",
                    severity: .high,
                    affectedItem: "\(items.count) accounts"
                )
            )
        }

        if clearClipboardEnabled {
            findings.append(
                SecurityFinding(
                    title: "Clipboard Hygiene",
                    detail: "Auto-clear is enabled as a privacy-friendly default.",
                    severity: .low,
                    affectedItem: "Device"
                )
            )
        }

        securityFindings = findings
    }
    private static func passwordStrength(for password: String) -> PasswordStrength {
        let length = password.count
        let hasUppercase = password.contains(where: \.isUppercase)
        let hasLowercase = password.contains(where: \.isLowercase)
        let hasNumber = password.contains(where: \.isNumber)
        let hasSymbol = password.contains { !$0.isLetter && !$0.isNumber }

        if length >= 14 && hasUppercase && hasLowercase && hasNumber && hasSymbol {
            return .strong
        }
        if length >= 10 && hasUppercase && hasLowercase && (hasNumber || hasSymbol) {
            return .good
        }
        return .needsAttention
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func escapeCSVField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

enum AppAppearance: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum VaultModelError: LocalizedError {
    case missingService
    case missingUsername
    case missingPassword

    var errorDescription: String? {
        switch self {
        case .missingService:
            "Enter a service name."
        case .missingUsername:
            "Enter a username or email."
        case .missingPassword:
            "Enter a password before saving."
        }
    }
}

struct PasswordImportSummary {
    let importedCount: Int
    let skippedCount: Int

    var message: String {
        if skippedCount > 0 {
            "Imported \(importedCount) passwords. Skipped \(skippedCount) rows."
        } else {
            "Imported \(importedCount) passwords."
        }
    }
}
