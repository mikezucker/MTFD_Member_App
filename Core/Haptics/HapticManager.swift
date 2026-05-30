import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func dispatchAlert(enabled: Bool, isCritical: Bool) {
        guard enabled else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(isCritical ? .warning : .success)
    }

    func warning(enabled: Bool) {
        guard enabled else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    func success(enabled: Bool) {
        guard enabled else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    func selection(enabled: Bool) {
        guard enabled else { return }

        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
