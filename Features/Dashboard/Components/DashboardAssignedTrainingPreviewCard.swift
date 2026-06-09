import SwiftUI

struct DashboardAssignedTrainingPreviewCard: View {
    let items: [DashboardTrainingPreviewItem]
    let onTap: () -> Void

    private var visibleItems: [DashboardTrainingPreviewItem] {
        Array(items.prefix(3))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(spacing: 12) {
                    ForEach(visibleItems) { item in
                        trainingRow(item)
                    }
                }

                if items.count > visibleItems.count {
                    moreAssignmentsFooter
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.14),
                        Color.white.opacity(0.075)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.gold.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assigned Training")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(items.count) active assignment\(items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text("View")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold.opacity(0.9))
            }
        }
    }

    private func trainingRow(_ item: DashboardTrainingPreviewItem) -> some View {
        let color = statusColor(for: item)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.20))
                        .frame(width: 34, height: 34)

                    Image(systemName: statusIcon(for: item))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(statusLine(for: item))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(color.opacity(item.progressPercent <= 0 && !item.isOverdue ? 0.92 : 1.0))
                }

                Spacer(minLength: 10)

                Text("\(item.progressPercent)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.16))
                    .clipShape(Capsule())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.13))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(
                            width: max(proxy.size.width * CGFloat(displayedProgress(for: item) / 100), 10),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    color.opacity(0.18),
                    Color.white.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        }
    }

    private var moreAssignmentsFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.gold)

            Text("+ \(items.count - visibleItems.count) more assignment\(items.count - visibleItems.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            Spacer()

            Text("View all")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.gold.opacity(0.9))

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.gold.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.gold.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 2)
    }

    private func displayedProgress(for item: DashboardTrainingPreviewItem) -> Double {
        if item.progressPercent <= 0 {
            return 2
        }

        return Double(item.progressPercent)
    }

    private func statusIcon(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "exclamationmark.triangle.fill"
        }

        if item.progressPercent >= 100 {
            return "checkmark.seal.fill"
        }

        if item.progressPercent > 0 {
            return "clock.fill"
        }

        return "circle.dashed"
    }

    private func statusLine(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "Overdue • \(item.progressText)"
        }

        return item.progressText
    }

    private func statusColor(for item: DashboardTrainingPreviewItem) -> Color {
        if item.isOverdue {
            return .orange
        }

        if item.progressPercent >= 100 {
            return .green
        }

        if item.progressPercent > 0 {
            return AppTheme.gold
        }

        return Color(red: 0.62, green: 0.78, blue: 1.0)
    }
}
