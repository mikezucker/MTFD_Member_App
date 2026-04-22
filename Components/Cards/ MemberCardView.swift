import SwiftUI

struct MemberCardView: View {
    let member: User

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(member.name)
                .font(.headline)

            Text(member.role)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Member ID: \(member.memberID)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Expiration: \(member.expiration)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
