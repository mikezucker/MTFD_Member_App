import Foundation

struct DispatchUnitOption: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct DispatchUnitsResponse: Decodable {
    let success: Bool
    let units: [DispatchUnitOption]?
    let error: String?
}

final class DispatchService {

    static func fetchUnits(completion: @escaping ([DispatchUnitOption]) -> Void) {
        Task {
            let units = (try? await APIClient.shared.fetchDispatchUnits()) ?? []
            await MainActor.run { completion(units) }
        }
    }

    static func fetchUnitsAsync() async -> [DispatchUnitOption] {
        await withCheckedContinuation { continuation in
            fetchUnits { units in
                continuation.resume(returning: units)
            }
        }
    }
}
