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

    func load() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let response = try await APIClient.shared.fetchMobileSchedule()

            date = response.date
            entries = response.entries

            if !response.success {
                errorMessage = response.message ?? "Schedule unavailable."
            }
        } catch {
            errorMessage = error.localizedDescription
            entries = []
        }
    }

    func loadOutlookDays(count: Int = 4) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

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

                print("🗓️ Schedule outlook \(label) \(dateString): \(response.entries.count) entries")
            } catch {
                print("🧨 Schedule outlook failed for \(dateString):", error.localizedDescription)

                days.append(
                    ScheduleOutlookDay(
                        id: dateString,
                        label: label,
                        date: dateString,
                        entries: []
                    )
                )

                if errorMessage == nil {
                    errorMessage = error.localizedDescription
                }
            }
        }

        outlookDays = days
        print("🗓️ Schedule outlook days loaded:", outlookDays.map { "\($0.label)=\($0.entries.count)" }.joined(separator: ", "))
    }

    func refresh() async {
        await load()
    }
}
