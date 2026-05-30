import SwiftUI

struct DashboardHeaderView: View {
    let firstName: String
    let roleTitle: String
    let stationTitle: String
    let unreadCount: Int
    let isBellRinging: Bool
    let onTapMessages: () -> Void

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

    private var messageStatusText: String {
        if unreadCount <= 0 {
            return "No unread messages"
        }

        return "\(unreadCount) unread message\(unreadCount == 1 ? "" : "s")"
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

                Text(messageStatusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Button(action: onTapMessages) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isBellRinging ? "bell.badge.fill" : "bell.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.white.opacity(0.14))
                        .clipShape(Circle())

                    if unreadCount > 0 {
                        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.red)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open messages")
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
