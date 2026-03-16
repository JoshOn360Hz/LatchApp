import Foundation

struct OTPImportedData {
    let secret: String
    let issuer: String?
    let accountName: String?
    let digits: Int
    let period: Int
}

struct OTPAuthParser {
    func parse(_ input: String, fallbackAccountName: String? = nil) throws -> OTPImportedData {
        guard let url = URL(string: input), url.scheme == "otpauth" else {
            throw OTPAuthParserError.invalidURL
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let secret = queryItems.first(where: { $0.name == "secret" })?.value?.uppercased()
        let issuer = queryItems.first(where: { $0.name == "issuer" })?.value
        let digits = Int(queryItems.first(where: { $0.name == "digits" })?.value ?? "") ?? 6
        let period = Int(queryItems.first(where: { $0.name == "period" })?.value ?? "") ?? 30

        let label = url.path.removingPercentEncoding?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let labelParts = label.split(separator: ":", maxSplits: 1).map(String.init)
        let derivedIssuer = labelParts.count == 2 ? labelParts[0] : issuer
        let accountName = labelParts.count == 2 ? labelParts[1] : (label.isEmpty ? fallbackAccountName : label)

        guard let secret, !secret.isEmpty else {
            throw OTPAuthParserError.missingSecret
        }

        return OTPImportedData(
            secret: secret,
            issuer: issuer ?? derivedIssuer,
            accountName: accountName ?? fallbackAccountName,
            digits: digits,
            period: period
        )
    }
}

enum OTPAuthParserError: LocalizedError {
    case invalidURL
    case missingSecret

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Scan or paste a valid otpauth:// URL."
        case .missingSecret:
            "The QR code did not contain a TOTP secret."
        }
    }
}
