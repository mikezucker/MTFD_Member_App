import Foundation
import Combine

@MainActor
class NotificationPreferencesViewModel: ObservableObject {
    @Published var preferences = NotificationPreferences()
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let key = "notification_preferences"
    private var saveTask: Task<Void, Never>?
    private var pendingRemotePreferences: NotificationPreferences?
    private var hasLoadedRemote = false

    init() {
        loadLocal()
    }

    func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return }

        preferences = decoded
        persistAlertSettings()
    }

    func saveLocal() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
        persistAlertSettings()
    }

    func loadRemote() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
            hasLoadedRemote = true
        }

        do {
            let response = try await APIClient.shared.fetchNotificationPreferences()

            if let serverPreferences = response.preferences {
                preferences = serverPreferences
                persistAlertSettings()
                saveLocal()
            } else if let error = response.error {
                errorMessage = error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleSave() {
        guard hasLoadedRemote else {
            saveLocal()
            return
        }

        saveLocal()
        successMessage = nil
        errorMessage = nil
        pendingRemotePreferences = preferences

        saveTask?.cancel()

        saveTask = Task { [preferences] in
            try? await Task.sleep(nanoseconds: 700_000_000)

            if Task.isCancelled {
                return
            }

            await saveRemote(preferences)
        }
    }

    func saveRemote(_ preferencesToSave: NotificationPreferences? = nil) async {
        let preferencesForRequest = preferencesToSave ?? preferences

        isSaving = true
        errorMessage = nil
        successMessage = nil

        defer { isSaving = false }

        do {
            let response = try await APIClient.shared.updateNotificationPreferences(
                preferencesForRequest
            )

            if response.success {
                pendingRemotePreferences = nil
                if let serverPreferences = response.preferences {
                    preferences = serverPreferences
                }
                saveLocal()
            } else if let error = response.error {
                errorMessage = error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func flushPendingSave() async {
        saveTask?.cancel()
        saveTask = nil
        saveLocal()

        guard let pendingRemotePreferences else {
            return
        }

        await saveRemote(pendingRemotePreferences)
    }

    func saveImmediately() async {
        saveTask?.cancel()
        saveTask = nil
        pendingRemotePreferences = preferences
        saveLocal()
        await saveRemote(preferences)
    }

    func cancelPendingSave() {
        saveTask?.cancel()
        saveTask = nil
    }

    private func persistAlertSettings() {
        UserDefaults.standard.set(preferences.hapticAlertStyle.rawValue, forKey: "notification_haptic_alert_style")
        UserDefaults.standard.set(preferences.hapticAlertStyle != .off, forKey: "notification_haptics_enabled")
        UserDefaults.standard.set(preferences.dispatchAlertTone.rawValue, forKey: "notification_dispatch_alert_tone")
        UserDefaults.standard.set(preferences.criticalDispatchAlertTone.rawValue, forKey: "notification_critical_dispatch_alert_tone")
    }
}
