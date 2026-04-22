import SwiftUI

struct AppScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.navy
                    .ignoresSafeArea()

                content()
            }
            .navigationTitle(title)
            .toolbarBackground(AppTheme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
