import Foundation
import LocalAuthentication

struct BiometricAuthService {
    func authenticate(reason: String) async throws {
        let context = LAContext()
        var authError: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            do {
                _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                return
            } catch {
                if let laError = error as? LAError, laError.code != .userFallback {
                    throw error
                }
            }
        }

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            throw BiometricAuthError.unavailable(authError?.localizedDescription ?? "Authentication is not available on this device.")
        }

        _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}

enum BiometricAuthError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            message
        }
    }
}
