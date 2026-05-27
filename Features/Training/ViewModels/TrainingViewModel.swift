import Foundation
import SwiftUI
import Combine

@MainActor
final class TrainingViewModel: ObservableObject {
    @Published private(set) var response: MobileTrainingResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

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
        loadCachedResponse()

        if response == nil {
            isLoading = true
        } else {
            isRefreshing = true
        }

        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let fresh = try await APIClient.shared.fetchTraining()
            response = fresh
            errorMessage = nil
            cacheResponse(fresh)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isRefreshing = true

        defer {
            isRefreshing = false
        }

        do {
            let fresh = try await APIClient.shared.fetchTraining()
            response = fresh
            errorMessage = nil
            cacheResponse(fresh)
        } catch {
            errorMessage = error.localizedDescription
        }
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
