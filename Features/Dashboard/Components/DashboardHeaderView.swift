import SwiftUI

struct DashboardHeaderView: View {
    let firstName: String
    let roleTitle: String
    let unreadCount: Int
    let onTapMessages: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("MTFDLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome \(firstName)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(roleTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onTapMessages) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())

                    if unreadCount > 0 {
                        Text("\(min(unreadCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Messages")
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.18, blue: 0.38),
                Color(red: 0.03, green: 0.10, blue: 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 0) {
            DashboardHeaderView(
                firstName: "Michael",
                roleTitle: "Chief",
                unreadCount: 3,
                onTapMessages: { }
            )
            .padding()

            Spacer()
        }
    }
}
