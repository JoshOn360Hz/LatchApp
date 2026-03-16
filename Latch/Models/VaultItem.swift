import Foundation

struct VaultItem: Identifiable, Codable, Hashable {
    var id: UUID
    var service: String
    var username: String
    var passwordReference: String
    var notes: String
    var tags: [String]
    var isFavorite: Bool
    var otpReference: String?
    var otpConfiguration: OTPConfiguration?
    var createdAt: Date
    var updatedAt: Date

    var hasTOTP: Bool {
        otpReference != nil && otpConfiguration != nil
    }
}

struct OTPConfiguration: Codable, Hashable {
    var issuer: String?
    var accountName: String?
    var digits: Int
    var period: Int
}

enum PasswordStrength: String {
    case strong
    case good
    case needsAttention

    var title: String {
        switch self {
        case .strong:
            "Strong"
        case .good:
            "Good"
        case .needsAttention:
            "Needs Attention"
        }
    }
}

struct VaultEntryDraft: Equatable {
    var service = ""
    var username = ""
    var password = ""
    var notes = ""
    var tagsText = ""
    var isFavorite = false
    var otpSecret = ""
    var otpIssuer = ""
    var otpAccountName = ""
    var otpDigits = 6
    var otpPeriod = 30

    init() {}

    init(item: VaultItem, password: String?, otpSecret: String?) {
        service = item.service
        username = item.username
        self.password = password ?? ""
        notes = item.notes
        tagsText = item.tags.joined(separator: ", ")
        isFavorite = item.isFavorite
        self.otpSecret = otpSecret ?? ""
        otpIssuer = item.otpConfiguration?.issuer ?? ""
        otpAccountName = item.otpConfiguration?.accountName ?? item.username
        otpDigits = item.otpConfiguration?.digits ?? 6
        otpPeriod = item.otpConfiguration?.period ?? 30
    }

    var tags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var cleanedOTPSecret: String? {
        let cleaned = otpSecret
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        return cleaned.isEmpty ? nil : cleaned
    }
}
