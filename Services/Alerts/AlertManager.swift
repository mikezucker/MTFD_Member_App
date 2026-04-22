import SwiftUI
import Combine

final class AlertManager: ObservableObject {
    @Published var alerts: [AppAlert] = []

    func add(_ alert: AppAlert) {
        DispatchQueue.main.async {
            withAnimation(Motion.spring) {
                self.alerts.insert(alert, at: 0)
            }

            switch alert.priority {
            case .critical:
                HapticsManager.shared.error()
            case .urgent:
                HapticsManager.shared.warning()
            default:
                HapticsManager.shared.selection()
            }
        }
    }
}
