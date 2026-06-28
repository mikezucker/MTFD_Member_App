import SwiftUI

struct DashboardRecentCallsCard: View {
    let calls: [RecentDepartmentCall]
    let onTap: () -> Void

    var body: some View {
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

            DashboardScrollableList(itemCount: calls.count, visibleItemLimit: 4, maxHeight: 300) {
                VStack(spacing: 8) {
                    ForEach(calls) { call in
                        callRow(call)
                    }
                }
            }

            Button(action: onTap) {
                HStack {
                    Text("View all past dispatches")
                        .font(.caption.bold())

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                }
                .foregroundStyle(AppTheme.gold)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func callRow(_ call: RecentDepartmentCall) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.gold.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: iconName(for: call.title))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.gold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(call.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(call.address)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption2.weight(.bold))

                    Text(call.timestamp)
                        .lineLimit(1)

                    if !call.units.isEmpty {
                        Text("/")
                            .foregroundStyle(.white.opacity(0.34))

                        Image(systemName: "truck.box.fill")
                            .font(.caption2.weight(.bold))

                        Text(call.units.prefix(5).joined(separator: ", "))
                            .lineLimit(1)
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func iconName(for title: String) -> String {
        let normalized = title.lowercased()

        if normalized.contains("fire") || normalized.contains("alarm") {
            return "flame.fill"
        }

        if normalized.contains("ems") || normalized.contains("medical") || normalized.contains("sick") {
            return "cross.case.fill"
        }

        if normalized.contains("mva") || normalized.contains("accident") {
            return "car.fill"
        }

        return "bell.fill"
    }
}
