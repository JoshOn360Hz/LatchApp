import SwiftUI

struct EmptyStateCard: View {
    @Environment(\.latchAccentPalette) private var accentPalette

    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(accentPalette.color)
                    .frame(width: 40, height: 40)
                    .background(accentPalette.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }
}
