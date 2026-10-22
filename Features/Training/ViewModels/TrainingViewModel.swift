import Foundation
import SwiftUI
import Combine

@MainActor
final class TrainingViewModel: ObservableObject {
    @Published private(set) var response: MobileTrainingResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private var refreshTask: Task<Void, Never>?

    private let cacheKey = "cached_mobile_training_response_v1"

    var summary: TrainingSummary? {
        response?.summary
    }

    var myTraining: [MobileTrainingItem] {
        response?.myTraining ?? []
    }

    var capabilities: TrainingCapabilities? {
        response?.capabilities
    }

    var pendingEvaluations: [PendingTrainingEvaluation] {
        response?.pendingEvaluations ?? []
    }

    var managedMembers: [ManagedTrainingMember] {
        response?.managedMembers ?? []
    }

    var hasCachedData: Bool {
        response != nil
    }

    func load() async {
        if response == nil { loadCachedResponse() }
        await refresh()
    }

    func refresh() async {
        // Own the request independently of SwiftUI's short-lived refresh gesture.
        // Initial loading, pull-to-refresh, and retries share one request.
        if let refreshTask {
            await refreshTask.value
            return
        }
        isLoading = response == nil
        isRefreshing = response != nil
        errorMessage = nil

        let task = Task { @MainActor [self] in
            defer {
                isLoading = false
                isRefreshing = false
                refreshTask = nil
            }
            do {
                let fresh = try await APIClient.shared.fetchTraining()
                response = fresh
                cacheResponse(fresh)
            } catch {
                // Cancellation is a lifecycle event, not a failed server refresh.
                if error is CancellationError { return }
                if let urlError = error as? URLError, urlError.code == .cancelled { return }
                if let apiError = error as? APIClient.APIError,
                   case .networkError(let urlError) = apiError,
                   urlError.code == .cancelled { return }
                errorMessage = error.localizedDescription
            }
        }
        refreshTask = task
        await task.value
    }

    private func loadCachedResponse() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return
        }

        do {
            response = try JSONDecoder.mtfdTrainingDecoder.decode(
                MobileTrainingResponse.self,
                from: data
            )
        } catch {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
    }

    private func cacheResponse(_ response: MobileTrainingResponse) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(response)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            // Cache failures should never block the UI.
        }
    }
}
