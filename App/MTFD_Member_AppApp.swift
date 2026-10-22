
import AppIntents
import SwiftUI

@main
struct MTFD_Member_AppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        MTFDAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SessionManager.shared)
                .onAppear {
                    DispatchLiveActivityManager.shared.startObservingPushToStartToken()
                }
        }
    }
}
