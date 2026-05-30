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

    private var role: String {
        session.currentUser?.role.uppercased() ?? ""
    }

    var body: some View {
        if role == "ADMIN" || role == "CHIEF" {
            ChiefCommandView()
        } else {
            LieutenantCommandView()
        }
    }
}

private struct ChiefCommandView: View {
    var body: some View {
        CommandWorkspaceView(
            title: "Chief Command",
            subtitle: "Department-wide command workspace",
            description: "Monitor department operations, staffing, training compliance, messages, documents, and future apparatus location tools.",
            tiles: [
                CommandTileData(
                    title: "Department Operations",
                    subtitle: "View active incidents, department-wide status, dispatch activity, and operational priorities.",
                    systemImage: "shield.lefthalf.filled"
                ),
                CommandTileData(
                    title: "Staffing Overview",
                    subtitle: "Review today’s staffing, vacancies, relief driver coverage, and department schedule status.",
                    systemImage: "person.3.sequence.fill"
                ),
                CommandTileData(
                    title: "Training Compliance",
                    subtitle: "Track assigned training, overdue members, JPR progress, and evaluator sign-offs.",
                    systemImage: "checklist.checked"
                ),
                CommandTileData(
                    title: "Department Messages",
                    subtitle: "Prepare department-wide messages, announcements, and operational updates.",
                    systemImage: "megaphone.fill"
                ),
                CommandTileData(
                    title: "Documents / SOPs",
                    subtitle: "Review SOP acknowledgements, missing signatures, and document completion status.",
                    systemImage: "doc.text.magnifyingglass"
                ),
                CommandTileData(
                    title: "Apparatus GPS",
                    subtitle: "Future apparatus location map, stale-location warnings, and vehicle status overview.",
                    systemImage: "location.north.line.fill"
                )
            ]
        )
    }
}

private struct LieutenantCommandView: View {
    var body: some View {
        CommandWorkspaceView(
            title: "Lieutenant Command",
            subtitle: "Station and company command workspace",
            description: "Focus on assigned members, station staffing, training progress, station messages, and operational readiness.",
            tiles: [
                CommandTileData(
                    title: "Station Operations",
                    subtitle: "View active incidents, assigned units, station/company status, and operational updates.",
                    systemImage: "building.2.crop.circle.fill"
                ),
                CommandTileData(
                    title: "My Staffing",
                    subtitle: "Review station/company schedule, vacancies, assigned members, and relief driver coverage.",
                    systemImage: "person.2.badge.gearshape.fill"
                ),
                CommandTileData(
                    title: "Training Progress",
                    subtitle: "Track assigned member training, JPR completion, skill checkoffs, and sign-offs.",
                    systemImage: "checkmark.seal.fill"
                ),
                CommandTileData(
                    title: "Station Messages",
                    subtitle: "Prepare station or company-specific messages and updates.",
                    systemImage: "text.bubble.fill"
                ),
                CommandTileData(
                    title: "Documents",
                    subtitle: "Review SOPs, station documents, acknowledgements, and required signatures.",
                    systemImage: "doc.text.fill"
                ),
                CommandTileData(
                    title: "Members",
                    subtitle: "View assigned member status, profiles, roles, and readiness information.",
                    systemImage: "person.crop.rectangle.stack.fill"
                )
            ]
        )
    }
}

private struct CommandWorkspaceView: View {
    let title: String
    let subtitle: String
    let description: String
    let tiles: [CommandTileData]

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
                        ForEach(tiles) { tile in
                            commandTile(tile)
                        }
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
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))

            Text(description)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func commandTile(_ tile: CommandTileData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: tile.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.gold)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(tile.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(tile.subtitle)
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

private struct CommandTileData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
}

