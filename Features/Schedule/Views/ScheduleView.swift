import SwiftUI

struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()

    var body: some View {
        AppScreen(title: "Schedule") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if viewModel.isLoading && viewModel.entries.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let errorMessage = viewModel.errorMessage,
                              viewModel.entries.isEmpty {
                        errorCard(errorMessage)
                    } else if viewModel.entries.isEmpty {
                        emptyCard
                    } else {
                        ForEach(viewModel.entries) { entry in
                            scheduleCard(entry)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            if viewModel.entries.isEmpty {
                await viewModel.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today’s Staffing")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(viewModel.date ?? "Current FirstDue schedule")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.68))

            if let message = viewModel.errorMessage,
               !message.isEmpty,
               !viewModel.entries.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.9))
                    .padding(.top, 4)
            }
        }
        .padding(.bottom, 4)
    }

    private func scheduleCard(_ entry: APIClient.MobileScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)

                    Text(entry.timeRange)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.gold)
                }

                Spacer()

                if let station = entry.station, !station.isEmpty {
                    Text(station)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.82))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if entry.staffing.isEmpty {
                Text("No staffing listed")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.58))
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(entry.staffing.enumerated()), id: \.offset) { _, staff in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: staff.lowercased().contains("vacant") ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(staff.lowercased().contains("vacant") ? .orange : AppTheme.gold)
                                .frame(width: 22)

                            Text(staff)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule unavailable")
                .font(.headline)
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.68))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No schedule entries")
                .font(.headline)
                .foregroundColor(.white)

            Text("No staffing assignments were returned for today.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.68))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        ScheduleView()
    }
}
