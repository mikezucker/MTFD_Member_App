import SwiftUI

@main
struct MTFD_Member_AppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SessionManager.shared) // 👈 THIS is what you're missing
        }
    }
}
