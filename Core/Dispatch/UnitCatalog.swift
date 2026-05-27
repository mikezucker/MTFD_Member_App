import Foundation
import Combine

@MainActor
final class UnitCatalog: ObservableObject {
    @Published var units: [DispatchUnitOption] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func loadUnits() async {
        isLoading = true
        errorMessage = nil

        let fetchedUnits = await DispatchService.fetchUnitsAsync()
        self.units = fetchedUnits

        print("🚒 Units loaded into UnitCatalog:", fetchedUnits.count)

        if fetchedUnits.isEmpty {
            self.errorMessage = "No units available or failed to load."
        }

        isLoading = false
    }

    func ingest(units: [DispatchUnitOption]) {
        self.units = units
    }
}
