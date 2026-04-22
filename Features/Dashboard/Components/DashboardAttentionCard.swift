import SwiftUI

struct DashboardAttentionCard: View {
    let item: DashboardAttentionItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {

                // Title
                Text(item.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                // Subtitle (this replaced priorityText)
                Text(item.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))

                // Optional action label
                if let actionLabel = item.actionLabel {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.18))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.24, blue: 0.48),
                                Color(red: 0.08, green: 0.18, blue: 0.38)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardAttentionCard(
        item: DashboardAttentionItem(
            title: "Assigned Training",
            subtitle: "You have training items ready",
            actionLabel: "Open",
            destination: .trainingAssigned
        ),
        onTap: {}
    )
}
