import SwiftUI

struct DashboardUpdateBlock: View {
    let update: DashboardBulletin

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(update.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text(update.message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.82))

            if let updatedAt = update.updatedAt, !updatedAt.isEmpty {
                Text(updatedAt)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
