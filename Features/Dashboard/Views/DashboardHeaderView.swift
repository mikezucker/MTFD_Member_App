import SwiftUI

struct AppDashboardIcon: View {
    let systemImage: String
    var size: CGFloat = 32

    var body: some View {
        AppIcon(systemImage: systemImage, size: size, frameSize: size + 8)
    }
}

struct AppDetailHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AppDashboardIcon(systemImage: systemImage, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

enum DashboardHeaderAlertMode: Equatable {
    case activeDispatch(messageCount: Int)
    case unreadMessages(count: Int)
    case latestDispatches

    var badgeCount: Int {
        switch self {
        case .activeDispatch(let messageCount):
            return messageCount
        case .unreadMessages(let count):
            return count
        case .latestDispatches:
            return 0
        }
    }

    var shouldAnimate: Bool {
        switch self {
        case .activeDispatch:
            return true
        case .unreadMessages(let count):
            return count > 0
        case .latestDispatches:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .activeDispatch:
            return "bell.and.waves.left.and.right.fill"
        case .unreadMessages:
            return "envelope.badge.fill"
        case .latestDispatches:
            return "clock.arrow.circlepath"
        }
    }

    var iconColor: Color {
        switch self {
        case .activeDispatch:
            return .red
        case .unreadMessages:
            return .blue
        case .latestDispatches:
            return .white
        }
    }

    var backgroundColor: Color {
        switch self {
        case .activeDispatch:
            return .red.opacity(0.20)
        case .unreadMessages:
            return .blue.opacity(0.20)
        case .latestDispatches:
            return .white.opacity(0.14)
        }
    }

    var statusText: String {
        switch self {
        case .activeDispatch(let messageCount):
            if messageCount > 0 {
                return "Active dispatch • \(messageCount) unread message\(messageCount == 1 ? "" : "s")"
            }

            return "Active dispatch"
        case .unreadMessages(let count):
            return "\(count) unread message\(count == 1 ? "" : "s")"
        case .latestDispatches:
            return "Latest dispatches"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .activeDispatch:
            return "Open active dispatch"
        case .unreadMessages:
            return "Open messages"
        case .latestDispatches:
            return "Open latest dispatches"
        }
    }
}

struct DashboardHeaderView: View {
    let firstName: String
    let roleTitle: String
    let stationTitle: String
    let alertMode: DashboardHeaderAlertMode
    let isBellRinging: Bool
    let onTapAlert: () -> Void

    private var displayName: String {
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Member" : trimmedName
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private var headerSubtitle: String {
        let cleanedRole = roleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedStation = stationTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedRole.isEmpty {
            return cleanedStation
        }

        if cleanedStation.isEmpty {
            return cleanedRole
        }

        return "\(cleanedRole) • \(cleanedStation)"
    }

    private var effectiveShouldAnimate: Bool {
        isBellRinging || alertMode.shouldAnimate
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("MTFDLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(timeBasedGreeting), \(displayName)")
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)

                if !headerSubtitle.isEmpty {
                    Text(headerSubtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                }

                Text(alertMode.statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Button(action: onTapAlert) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: alertMode.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(alertMode.iconColor)
                        .frame(width: 50, height: 50)
                        .background(alertMode.backgroundColor)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(effectiveShouldAnimate ? -10 : 0))
                        .scaleEffect(effectiveShouldAnimate ? 1.08 : 1.0)
                        

                    if alertMode.badgeCount > 0 {
                        Text(alertMode.badgeCount > 99 ? "99+" : "\(alertMode.badgeCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(alertMode == .activeDispatch(messageCount: alertMode.badgeCount) ? .blue : .red)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(alertMode.accessibilityLabel)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 3 / 255, green: 22 / 255, blue: 51 / 255),
                    Color(red: 8 / 255, green: 42 / 255, blue: 86 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
