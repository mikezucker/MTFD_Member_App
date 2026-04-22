import SwiftUI

struct CourseDetailView: View {
    let course: Course

    var body: some View {
        VStack(spacing: 20) {

            // Title
            Text(course.title)
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            // Description
            Text(course.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Spacer()

            // Start Button
            NavigationLink {
                JPRListView(course: course)
            } label: {
                Text("Start Training")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

        }
        .padding()
        .navigationTitle("Course")
        .navigationBarTitleDisplayMode(.inline)
    }
}
