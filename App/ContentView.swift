import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.scenePhase) private var scenePhase

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
                    .onAppear {
                        NavigationRouter.shared.resetToHome()
                    }
            } else {
                LoginView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                DispatchAttentionPresenter.shared.resume()
                Task { await session.registerPushTokenIfAvailable() }
            }
        }
        .onChange(of: session.isLoggedIn) { _, loggedIn in
            if !loggedIn { DispatchAttentionPresenter.shared.clear() }
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
