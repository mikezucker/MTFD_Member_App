import Foundation

protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
struct TrainingSummary: Codable {}
struct MobileTrainingItem: Codable {}
struct TrainingCapabilities: Codable {}
struct PendingTrainingEvaluation: Codable {}
struct ManagedTrainingMember: Codable {}
struct MobileTrainingResponse: Codable {
    let revision: Int
    var summary: TrainingSummary? = nil
    var myTraining: [MobileTrainingItem] = []
    var capabilities: TrainingCapabilities? = nil
    var pendingEvaluations: [PendingTrainingEvaluation] = []
    var managedMembers: [ManagedTrainingMember] = []
}
extension JSONDecoder {
    static var mtfdTrainingDecoder: JSONDecoder { JSONDecoder() }
}
let trainingTestDefaults = UserDefaults(suiteName: "mtfd-training-refresh-tests-\(UUID().uuidString)")!

@MainActor final class APIClient {
    static let shared = APIClient()
    enum APIError: Error, LocalizedError {
        case networkError(URLError)
        var errorDescription: String? { "Network error" }
    }
    var calls = 0
    var pending: CheckedContinuation<MobileTrainingResponse, Error>?
    func fetchTraining() async throws -> MobileTrainingResponse {
        calls += 1
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func finish(_ result: Result<MobileTrainingResponse, Error>) {
        let continuation = pending!
        pending = nil
        continuation.resume(with: result)
    }
}

@main struct TrainingRefreshTests {
    @MainActor static func waitForRequest(_ count: Int) async {
        for _ in 0..<10000 {
            if APIClient.shared.calls == count && APIClient.shared.pending != nil { return }
            await Task.yield()
        }
        fatalError("Request did not start")
    }
    @MainActor static func main() async {
        let api = APIClient.shared
        let model = TrainingViewModel()
        let gesture = Task { await model.refresh() }
        await waitForRequest(1)
        assert(model.isLoading)
        gesture.cancel()
        let overlapping = Task { await model.load() }
        for _ in 0..<20 { await Task.yield() }
        assert(api.calls == 1, "Overlapping refreshes must share one request")
        api.finish(.success(MobileTrainingResponse(revision: 1)))
        await gesture.value
        await overlapping.value
        assert(model.response?.revision == 1, "Cancelled gesture must still receive completed refresh")
        assert(model.errorMessage == nil && !model.isLoading && !model.isRefreshing)

        for error in [CancellationError(), URLError(.cancelled), APIClient.APIError.networkError(URLError(.cancelled))] as [Error] {
            let nextCall = api.calls + 1
            let refresh = Task { await model.refresh() }
            await waitForRequest(nextCall)
            assert(model.isRefreshing)
            api.finish(.failure(error))
            await refresh.value
            assert(model.errorMessage == nil, "Cancellation must not show a network failure")
            assert(model.response?.revision == 1 && !model.isRefreshing)
        }

        let failed = Task { await model.refresh() }
        await waitForRequest(api.calls + (api.pending == nil ? 1 : 0))
        api.finish(.failure(APIClient.APIError.networkError(URLError(.notConnectedToInternet))))
        await failed.value
        assert(model.errorMessage != nil && model.response?.revision == 1)
        let retry = Task { await model.refresh() }
        await waitForRequest(api.calls + (api.pending == nil ? 1 : 0))
        assert(model.errorMessage == nil)
        api.finish(.success(MobileTrainingResponse(revision: 2)))
        await retry.value
        assert(model.response?.revision == 2 && model.errorMessage == nil && !model.isRefreshing)
        print("PASS: cancelled gesture completes, refreshes coalesce, cancellations stay silent, real failures preserve cache, retry recovers")
    }
}
