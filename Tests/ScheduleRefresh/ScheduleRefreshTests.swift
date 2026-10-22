import Foundation
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
@MainActor final class APIClient {
    static let shared = APIClient()
    struct MobileScheduleEntry { let id: String }
    struct Response {
        let success: Bool
        let date: String?
        let entries: [MobileScheduleEntry]
        var message: String? = nil
    }
    enum APIError: Error { case networkError(URLError) }
    var calls = 0
    var requestedDate: String?
    var pending: CheckedContinuation<Response, Error>?
    func fetchMobileSchedule(date: String? = nil) async throws -> Response {
        calls += 1
        requestedDate = date
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func succeed(_ entry: String) {
        finish(.success(Response(success: true, date: requestedDate, entries: [MobileScheduleEntry(id: entry)])))
    }
    func finish(_ result: Result<Response, Error>) {
        let continuation = pending!
        pending = nil
        continuation.resume(with: result)
    }
}
@main struct ScheduleRefreshTests {
    @MainActor static func waitForRequest(_ count: Int) async {
        for _ in 0..<10000 {
            if APIClient.shared.calls == count && APIClient.shared.pending != nil { return }
            await Task.yield()
        }
        fatalError("Request did not start")
    }
    @MainActor static func main() async {
        let api = APIClient.shared
        let model = ScheduleViewModel()
        let gesture = Task { await model.loadOutlookDays(count: 2) }
        await waitForRequest(1)
        gesture.cancel()
        let duplicate = Task { await model.refresh() }
        for _ in 0..<20 { await Task.yield() }
        assert(api.calls == 1)
        api.succeed("today")
        await waitForRequest(2)
        api.succeed("tomorrow")
        await gesture.value
        await duplicate.value
        assert(model.outlookDays.count == 2 && model.entries.first?.id == "today")
        assert(!model.isLoading && model.errorMessage == nil)

        for error in [CancellationError(), URLError(.cancelled), APIClient.APIError.networkError(URLError(.cancelled))] as [Error] {
            let count = api.calls + 1
            let refresh = Task { await model.loadOutlookDays(count: 2) }
            await waitForRequest(count)
            api.finish(.failure(error))
            await refresh.value
            assert(model.errorMessage == nil && !model.isLoading)
            assert(model.outlookDays.first?.entries.first?.id == "today")
        }
        let count = api.calls + 1
        let partial = Task { await model.loadOutlookDays(count: 2) }
        await waitForRequest(count)
        api.finish(.failure(URLError(.notConnectedToInternet)))
        await waitForRequest(count + 1)
        api.succeed("updated tomorrow")
        await partial.value
        assert(model.errorMessage != nil)
        assert(model.outlookDays.first?.entries.first?.id == "today")
        assert(model.outlookDays.last?.entries.first?.id == "updated tomorrow")
        let next = api.calls + 1
        let retry = Task { await model.load() }
        await waitForRequest(next)
        assert(model.errorMessage == nil)
        api.succeed("updated today")
        await retry.value
        assert(model.entries.first?.id == "updated today" && !model.isLoading)
        print("PASS: schedule refresh survives gesture cancellation, coalesces, ignores cancellations, preserves failed days, and retries")
    }
}
