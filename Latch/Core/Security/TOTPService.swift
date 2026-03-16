import CryptoKit
import Foundation

struct TOTPSnapshot: Hashable {
    let code: String
    let secondsRemaining: Int
}

struct TOTPService {
    func generate(secret: String, digits: Int = 6, period: Int = 30, at date: Date) throws -> TOTPSnapshot {
        guard let secretData = Self.base32Decode(secret) else {
            throw TOTPError.invalidSecret
        }

        let unixTime = UInt64(date.timeIntervalSince1970)
        let counter = unixTime / UInt64(period)
        let remaining = period - Int(unixTime % UInt64(period))

        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: MemoryLayout<UInt64>.size)
        let key = SymmetricKey(data: secretData)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hash = Array(hmac)
        let offset = Int(hash.last! & 0x0F)
        let truncatedHash = hash[offset...offset + 3]
        var number = UInt32(truncatedHash[truncatedHash.startIndex] & 0x7F) << 24
        number |= UInt32(truncatedHash[truncatedHash.startIndex + 1]) << 16
        number |= UInt32(truncatedHash[truncatedHash.startIndex + 2]) << 8
        number |= UInt32(truncatedHash[truncatedHash.startIndex + 3])

        let modulo = UInt32(pow(10, Float(digits)))
        let otp = number % modulo
        let code = String(format: "%0*u", digits, otp)
        return TOTPSnapshot(
            code: code.chunked(every: 3).joined(separator: " "),
            secondsRemaining: remaining
        )
    }

    private static func base32Decode(_ string: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        let lookup = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, UInt8($0)) })

        let filtered = string.uppercased().filter { lookup[$0] != nil }
        guard !filtered.isEmpty else { return nil }

        var buffer: UInt32 = 0
        var bitsLeft: Int = 0
        var bytes: [UInt8] = []

        for character in filtered {
            guard let value = lookup[character] else { continue }
            buffer = (buffer << 5) | UInt32(value)
            bitsLeft += 5

            if bitsLeft >= 8 {
                let shift = bitsLeft - 8
                let byte = UInt8((buffer >> UInt32(shift)) & 0xFF)
                bytes.append(byte)
                bitsLeft -= 8
                buffer &= (1 << UInt32(bitsLeft)) - 1
            }
        }

        return Data(bytes)
    }
}

enum TOTPError: LocalizedError {
    case invalidSecret

    var errorDescription: String? {
        "The TOTP secret is invalid."
    }
}

private extension String {
    func chunked(every count: Int) -> [String] {
        stride(from: 0, to: self.count, by: count).map { index in
            let start = self.index(self.startIndex, offsetBy: index)
            let end = self.index(start, offsetBy: count, limitedBy: self.endIndex) ?? self.endIndex
            return String(self[start..<end])
        }
    }
}
