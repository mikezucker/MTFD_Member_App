import Foundation
import Combine

struct ScheduleOutlookDay: Identifiable {
    let id: String
    let label: String
    let date: String
    let entries: [APIClient.MobileScheduleEntry]
}

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var date: String?
    @Published var entries: [APIClient.MobileScheduleEntry] = []
    @Published var outlookDays: [ScheduleOutlookDay] = []

    private var requestTask: Task<Void, Never>?

    func load() async {
        await performLoad(outlookCount: nil)
    }

    func loadOutlookDays(count: Int = 4) async {
        await performLoad(outlookCount: count)
    }

    private func performLoad(outlookCount: Int?) async {
        // Keep the network work alive when SwiftUI cancels the refresh gesture.
        if let requestTask {
            await requestTask.value
            return
        }
        isLoading = true
        errorMessage = nil
        let task = Task { @MainActor [self] in
            defer { isLoading = false; requestTask = nil }
            if let outlookCount {
                await fetchOutlookDays(count: outlookCount)
            } else {
                do {
                    let response = try await APIClient.shared.fetchMobileSchedule()
                    if response.success {
                        date = response.date
                        entries = response.entries
                    } else {
                        errorMessage = response.message ?? "Schedule unavailable."
                    }
                } catch {
                    if !isCancellation(error) { errorMessage = error.localizedDescription }
                }
            }
        }
        requestTask = task
        await task.value
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let error = error as? URLError { return error.code == .cancelled }
        if let error = error as? APIClient.APIError, case .networkError(let urlError) = error {
            return urlError.code == .cancelled
        }
        return false
    }

    private func fetchOutlookDays(count: Int) async {
        let apiDateFormatter = DateFormatter()
        apiDateFormatter.calendar = Calendar(identifier: .gregorian)
        apiDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        apiDateFormatter.dateFormat = "yyyy-MM-dd"

        let labelFormatter = DateFormatter()
        labelFormatter.calendar = Calendar(identifier: .gregorian)
        labelFormatter.locale = Locale(identifier: "en_US_POSIX")
        labelFormatter.dateFormat = "EEE"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var days: [ScheduleOutlookDay] = []

        for offset in 0..<count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else {
                continue
            }

            let dateString = apiDateFormatter.string(from: day)
            let label = offset == 0 ? "Today" : labelFormatter.string(from: day)

            do {
                let response = try await APIClient.shared.fetchMobileSchedule(date: dateString)

                days.append(
                    ScheduleOutlookDay(
                        id: dateString,
                        label: label,
                        date: response.date ?? dateString,
                        entries: response.entries
                    )
                )

                if offset == 0 {
                    date = response.date
                    entries = response.entries
                }

                if !response.success {
                    errorMessage = response.message ?? "Schedule unavailable."
                }

            } catch {
                if isCancellation(error) { return }
                days.append(
                    ScheduleOutlookDay(
                        id: dateString,
                        label: label,
                        date: dateString,
                        entries: outlookDays.first(where: { $0.id == dateString })?.entries ?? []
                    )
                )

                if errorMessage == nil {
                    errorMessage = error.localizedDescription
                }
            }
        }

        outlookDays = days
    }

    func refresh() async {
        if outlookDays.isEmpty {
            await load()
        } else {
            await loadOutlookDays(count: max(outlookDays.count, 7))
        }
    }
}
