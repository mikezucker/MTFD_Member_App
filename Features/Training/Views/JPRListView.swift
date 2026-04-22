import SwiftUI

struct JPRListView: View {
    let course: Course

    var body: some View {
        Text("JPRs for \(course.title)")
            .navigationTitle("JPRs")
    }
}
