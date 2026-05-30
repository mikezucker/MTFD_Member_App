import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
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

                if canUseCommandTab {
                    CommandView()
                        .tabItem {
                            Label("Command", systemImage: "shield.lefthalf.filled")
                        }
                        .tag(NavigationRouter.AppTab.command)
                }

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

    private var canUseCommandTab: Bool {
        let role = session.currentUser?.role.uppercased()

        return role == "ADMIN"
            || role == "CHIEF"
            || role == "OFFICER_CAREER"
            || role == "OFFICER_VOLUNTEER"
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


private struct CommandView: View {
    @EnvironmentObject private var session: SessionManager

    private var roleTitle: String {
        switch session.currentUser?.role.uppercased() {
        case "ADMIN":
            return "Administrator"
        case "CHIEF":
            return "Chief"
        case "OFFICER_CAREER":
            return "Career Officer"
        case "OFFICER_VOLUNTEER":
            return "Volunteer Officer"
        default:
            return "Officer"
        }
    }

    var body: some View {
        AppScreen(title: "Command") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ],
                        spacing: 14
                    ) {
                        commandTile(
                            title: "Active Dispatch",
                            subtitle: "Monitor active incidents, units, CAD notes, and location details.",
                            systemImage: "bell.and.waves.left.and.right.fill"
                        )

                        commandTile(
                            title: "Staffing",
                            subtitle: "Review today’s schedule, vacancies, assignments, and relief driver coverage.",
                            systemImage: "person.3.sequence.fill"
                        )

                        commandTile(
                            title: "Training",
                            subtitle: "Track assigned training, overdue items, JPRs, and evaluator sign-offs.",
                            systemImage: "checklist.checked"
                        )

                        commandTile(
                            title: "Messages",
                            subtitle: "Prepare officer, station, company, and department communications.",
                            systemImage: "text.bubble.fill"
                        )

                        commandTile(
                            title: "Documents",
                            subtitle: "Review SOP acknowledgements, missing signatures, and document status.",
                            systemImage: "doc.text.magnifyingglass"
                        )

                        commandTile(
                            title: "Members",
                            subtitle: "View member status, profile updates, assignments, and role information.",
                            systemImage: "person.crop.rectangle.stack.fill"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Officer / Chief Tools")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("\(roleTitle) command workspace")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))

            Text("Command-facing tools grouped separately from the member dashboard.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func commandTile(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.gold)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .padding(16)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
