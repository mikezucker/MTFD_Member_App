import SwiftUI

struct Motion {
    static let fast = Animation.easeOut(duration: 0.15)
    static let normal = Animation.easeOut(duration: 0.3)
    static let slow = Animation.easeOut(duration: 0.5)

    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
}
