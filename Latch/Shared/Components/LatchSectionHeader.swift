import SwiftUI

struct LatchSectionHeader: View {
    @Environment(\.latchAccentPalette) private var accentPalette

    let eyebrow: String?
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentPalette.color)
            }

            Text(title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
