import Foundation

struct SecurityFinding: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let severity: FindingSeverity
    let affectedItem: String
}

enum FindingSeverity: String {
    case low
    case medium
    case high
}
