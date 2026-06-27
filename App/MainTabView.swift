import SwiftUI
import UIKit

import SwiftUI

enum AppIconKey: String {
    case dispatch
    case messages
    case training
    case schedule
    case staffing
    case apparatus
    case workOrders
    case documents
    case fire
    case ems
    case department
    case warning
    case unread
    case progress
    case inbox
    case profile
    case settings
    case uniform
    case announcement
    case location
    case station
    case officer
    case chief
    case volunteer
    case career
    case calls
    case stats
    case unknown
}

enum AppIconCatalog {
    static let dispatch = "🚒"
    static let messages = "📬"
    static let training = "🎓"
    static let schedule = "📅"
    static let staffing = "👥"
    static let apparatus = "🛠️"
    static let workOrders = "🛠️"
    static let documents = "📄"
    static let fire = "🔥"
    static let ems = "🚑"
    static let department = "🏢"
    static let warning = "⚠️"
    static let unread = "🔔"
    static let progress = "📈"
    static let inbox = "📥"
    static let profile = "👤"
    static let settings = "⚙️"
    static let uniform = "👕"
    static let announcement = "📣"
    static let location = "📍"
    static let station = "🏠"
    static let officer = "🧑‍🚒"
    static let chief = "🧑‍🚒"
    static let volunteer = "🙋"
    static let career = "🧑‍🚒"
    static let calls = "📟"
    static let stats = "📊"
    static let unknown = ""

    static func emoji(for key: AppIconKey) -> String {
        switch key {
        case .dispatch: return "🚒"
        case .messages: return "📬"
        case .training: return "🎓"
        case .schedule: return "📅"
        case .staffing: return "👥"
        case .apparatus: return "🛠️"
        case .workOrders: return "🛠️"
        case .documents: return "📄"
        case .fire: return "🔥"
        case .ems: return "🚑"
        case .department: return "🏢"
        case .warning: return "⚠️"
        case .unread: return "🔔"
        case .progress: return "📈"
        case .inbox: return "📥"
        case .profile: return "👤"
        case .settings: return "⚙️"
        case .uniform: return "👕"
        case .announcement: return "📣"
        case .location: return "📍"
        case .station: return "🏠"
        case .officer: return "🧑‍🚒"
        case .chief: return "🧑‍🚒"
        case .volunteer: return "🙋"
        case .career: return "🧑‍🚒"
        case .calls: return "📟"
        case .stats: return "📊"
        case .unknown: return ""
        }
    }

    static func key(forSystemImage systemImage: String) -> AppIconKey {
        switch systemImage {
        case "bell.and.waves.left.and.right.fill", "firetruck.fill": return .dispatch
        case "flame.fill": return .fire
        case "cross.case.fill", "heart.text.square.fill": return .ems
        case "envelope.badge.fill", "envelope.fill", "message.fill", "bubble.left.and.bubble.right.fill": return .messages
        case "megaphone.fill", "megaphone": return .announcement
        case "checkmark.seal.fill", "graduationcap.fill", "checkmark.circle.fill", "play.circle.fill": return .training
        case "calendar", "calendar.badge.clock", "clock.fill": return .schedule
        case "person.2.fill", "person.3.fill": return .staffing
        case "wrench.and.screwdriver.fill", "gearshape.fill": return .workOrders
        case "checklist.checked", "book.closed.fill", "paperplane.fill", "plus.rectangle.on.folder.fill": return .training
        case "clock.badge.checkmark.fill", "circle.dashed": return .training
        case "text.bubble.fill", "bell.fill": return .messages
        case "tshirt.fill": return .uniform
        case "person.badge.shield.checkmark.fill", "person.crop.circle.badge.checkmark": return .officer
        case "car.fill": return .dispatch
        case "building.2.crop.circle.fill": return .department
        case "doc.text.fill", "folder.fill", "doc.fill": return .documents
        case "building.2.fill", "building.columns.fill": return .department
        case "house.and.flag.fill": return .station
        case "exclamationmark.triangle.fill": return .warning
        case "tray.fill", "tray": return .inbox
        case "chart.line.uptrend.xyaxis", "chart.bar.fill": return .progress
        case "person.crop.circle.fill", "person.fill": return .profile
        case "gearshape", "slider.horizontal.3": return .settings
        case "mappin.and.ellipse", "location.fill": return .location
        default: return .unknown
        }
    }
}

struct AppIcon: View {
    let key: AppIconKey
    var size: CGFloat = 30
    var frameSize: CGFloat? = nil

    init(_ key: AppIconKey, size: CGFloat = 30, frameSize: CGFloat? = nil) {
        self.key = key
        self.size = size
        self.frameSize = frameSize
    }

    init(systemImage: String, size: CGFloat = 30, frameSize: CGFloat? = nil) {
        self.key = AppIconCatalog.key(forSystemImage: systemImage)
        self.size = size
        self.frameSize = frameSize
    }

    var body: some View {
        Text(AppIconCatalog.emoji(for: key))
            .font(.system(size: size))
            .frame(width: frameSize ?? size + 8, height: frameSize ?? size + 8)
            .accessibilityLabel(Text(key.rawValue))
    }
}


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

                TrainingView()
                    .tabItem {
                        Label("Training", systemImage: "flame.fill")
                    }
                    .tag(NavigationRouter.AppTab.training)

                DocumentsView()
                    .tabItem {
                        Label("Policy Center", systemImage: "doc.text.fill")
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
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mtfdmember" else { return }

        if url.host == "dispatch" {
            let dispatchId = url.pathComponents.dropFirst().first ?? ""

            guard !dispatchId.isEmpty else {
                router.selectedTab = .home
                return
            }

            let payload = AppNotificationPayload(
                type: .dispatch,
                id: dispatchId,
                title: "Dispatch Alert",
                body: nil,
                callType: nil,
                address: nil,
                units: [],
                isWorkingFire: false,
                activeCallCount: 1,
                stationId: nil,
                messageId: nil,
                trainingId: nil,
                documentId: nil
            )

            router.route(from: payload)
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

                    AppIcon(.dispatch)
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

