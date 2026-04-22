import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        Group {
            if session.isRestoringSession {
                ProgressView("Restoring session...")
            } else if session.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
