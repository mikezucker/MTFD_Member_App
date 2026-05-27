import Foundation
import Combine

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var date: String?
    @Published var entries: [APIClient.MobileScheduleEntry] = []

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

    func refresh() async {
        await load()
    }
}
