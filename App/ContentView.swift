import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        Group {
            if session.isRestoringSession {
                VStack(spacing: 16) {
                    ProgressView()

                    Text("Restoring session...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if session.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            // Prevent duplicate restore calls
            guard !session.isLoggedIn,
                  !session.isRestoringSession
            else {
                return
            }

            await session.restoreSession()
        }
    }
}
