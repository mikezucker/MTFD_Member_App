import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

@MainActor
final class HapticAlertManager {
    static let shared = HapticAlertManager()

    private var playedDispatchIds = Set<String>()
    private var playbackTask: Task<Void, Never>?

    private init() {}

    func playDispatchAlert(
        dispatchId: String,
        style: HapticAlertStyle,
        isCritical: Bool
    ) {
        guard !playedDispatchIds.contains(dispatchId) else {
            return
        }

        playedDispatchIds.insert(dispatchId)
        play(style: style, isCritical: isCritical)
    }

    func play(style: HapticAlertStyle, isCritical: Bool = false) {
        switch style {
        case .off:
            return
        case .normal:
            playNormal(isCritical: isCritical)
        case .strong:
            playStrong()
        case .pagerStyle:
            playPagerStyle()
        }
    }

    private func playNormal(isCritical: Bool) {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            for index in 0..<3 {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(isCritical ? .warning : .success)

                if index < 2 {
                    try? await Task.sleep(nanoseconds: 450_000_000)
                }
            }
        }
    }

    private func playStrong() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            for index in 0..<8 {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                generator.impactOccurred(intensity: 1.0)

                if index < 7 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
    }

    private func playPagerStyle() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            for index in 0..<12 {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                generator.impactOccurred(intensity: 1.0)

                if index < 11 {
                    try? await Task.sleep(nanoseconds: index.isMultiple(of: 2) ? 250_000_000 : 650_000_000)
                }
            }
        }
    }
}
