import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct OpenActiveDispatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Active Dispatch"
    static var description = IntentDescription("Opens the MTFD app to active dispatches.")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOSApplicationExtension 18.0, *)
struct MTFDLiveActivitiesControl: ControlWidget {
    static let kind = "com.StartCPR.MTFD-Member-App.active-dispatch-control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenActiveDispatchIntent()) {
                Label("Active Dispatch", systemImage: "flame.fill")
            }
        }
        .displayName("MTFD Active Dispatch")
        .description("Quick access to active MTFD dispatches.")
    }
}
