import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let member = session.currentUser {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)

                    VStack(spacing: 8) {
                        Text(member.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(member.role)
                            .foregroundColor(.secondary)

                        Text("Member ID: \(member.memberId ?? "N/A")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    session.logout()
                } label: {
                    Text("Log Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager.shared)
}
