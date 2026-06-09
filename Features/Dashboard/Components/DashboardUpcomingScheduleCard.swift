import SwiftUI

struct DashboardUpcomingScheduleCard: View {
    let schedule: APIClient.MobileUpcomingScheduleResponse
    let shift: APIClient.MobileUpcomingShift
    let onTap: () -> Void

    private var statusText: String {
        schedule.isWorkingNow ? "Working now" : "Next scheduled shift"
    }

    private var stationLine: String {
        [shift.station, shift.assignment]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .joined(separator: " • ")
    }

    private var detailLine: String {
        if !stationLine.isEmpty {
            return stationLine
        }

        return shift.title
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusText.uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundStyle(AppTheme.gold)
                            .tracking(0.6)

                        Text(shift.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 7) {
                    if schedule.isWorkingNow {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7, weight: .bold))

                            Text("Currently working")
                                .font(.caption2.weight(.black))
                                .tracking(0.4)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.14))
                        .clipShape(Capsule())
                    }

                    Text(shift.timeRange)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(detailLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)

                    if let date = shift.date, !date.isEmpty {
                        Text(date)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(schedule.isWorkingNow ? Color.green.opacity(0.75) : AppTheme.gold.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
