import Foundation
import Combine

@MainActor
final class DispatchDetailViewModel: ObservableObject {
    @Published var dispatch: LiveDispatchDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(dispatchId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let encodedId = dispatchId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? dispatchId

        guard let url = URL(string: "https://new-mtfd-site.vercel.app/api/mobile/dispatches/\(encodedId)") else {
            errorMessage = "Invalid dispatch URL."
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Invalid server response."
                return
            }

            guard http.statusCode == 200 else {
                errorMessage = "Dispatch detail unavailable."
                return
            }

            let decoded = try JSONDecoder().decode(LiveDispatchDetailResponse.self, from: data)
            dispatch = decoded.dispatch
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LiveDispatchDetailResponse: Decodable {
    let success: Bool
    let dispatch: LiveDispatchDetail?
}

struct LiveDispatchDetail: Decodable, Identifiable {
    let id: String
    let stableId: String
    let callType: String
    let message: String?
    let placeName: String?
    let address: String?
    let address2: String?
    let city: String?
    let state: String?
    let latitude: Double?
    let longitude: Double?
    let units: [String]
    let tacChannel: String?
    let status: String?
    let dispatchedAt: String?
    let lastActivityAt: String?
    let fetchedAt: String?
}//
//  DispatchDetailViewModel.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/7/26.
//

