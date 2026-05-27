import SwiftUI

struct DashboardHeaderView: View {
    let firstName: String
    let roleTitle: String
    let stationTitle: String
    let unreadCount: Int
    let isBellRinging: Bool
    let onTapMessages: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("MTFDLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 68)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome \(firstName.isEmpty ? "Member" : firstName)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(roleTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)

                Text(stationTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(action: onTapMessages) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isBellRinging ? "bell.badge.fill" : "bell.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
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
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 18)
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
}//
//  DashboardHeaderView.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/11/26.
//

