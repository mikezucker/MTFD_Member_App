import SwiftUI

struct MainTabView: View {
    @StateObject private var router = NavigationRouter.shared
    @State private var showGlobalDispatchBanner = false
    @State private var activeDispatchPayload: AppNotificationPayload?

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
        ZStack(alignment: .top) {
            TabView(selection: $router.selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(NavigationRouter.AppTab.home)

                TrainingView()
                    .tabItem {
                        Label("Training", systemImage: "flame.fill")
                    }
                    .tag(NavigationRouter.AppTab.training)

                DocumentsView()
                    .tabItem {
                        Label("Documents", systemImage: "doc.text.fill")
                    }
                    .tag(NavigationRouter.AppTab.documents)

                ScheduleView()
                    .tabItem {
                        Label("Schedule", systemImage: "calendar.badge.clock")
                    }
                    .tag(NavigationRouter.AppTab.schedule)

                MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(NavigationRouter.AppTab.more)
            }
            .tint(AppTheme.gold)

            if showGlobalDispatchBanner, let activeDispatchPayload {
                GlobalDispatchBanner(
                    payload: activeDispatchPayload,
                    onTap: {
                        openDispatchDetail(activeDispatchPayload)
                    },
                    onDismiss: {
                        dismissBanner()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(50)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showGlobalDispatchBanner)
        .onReceive(router.$dispatchToOpen) { payload in
            guard let payload else { return }

            router.selectedTab = .home
            activeDispatchPayload = payload

            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showGlobalDispatchBanner = true
            }

            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if activeDispatchPayload?.id == payload.id {
                    dismissBanner()
                }
            }
        }
        .sheet(item: $router.dispatchToOpen, onDismiss: {
            router.clearDispatchRoute()
        }) { payload in
            DispatchDetailView(dispatch: payload)
        }
    }

    private func openDispatchDetail(_ payload: AppNotificationPayload) {
        router.selectedTab = .home
        router.dispatchToOpen = payload

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showGlobalDispatchBanner = false
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func dismissBanner() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showGlobalDispatchBanner = false
        }
    }
}

private struct GlobalDispatchBanner: View {
    let payload: AppNotificationPayload
    let onTap: () -> Void
    let onDismiss: () -> Void

    private var dispatchSubtitle: String {
        let parts = [
            payload.address,
            payload.units.isEmpty ? nil : payload.units.joined(separator: ", ")
        ].compactMap { $0 }

        return parts.joined(separator: " • ")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.16))
                        .frame(width: 44, height: 44)

                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(payload.type == .dispatchCritical ? "CRITICAL DISPATCH" : "LIVE DISPATCH")
                        .font(.caption.bold())
                        .foregroundStyle(.red)

                    Text(payload.callType ?? payload.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    if !dispatchSubtitle.isEmpty {
                        Text(dispatchSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }
}
