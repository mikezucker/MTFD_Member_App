import Foundation
import Combine

class NotificationPreferencesViewModel: ObservableObject {
    @Published var preferences = NotificationPreferences()

    private let key = "notification_preferences"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return }

        preferences = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
//  NotificationPreferencesViewModel.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 4/27/26.
//

