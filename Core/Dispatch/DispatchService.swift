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
        guard let url = URL(string: "https://new-mtfd-site.vercel.app/api/mobile/dispatch-units") else {
            completion([])
            return
        }

        guard let token = APIClient.shared.authToken, !token.isEmpty else {
            print("❌ No auth token available for dispatch units")
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print("❌ Dispatch units fetch failed:", error.localizedDescription)
                completion([])
                return
            }

            if let http = response as? HTTPURLResponse {
                print("📡 Dispatch units status:", http.statusCode)
            }

            guard let data else {
                print("❌ Dispatch units response had no data")
                completion([])
                return
            }

            Task { @MainActor in
                if let raw = String(data: data, encoding: .utf8) {
                    print("📥 Dispatch units raw:", raw)
                }
                do {
                    let decoded = try JSONDecoder().decode(DispatchUnitsResponse.self, from: data)
                    guard decoded.success else {
                        print("❌ Dispatch units API returned success=false:", decoded.error ?? "Unknown error")
                        completion([])
                        return
                    }
                    completion(decoded.units ?? [])
                } catch {
                    print("❌ Failed to decode dispatch units:", error.localizedDescription)
                    completion([])
                }
            }
        }.resume()
    }

    static func fetchUnitsAsync() async -> [DispatchUnitOption] {
        await withCheckedContinuation { continuation in
            fetchUnits { units in
                continuation.resume(returning: units)
            }
        }
    }
}
