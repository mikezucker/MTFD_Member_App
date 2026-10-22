import SwiftUI

struct AppTheme {
    static let navy = Color(red: 3/255, green: 22/255, blue: 51/255) // #031633
    static let navyHighlight = Color(red: 9/255, green: 43/255, blue: 86/255)
    static let navyDeep = Color(red: 1/255, green: 10/255, blue: 24/255)
    static let commandBlue = Color(red: 42/255, green: 131/255, blue: 198/255)
    static let gold = Color(red: 255/255, green: 193/255, blue: 7/255)
    #if os(watchOS)
    static let background = Color.black
    #else
    static let background = Color(.systemGroupedBackground)
    #endif
    static let card = Color.white

    static let approved = Color.green
    static let pending = Color.orange
    static let danger = Color.red
}
