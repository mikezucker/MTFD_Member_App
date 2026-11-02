import AppKit
import SwiftUI

@MainActor final class FrameCapture {
    var frames: [Int: CGRect] = [:]
}

private struct Frames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

@main struct IPadLayoutTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let heights: [CGFloat] = [80, 200, 120, 60, 140]
        for (width, allowsColumns, expectedColumns, minimumWidth, gap) in [
            (393.0, true, 1, 459.0, 22.0), (600, true, 1, 459, 22), (834, true, 1, 459, 22), (939, true, 1, 459, 22), (940, true, 2, 459, 22), (1194, true, 2, 459, 22), (1366, false, 1, 459, 22),
            // Training uses two readable 340pt columns when the window permits.
            // Narrow phones / Split View and accessibility always remain in bounds.
            (288, true, 1, 340, 16), (393, true, 1, 340, 16), (600, true, 1, 340, 16), (695, true, 1, 340, 16), (696, true, 2, 340, 16), (788, true, 2, 340, 16), (1168, true, 2, 340, 16), (1168, false, 1, 340, 16)
        ] {
            let capture = FrameCapture()
            let root = DashboardCardGrid(spacing: gap, allowsColumns: allowsColumns, minimumColumnWidth: minimumWidth) {
                ForEach(heights.indices, id: \.self) { index in
                    Color.blue.frame(height: heights[index])
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: Frames.self, value: [index: geometry.frame(in: .named("grid"))])
                        })
                }
            }
            .coordinateSpace(name: "grid")
            .onPreferenceChange(Frames.self) { capture.frames = $0 }
            .frame(width: width, alignment: .topLeading)
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 1800), styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: width, height: 1800)
            host.layoutSubtreeIfNeeded()
            let deadline = Date().addingTimeInterval(2)
            while capture.frames.count < heights.count && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
            precondition(capture.frames.count == heights.count, "All cards must be rendered at width \(width)")
            let frames = heights.indices.map { capture.frames[$0]! }
            for frame in frames {
                precondition(frame.minX >= -1 && frame.maxX <= width + 1, "Card must stay within available window width")
            }
            if expectedColumns == 1 {
                for index in 1..<frames.count {
                    precondition(frames[index].minY >= frames[index - 1].maxY + gap - 1, "Stacked cards must not overlap")
                }
            } else {
                precondition(abs(frames[0].minY - frames[1].minY) < 1, "First pair must share a row")
                precondition(frames[1].minX >= frames[0].maxX + gap - 1, "Columns need a visible gutter")
                precondition(frames[2].minY >= max(frames[0].maxY, frames[1].maxY) + gap - 1, "Next row must clear the tallest card")
                precondition(frames[4].minY >= max(frames[2].maxY, frames[3].maxY) + gap - 1, "Odd final row must remain below the preceding row")
            }
            window.orderOut(nil)
            print("PASS: width \(Int(width)), \(expectedColumns) column(s), all 5 cards contained without overlap")
        }
    }
}
