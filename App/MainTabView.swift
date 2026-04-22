import SwiftUI

struct MainTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 3/255,
            green: 22/255,
            blue: 51/255,
            alpha: 1
        )

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = .lightGray
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TrainingView()
                .tabItem {
                    Label("Training", systemImage: "flame.fill")
                }

            DocumentsView()
                .tabItem {
                    Label("Documents", systemImage: "doc.text.fill")
                }

            UniformsView()
                .tabItem {
                    Label("Uniforms", systemImage: "tshirt.fill")
                }

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
        }
        .tint(AppTheme.gold)
    }
}
