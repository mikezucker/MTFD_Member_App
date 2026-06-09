import SwiftUI

struct DashboardRecentCallsCard: View {
    let calls: [RecentDepartmentCall]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("Latest dispatches")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("View")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold.opacity(0.9))
                }

                VStack(spacing: 10) {
                    ForEach(calls.prefix(3)) { call in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 8) {
                                Text(call.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Spacer()

                                Text(call.timestamp)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.52))
                                    .lineLimit(1)
                            }

                            Text(call.address)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                                .lineLimit(1)

                            if let incidentNumber = call.incidentNumber,
                               !incidentNumber.isEmpty {
                                Text(incidentNumber)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
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
