import Foundation

final class APIClient {
    static let shared = APIClient()

    private init() {}

    // MARK: - Environment

    enum Environment {
        case production
        case development

        var baseURL: String {
            switch self {
            case .production:
                return "https://new-mtfd-site.vercel.app"
            case .development:
                return "http://localhost:3000"
            }
        }
    }

    private let environment: Environment = .production

    private var baseURL: String {
        environment.baseURL
    }

    // MARK: - Auth

    var authToken: String?

    // MARK: - URL Session

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // MARK: - Request Builder

    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }

    private func makeRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = false
    ) throws -> URLRequest {
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresAuth {
            guard let token = authToken, !token.isEmpty else {
                throw APIError.missingAuthToken
            }

            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Generic Network Layer

    private func performRequest(_ request: URLRequest) async throws -> Data {
        #if DEBUG
        debugPrint("🌐 REQUEST: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "nil")")
        #endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            #if DEBUG
            debugPrint("📡 RESPONSE STATUS: \(http.statusCode)")
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                debugPrint("📥 RESPONSE BODY: \(responseString)")
            }
            #endif

            guard 200...299 ~= http.statusCode else {
                let serverMessage = extractServerMessage(from: data)

                if http.statusCode == 401 {
                    throw APIError.unauthorized(message: serverMessage)
                } else {
                    throw APIError.serverError(statusCode: http.statusCode, message: serverMessage)
                }
            }

            return data
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            throw APIError.networkError(error)
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatterWithMilliseconds = ISO8601DateFormatter()
            formatterWithMilliseconds.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = formatterWithMilliseconds.date(from: value) {
                return date
            }

            let formatterWithoutMilliseconds = ISO8601DateFormatter()
            formatterWithoutMilliseconds.formatOptions = [
                .withInternetDateTime
            ]

            if let date = formatterWithoutMilliseconds.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(value)
        } catch {
            throw APIError.encodingError(error.localizedDescription)
        }
    }

    private func extractServerMessage(from data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? String, !error.isEmpty {
                return error
            }

            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
        }

        if let rawString = String(data: data, encoding: .utf8),
           !rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawString
        }

        return nil
    }
    // MARK: - Training

    func fetchTraining() async throws -> MobileTrainingResponse {
        let request = try makeRequest(
            path: "/api/mobile/training",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileTrainingResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }
    
    func fetchTrainingCourseDetail(courseId: String) async throws -> MobileTrainingCourseDetailResponse {
        let request = try makeRequest(
            path: "/api/mobile/training/courses/\(courseId)",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileTrainingCourseDetailResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }
    
    // MARK: - Session Helpers

    func hasValidSession() -> Bool {
        guard let token = authToken, !token.isEmpty else {
            return false
        }

        return true
    }

    func clearSession() {
        authToken = nil
    }
    

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        let payload = LoginRequest(email: email, password: password)
        let body = try encode(payload)

        let request = try makeRequest(
            path: "/api/mobile/login",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        let data = try await performRequest(request)
        let response = try decode(LoginResponse.self, from: data)

        guard response.success else {
            throw APIError.serverError(
                statusCode: 401,
                message: response.error ?? "Login failed."
            )
        }

        guard let token = response.token, !token.isEmpty else {
            throw APIError.missingTokenInResponse
        }

        authToken = token
        return response
    }

    func fetchCurrentUser() async throws -> MemberResponse {
        let request = try makeRequest(
            path: "/api/mobile/me",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MemberResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func logout() {
        clearSession()
    }

    // MARK: - Dashboard

    func fetchDashboard() async throws -> DashboardResponse {
        let request = try makeRequest(
            path: "/api/mobile/dashboard",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(DashboardResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    // MARK: - Announcements

    func fetchAnnouncements() async throws -> AnnouncementsResponse {
        let request = try makeRequest(
            path: "/api/mobile/announcements",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(AnnouncementsResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    // MARK: - Messages

    func fetchMessages() async throws -> MobileMessagesResponse {
        let request = try makeRequest(
            path: "/api/mobile/messages",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileMessagesResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func markMessageRead(id: String) async throws -> MarkMessageReadResponse {
        let request = try makeRequest(
            path: "/api/mobile/messages/\(id)/read",
            method: "POST",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MarkMessageReadResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    // MARK: - Dispatch

    func fetchDispatchStats() async throws -> DispatchStatsResponse {
        let request = try makeRequest(
            path: "/api/mobile/stats",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(DispatchStatsResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func fetchDispatchHistory(window: String = "24h") async throws -> DispatchHistoryResponse {
        let request = try makeRequest(
            path: "/api/mobile/dispatches",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "window", value: window)
            ],
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(DispatchHistoryResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }
    func fetchMobileSchedule() async throws -> MobileScheduleResponse {
        let request = try makeRequest(
            path: "/api/mobile/schedule",
            requiresAuth: true
        )

        let data = try await performRequest(request)
        return try decode(MobileScheduleResponse.self, from: data)
    }
}


// MARK: - Errors

extension APIClient {
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case missingAuthToken
        case missingTokenInResponse
        case unauthorized(message: String?)
        case sessionExpired
        case serverError(statusCode: Int, message: String?)
        case networkError(URLError)
        case decodingError(String)
        case encodingError(String)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The server URL is invalid."

            case .invalidResponse:
                return "The server returned an invalid response."

            case .missingAuthToken:
                return "Authentication token is missing."

            case .missingTokenInResponse:
                return "Login succeeded, but no authentication token was returned."

            case .unauthorized(let message):
                return message ?? "You are not authorized. Please sign in again."

            case .sessionExpired:
                return "Your session expired. Please sign in again."

            case .serverError(let statusCode, let message):
                if let message, !message.isEmpty {
                    return "Server error (\(statusCode)): \(message)"
                } else {
                    return "Server error (\(statusCode))."
                }

            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"

            case .decodingError(let message):
                return "Failed to decode the server response. \(message)"

            case .encodingError(let message):
                return "Failed to encode the request. \(message)"

            case .unknown(let message):
                return "Unexpected error: \(message)"
            }
        }
    }
}

// MARK: - Request Models

extension APIClient {
    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }
}

// MARK: - Response Models

extension APIClient {
    struct LoginResponse: Decodable {
        let success: Bool
        let token: String?
        let member: Member?
        let error: String?
    }

    struct MemberResponse: Decodable {
        let success: Bool
        let member: Member
    }

    struct Member: Decodable {
        let name: String
        let role: String
        let company: String?
        let memberId: String?
        let expiration: String?
        let email: String?
    }

    struct AnnouncementsResponse: Decodable {
        let success: Bool
        let announcements: [Announcement]
    }

    struct Announcement: Decodable, Identifiable {
        let id: String
        let title: String
        let message: String
        let publishedAt: String?
    }

    struct DashboardResponse: Decodable {
        let success: Bool?
        let member: Member?
        let attentionItems: [AttentionItem]?
        let latestUpdates: [LatestUpdate]?
        let trainingSummary: TrainingSummary?
        let stats: DispatchStats?
        let department: DispatchBucket?
        let station: DispatchBucket?
        let activeDispatches: [ActiveDispatch]?
        let messageSummary: MessageSummary?
        let lastUpdated: String?
        let sourceLabel: String?
        let statsMessage: String?
        let stationUpdates: [DashboardUpdate]?
        let departmentUpdates: [DashboardUpdate]?
        let notesConfigured: Bool?
        let notesMessage: String?
        let error: String?
    }

    struct ActiveDispatch: Decodable, Identifiable {
        let id: String
        let callType: String
        let address: String?
        let placeName: String?
        let message: String?
        let units: [String]
        let dispatchedAt: Date?
        let priority: String?
        let isWorkingFire: Bool?
    }

    struct MessageSummary: Decodable {
        let unreadCount: Int
    }

    struct AttentionItem: Decodable, Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let actionLabel: String?
        let destination: String?
    }

    struct LatestUpdate: Decodable, Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let createdAt: String?
    }

    struct TrainingSummary: Decodable {
        let assignedTrainingCount: Int?
        let completedTrainingCount: Int?
        let pendingJprReviews: Int?
        let pendingDocumentSignatures: Int?
    }

    struct DashboardUpdate: Decodable, Identifiable {
        let id: String
        let title: String
        let message: String
        let audience: String?
        let stationTag: String?
        let isPinned: Bool?
        let startsAt: String?
        let endsAt: String?
        let updatedAt: String?
    }

    struct DispatchStatsResponse: Decodable {
        let success: Bool?
        let stats: DispatchStats?
        let department: DispatchBucket?
        let station: DispatchBucket?
        let lastUpdated: String?
        let sourceLabel: String?
        let message: String?
    }

    struct DispatchStats: Decodable {
        let department24h: Int?
        let department7d: Int?
        let department30d: Int?
        let departmentYtd: Int?
        let station24h: Int?
        let station7d: Int?
        let station30d: Int?
        let stationYtd: Int?
    }

    struct DispatchBucket: Decodable {
        let total24h: Int?
        let total7d: Int?
        let total30d: Int?
        let totalYtd: Int?
        let fire24h: Int?
        let fire7d: Int?
        let fire30d: Int?
        let fireYtd: Int?
        let ems24h: Int?
        let ems7d: Int?
        let ems30d: Int?
        let emsYtd: Int?
    }

    struct DispatchHistoryResponse: Decodable {
        let success: Bool
        let window: String
        let fetchedAt: Date?
        let sourceLabel: String?
        let activeDispatches: [ActiveDispatch]
        let historicalDispatches: [DispatchHistoryItem]
    }

    struct DispatchHistoryItem: Decodable, Identifiable {
        let id: String
        let stableId: String?
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
        let dispatchedAt: Date?
        let lastActivityAt: Date?
        let priority: String?
        let isWorkingFire: Bool?
        let isClosed: Bool?
    }
    
    struct MobileScheduleResponse: Decodable {
        let success: Bool
        let message: String?
        let date: String?
        let entries: [MobileScheduleEntry]
    }

    struct MobileScheduleEntry: Decodable, Identifiable {
        let id: String
        let title: String
        let station: String?
        let timeRange: String
        let staffing: [String]
        let staffingDetails: [MobileScheduleStaffingDetail]
    }

    struct MobileScheduleStaffingDetail: Decodable {
        let name: String?
        let qualifier: String?
        let isVacant: Bool
    }
}
