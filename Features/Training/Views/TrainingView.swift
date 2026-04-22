import SwiftUI

struct TrainingView: View {
    @State private var courses: [AssignedTrainingCourse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AppScreen(title: "Training") {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if courses.isEmpty {
                    Text("No assigned training right now.")
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(courses) { course in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(course.title)
                                            .font(.headline)
                                            .foregroundColor(.white)

                                        Spacer()

                                        Text(course.assignmentStatus)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.gold)
                                            .foregroundColor(.black)
                                            .cornerRadius(8)
                                    }

                                    if !course.description.isEmpty {
                                        Text(course.description)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.75))
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(16)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .task {
            await loadCourses()
        }
    }

    @MainActor
    private func loadCourses() async {
        isLoading = true
        errorMessage = nil

        // Temporary until training endpoint is added back to APIClient
        courses = []

        isLoading = false
    }
}
