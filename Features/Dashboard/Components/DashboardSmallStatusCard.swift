import SwiftUI

struct DashboardSmallStatusCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var requiresAttention = false
    let onTap: () -> Void


    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                DashboardColorIcon(systemImage: requiresAttention ? "exclamationmark.triangle.fill" : systemImage, size: 28, frameSize: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(requiresAttention ? Color.red : .white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold.opacity(0.9))
            }
            .padding(16)
            .background(requiresAttention ? Color.red.opacity(0.18) : Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(requiresAttention ? Color.red.opacity(0.8) : Color.white.opacity(0.12), lineWidth: requiresAttention ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}
