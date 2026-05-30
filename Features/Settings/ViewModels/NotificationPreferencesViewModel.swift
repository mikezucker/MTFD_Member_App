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
    private var hasLoadedRemote = false

    init() {
        loadLocal()
    }

    func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return }

        preferences = decoded
        UserDefaults.standard.set(preferences.hapticsEnabled, forKey: "notification_haptics_enabled")
    }

    func saveLocal() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
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
                UserDefaults.standard.set(preferences.hapticsEnabled, forKey: "notification_haptics_enabled")
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
        isSaving = true
        errorMessage = nil
        successMessage = nil

        defer { isSaving = false }

        do {
            let response = try await APIClient.shared.updateNotificationPreferences(
                preferencesToSave ?? preferences
            )

            if response.success {
                saveLocal()
            } else if let error = response.error {
                errorMessage = error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelPendingSave() {
        saveTask?.cancel()
        saveTask = nil
    }
}
