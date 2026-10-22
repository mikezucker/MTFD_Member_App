import Foundation
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
let settingsTestDefaults = UserDefaults(suiteName: "mtfd-settings-test-\(UUID().uuidString)")!
@MainActor final class APIClient {
    static let shared = APIClient()
    var calls: [NotificationPreferences] = []
    var pending: CheckedContinuation<NotificationPreferencesResponse, Error>?
    func fetchNotificationPreferences() async throws -> NotificationPreferencesResponse {
        NotificationPreferencesResponse(hapticsEnabled: nil,success:true,preferences:NotificationPreferences(),error:nil)
    }
    func updateNotificationPreferences(_ value: NotificationPreferences) async throws -> NotificationPreferencesResponse {
        calls.append(value)
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func finish(success: Bool = true) {
        let value = calls.last!
        let continuation = pending!
        pending = nil
        continuation.resume(returning: NotificationPreferencesResponse(hapticsEnabled:nil,success:success,preferences:success ? value : nil,error:success ? nil : "Server unavailable"))
    }
}
@main struct SaveTests {
    @MainActor static func waitFor(_ count: Int) async {
        for _ in 0..<10000 {
            if APIClient.shared.calls.count == count && APIClient.shared.pending != nil { return }
            await Task.yield()
        }
        fatalError("Save request did not start")
    }
    @MainActor static func main() async throws {
        let model=NotificationPreferencesViewModel()
        let api=APIClient.shared
        await model.loadRemote()
        model.preferences.hapticAlertStyle = .strong
        let first=Task { await model.saveImmediately() }
        await waitFor(1)
        model.preferences.hapticAlertStyle = .pagerStyle
        model.preferences.documentAssignmentsEnabled=false
        let second=Task { await model.saveImmediately() }
        for _ in 0..<20 { await Task.yield() }
        precondition(api.calls.count == 1, "Writes must serialize")
        api.finish()
        await waitFor(2)
        precondition(model.preferences.hapticAlertStyle == .pagerStyle, "Older response must not overwrite edit")
        api.finish()
        await first.value
        await second.value
        precondition(api.calls.last?.documentAssignmentsEnabled == false)
        precondition(!model.isSaving && model.errorMessage == nil)
        let cached=try JSONDecoder().decode(NotificationPreferences.self,from:settingsTestDefaults.data(forKey:"notification_preferences")!)
        precondition(cached == model.preferences)

        model.preferences.stationMessagesEnabled=false
        let failure=Task { await model.saveImmediately() }
        await waitFor(3)
        api.finish(success:false)
        await failure.value
        precondition(model.errorMessage != nil)
        let retry=Task { await model.flushPendingSave() }
        await waitFor(4)
        api.finish()
        await retry.value
        precondition(model.errorMessage == nil && model.preferences.stationMessagesEnabled == false)
        print("PASS: serialized saves, latest edit wins, local persistence, failed save retained and retried")
    }
}
