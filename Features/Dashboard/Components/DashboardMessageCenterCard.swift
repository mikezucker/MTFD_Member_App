import SwiftUI

struct DashboardMessageCenterCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Messages")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Department, station, training, document, and operational updates.")
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
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
