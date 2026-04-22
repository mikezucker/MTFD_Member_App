import SwiftUI

struct AnnouncementsView: View {
    @State private var announcements: [APIClient.Announcement] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AppScreen(title: "Announcements") {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.gold)

                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                } else if announcements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.gold)

                        Text("No announcements right now.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(announcements) { announcement in
                                AnnouncementCard(announcement: announcement)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .task {
            await loadAnnouncements()
        }
    }

    @MainActor
    private func loadAnnouncements() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.fetchAnnouncements()
            announcements = response.announcements
        } catch {
            print("ANNOUNCEMENTS ERROR:", error)
            errorMessage = error.localizedDescription
            announcements = []
        }

        isLoading = false
    }
}

struct AnnouncementCard: View {
    let announcement: APIClient.Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(announcement.title)
                .font(.headline)
                .foregroundColor(.white)

            Text(announcement.message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.80))

            if let publishedAt = announcement.publishedAt, !publishedAt.isEmpty {
                Text(publishedAt)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

#Preview {
    AnnouncementsView()
}
