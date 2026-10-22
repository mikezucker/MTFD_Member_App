import Foundation

let watchTestDefaults = UserDefaults(suiteName: "mtfd-watch-haptics-test-\(UUID().uuidString)")!

enum HapticAlertStyle { case off, normal, strong, pagerStyle }
enum ApplicationState { case active, background }
@MainActor final class UIApplication {
    static let shared = UIApplication()
    var applicationState: ApplicationState = .active
}
@MainActor final class WKApplication {
    static let instance = WKApplication()
    static func shared() -> WKApplication { instance }
    var applicationState: ApplicationState = .active
}
@MainActor enum Feedback { static var phone = 0; static var watch = 0 }
@MainActor final class UINotificationFeedbackGenerator {
    enum Kind { case warning, success }
    func prepare() {}
    func notificationOccurred(_ kind: Kind) { Feedback.phone += 1 }
}
@MainActor final class UIImpactFeedbackGenerator {
    enum Style { case heavy }
    init(style: Style) {}
    func prepare() {}
    func impactOccurred(intensity: Double) { Feedback.phone += 1 }
}
@MainActor final class WKInterfaceDevice {
    enum Kind { case notification, directionUp }
    static func current() -> WKInterfaceDevice { WKInterfaceDevice() }
    func play(_ kind: Kind) { Feedback.watch += 1 }
}

@main struct PlaybackTests {
    static func pause(_ milliseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
    @MainActor static func message(_ id: String, _ style: String = "strong", age: Double = 0) -> [String: Any] {
        ["action": "dispatch_haptic", "dispatchId": id, "hapticAlertStyle": style,
         "sentAt": Date().timeIntervalSince1970 - age, "critical": true]
    }
    @MainActor static func main() async throws {
        let phone = HapticAlertManager.shared
        phone.playDispatchAlert(dispatchId: "one", style: .normal, isCritical: false)
        try await pause(1050)
        precondition(Feedback.phone == 3)
        phone.playDispatchAlert(dispatchId: "one", style: .normal, isCritical: false)
        try await pause(50)
        precondition(Feedback.phone == 3, "Duplicate dispatch must not replay")

        phone.play(style: .strong)
        try await pause(50)
        let beforeOff = Feedback.phone
        phone.play(style: .off)
        try await pause(550)
        precondition(Feedback.phone == beforeOff, "Off must cancel remaining taps")
        phone.play(style: .pagerStyle)
        try await pause(50)
        UIApplication.shared.applicationState = .background
        let beforeBackground = Feedback.phone
        try await pause(300)
        precondition(Feedback.phone == beforeBackground, "Background must stop playback")

        let watch = WatchDispatchHaptics.shared
        watch.receive(message("watch-one"))
        try await pause(2500)
        precondition(Feedback.watch == 3, "Strong Watch pattern must repeat")
        watch.receive(message("watch-one"))
        watch.receive(message("stale", age: 31))
        try await pause(50)
        precondition(Feedback.watch == 3, "Duplicates and stale messages must stay quiet")
        watch.receive(message("pager", "pagerStyle"))
        try await pause(50)
        let watchBeforeOff = Feedback.watch
        watch.receive(message("off", "off"))
        try await pause(1250)
        precondition(Feedback.watch == watchBeforeOff, "Watch Off must cancel remaining taps")
        watch.applySettings(["hapticsEnabled": false])
        precondition(!watch.receive(message("disabled")))
        watch.applySettings(["hapticsEnabled": true, "hapticStyle": "normal"])
        precondition(watch.receive(message("override", "pagerStyle")))
        try await pause(1300)
        precondition(Feedback.watch == watchBeforeOff + 1, "Watch override must replace phone style")
        let afterOverride = Feedback.watch
        WKApplication.shared().applicationState = .background
        watch.receive(message("background"))
        try await pause(50)
        precondition(Feedback.watch == afterOverride, "Watch background must not start custom feedback")
        print("PASS: repeated patterns, deduplication, Off cancellation, background guards, stale Watch messages")
    }
}
