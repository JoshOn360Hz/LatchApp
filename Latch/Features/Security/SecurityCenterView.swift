import SwiftUI

struct SecurityCenterView: View {
    @Bindable var model: LatchAppModel

    var body: some View {
        NavigationStack {
            AppScrollView {
                securityScoreCard

                VStack(spacing: 12) {
                    if model.securityFindings.isEmpty {
                        EmptyStateCard(
                            title: "No current findings",
                            detail: "Your local vault configuration looks healthy right now.",
                            systemImage: "checkmark.shield"
                        )
                    } else {
                        ForEach(model.securityFindings) { finding in
                            SecurityFindingRow(finding: finding)
                        }
                    }
                }
            }
            .navigationTitle("Security")
        }
    }

    private var securityScoreCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LatchSectionHeader(
                    eyebrow: nil,
                    title: "Security Summary",
                    detail: "Review weak passwords, missing two-factor authentication, and reused credentials across your vault."
                )

                HStack {
                    scoreBlock(value: "\(model.healthScore)", title: "Health Score", tone: .accent)
                    Spacer()
                    scoreBlock(value: "\(model.totpEnabledCount)", title: "2FA Enabled", tone: .success)
                    Spacer()
                    scoreBlock(value: "\(model.securityFindings.count)", title: "Signals", tone: .warning)
                }
            }
        }
    }

    private func scoreBlock(value: String, title: String, tone: StatusPill.Tone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusPill(title: title, tone: tone)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
    }
}

private struct SecurityFindingRow: View {
    let finding: SecurityFinding

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(finding.title, systemImage: severityIcon)
                        .font(.headline)
                        .foregroundStyle(severityColor)
                    Spacer()
                    StatusPill(title: finding.affectedItem, tone: .neutral)
                }

                Text(finding.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Text(recommendation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var severityColor: Color {
        switch finding.severity {
        case .low:
            AppTheme.success
        case .medium:
            AppTheme.warning
        case .high:
            AppTheme.danger
        }
    }

    private var severityIcon: String {
        switch finding.severity {
        case .low:
            "checkmark.circle.fill"
        case .medium:
            "exclamationmark.triangle.fill"
        case .high:
            "flame.fill"
        }
    }

    private var recommendation: String {
        switch finding.severity {
        case .low:
            "This is informational and already aligned with a stronger privacy posture."
        case .medium:
            "This is worth fixing soon to reduce avoidable account risk."
        case .high:
            "This should be addressed first because it has the highest security impact."
        }
    }
}
