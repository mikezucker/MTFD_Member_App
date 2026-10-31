import Foundation

enum DispatchUnitFilter {
    static func visibleRespondingUnits(from units: [String]) -> [String] {
        units.filter { unit in
            let normalized = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard !normalized.isEmpty else { return false }

            let blockedUnits = [
                "hq",
                "oem",
                "station",
                "station 1",
                "station 2",
                "station 3",
                "station 4",
                "station 5"
            ]

            if blockedUnits.contains(normalized) { return false }
            if normalized.hasPrefix("station ") { return false }

            return true
        }
    }
}

extension APIClient.ActiveDispatch {
    var isVisibleActiveDispatch: Bool {
        if isClosed == true {
            return false
        }

        if let status,
           status.range(of: "closed", options: .caseInsensitive) != nil ||
            status.range(of: "clear", options: .caseInsensitive) != nil ||
            status.range(of: "complete", options: .caseInsensitive) != nil ||
            status.range(of: "cancel", options: .caseInsensitive) != nil {
            return false
        }

        guard let latestTimestamp = [lastActivityAt, dispatchedAt]
            .compactMap({ $0 })
            .max() else {
            return false
        }

        return Date().timeIntervalSince(latestTimestamp) <= 90 * 60
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

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

    func absoluteURL(from pathOrURL: String?) -> URL? {
        guard let rawValue = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }

        if let url = URL(string: rawValue), url.scheme != nil {
            return url
        }

        let normalizedPath = rawValue.hasPrefix("/") ? rawValue : "/\(rawValue)"
        return URL(string: baseURL + normalizedPath)
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

    // Startup must fail promptly when offline so the member can retry their saved sign-in.
    private let sessionValidationSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
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
            if authToken?.isEmpty != false,
               let savedToken = KeychainService.shared.loadToken(),
               !savedToken.isEmpty {
                authToken = savedToken
            }

            guard let token = authToken, !token.isEmpty else {
                throw APIError.missingAuthToken
            }

            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Generic Network Layer

    private func performRequest(_ originalRequest: URLRequest, allowRefresh: Bool = true, using requestSession: URLSession? = nil) async throws -> Data {
        var request = originalRequest
        let authenticated = request.value(forHTTPHeaderField: "Authorization") != nil
        if authenticated {
            guard let current = KeychainService.shared.loadToken() else { throw APIError.sessionExpired }
            request.setValue("Bearer \(current)", forHTTPHeaderField: "Authorization")
        }
        #if DEBUG
        debugPrint("🌐 REQUEST: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "nil")")
        #endif

        do {
            let (data, response) = try await (requestSession ?? session).data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            #if DEBUG
            debugPrint("📡 RESPONSE STATUS: \(http.statusCode)")
            #endif

            guard 200...299 ~= http.statusCode else {
                let serverMessage = extractServerMessage(from: data)

                if http.statusCode == 401 {
                    if authenticated {
                        let rejectedToken = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "") ?? ""
                        if allowRefresh, KeychainService.shared.loadSession() != nil {
                            do {
                                let renewed = try await MobileSessionRenewal.shared.renew(rejectedToken: rejectedToken, baseURL: baseURL)
                                guard KeychainService.shared.loadSession()?.accessToken == renewed else { throw CancellationError() }
                                request.setValue("Bearer \(renewed)", forHTTPHeaderField: "Authorization")
                                return try await performRequest(request, allowRefresh: false, using: requestSession)
                            } catch APIError.sessionExpired {
                                invalidateSession(matching: rejectedToken)
                                throw APIError.sessionExpired
                            }
                        }
                        invalidateSession(matching: rejectedToken)
                        throw APIError.sessionExpired
                    }
                    throw APIError.unauthorized(message: serverMessage)
                } else {
                    throw APIError.serverError(statusCode: http.statusCode, message: serverMessage)
                }
            }

            return data
        } catch is CancellationError {
            throw CancellationError()
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

        if let rawString = String(data: data, encoding: .utf8) {
            let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            let lowercased = trimmed.lowercased()
            if lowercased.hasPrefix("<!doctype html") || lowercased.hasPrefix("<html") {
                return nil
            }

            return String(trimmed.prefix(300))
        }

        return nil
    }
    func memberTours<T: Decodable>(body: Data? = nil) async throws -> T {
        let request = try makeRequest(path: "/api/members/admin/tours", method: body == nil ? "GET" : "POST", body: body, requiresAuth: true)
        return try decode(T.self, from: await performRequest(request))
    }
    func currentMemberTour() async throws -> CurrentMemberTourResponse {
        let request = try makeRequest(path: "/api/members/tour", method: "GET", requiresAuth: true)
        return try decode(CurrentMemberTourResponse.self, from: await performRequest(request))
    }
    func trainingWorkspace<T: Decodable>(_ path: String = "", body: Data? = nil) async throws -> T {
        let request = try makeRequest(path: "/api/training/workspace" + path, method: body == nil ? "GET" : "POST", body: body, requiresAuth: true)
        return try decode(T.self, from: await performRequest(request))
    }

    func uploadJPRMedia(file:URL,mimeType:String) async throws -> String {
        let size=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0
        let limit=mimeType.hasPrefix("video/") ? 50*1024*1024 : 12*1024*1024
        guard size>0,size<=limit else {throw APIError.unknown("Choose a photograph up to 12 MB or a video up to 50 MB.")}
        let ticket:JPRMediaTicket=try await trainingWorkspace("/jpr-media",body:JSONSerialization.data(withJSONObject:["action":"prepare","fileName":file.lastPathComponent,"mimeType":mimeType,"sizeBytes":size]))
        try Task.checkCancellation()
        var upload=URLRequest(url:ticket.uploadUrl);upload.httpMethod="PUT";upload.timeoutInterval=120
        upload.setValue(mimeType,forHTTPHeaderField:"Content-Type");upload.setValue("false",forHTTPHeaderField:"x-upsert")
        // The signed storage request deliberately receives no app bearer credential.
        let (_,response)=try await URLSession.shared.upload(for:upload,fromFile:file)
        guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else {throw APIError.unknown("Upload interrupted. Choose the file again to retry.")}
        try Task.checkCancellation()
        let _:TrainingWorkspaceMutation=try await trainingWorkspace("/jpr-media",body:JSONSerialization.data(withJSONObject:["action":"confirm","assetId":ticket.assetId]))
        return ticket.assetId
    }
    func jprMediaURL(assetId:String,versionId:String?) async throws -> URL {
        var components=URLComponents();components.queryItems=[URLQueryItem(name:"assetId",value:assetId)]
        if let versionId {components.queryItems?.append(URLQueryItem(name:"versionId",value:versionId))}
        let result:JPRMediaLocation=try await trainingWorkspace("/jpr-media"+(components.string ?? ""));return result.url
    }

    func uploadWorkspaceTraining(data: Data, fileName: String, mimeType: String) async throws -> WorkspaceUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        let name = fileName.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "_").replacingOccurrences(of: "\n", with: "_")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        var request = try makeRequest(path: "/api/training/workspace/uploads", method: "POST", body: body, requiresAuth: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return try decode(WorkspaceUploadResponse.self, from: await performRequest(request))
    }

    func uploadGuidedJPR(data: Data, fileName: String, courseId: String) async throws -> GuidedImport {
        let boundary = "Boundary-\(UUID().uuidString)"
        let name = fileName.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "_").replacingOccurrences(of: "\n", with: "_")
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"courseId\"\r\n\r\n\(courseId)\r\n")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document\r\n\r\n")
        body.append(data); body.append("\r\n--\(boundary)--\r\n")
        var request = try makeRequest(path: "/api/training/workspace/jprs", method: "POST", body: body, requiresAuth: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return try decode(GuidedImport.self, from: await performRequest(request))
    }

    func guidedJPRPrint(_ versionId: String) async throws -> String {
        let request = try makeRequest(path: "/api/training/workspace/jprs/\(versionId)/print", method: "GET", requiresAuth: true)
        let data = try await performRequest(request)
        guard let html = String(data: data, encoding: .utf8) else { throw APIError.invalidResponse }
        return html
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

    func updateTrainingProgress(
        courseId: String,
        request payload: TrainingProgressUpdateRequest
    ) async throws -> TrainingProgressUpdateResponse {
        let body = try encode(payload)

        let request = try makeRequest(
            path: "/api/mobile/training/courses/\(courseId)/progress",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(TrainingProgressUpdateResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func fetchTrainingLesson(courseId: String, lessonId: String) async throws -> TrainingLessonSnapshotResponse {
        let request = try makeRequest(path: "/api/training/courses/\(courseId)/lessons/\(lessonId)", method: "GET", requiresAuth: true)
        return try decode(TrainingLessonSnapshotResponse.self, from: await performRequest(request))
    }

    func trainingLessonAction(courseId: String, lessonId: String, action: TrainingLessonAction) async throws -> TrainingLessonActionResponse {
        let request = try makeRequest(path: "/api/training/courses/\(courseId)/lessons/\(lessonId)", method: "POST", body: try encode(action), requiresAuth: true)
        return try decode(TrainingLessonActionResponse.self, from: await performRequest(request))
    }

    func trainingMediaURL(_ url: URL) async throws -> URL {
        guard url.host == absoluteURL(from: "/")?.host, url.path.hasPrefix("/api/") else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "format" } + [URLQueryItem(name: "format", value: "json")]
        let request = try makeRequest(path: components.percentEncodedPath + "?" + (components.percentEncodedQuery ?? ""), method: "GET", requiresAuth: true)
        let response = try decode(TrainingMediaResponse.self, from: await performRequest(request))
        guard response.success, let mediaURL = response.url else { throw APIError.serverError(statusCode: 503, message: response.error ?? "Training media unavailable.") }
        return mediaURL
    }

    func fetchTrainingManageCourses() async throws -> MobileTrainingManageCoursesResponse {
        let request = try makeRequest(
            path: "/api/mobile/training/manage/courses",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileTrainingManageCoursesResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }


    func createTrainingCourse(
        request payload: CreateTrainingCourseRequest
    ) async throws -> CreateTrainingCourseResponse {
        let body = try encode(payload)

        let request = try makeRequest(
            path: "/api/mobile/training/manage/courses",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(CreateTrainingCourseResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func updateTrainingCourse(
        courseId: String,
        request payload: UpdateTrainingCourseRequest
    ) async throws -> TrainingMutationResponse {
        let body = try encode(payload)

        let request = try makeRequest(
            path: "/api/mobile/training/courses/\(courseId)",
            method: "PATCH",
            body: body,
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(TrainingMutationResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func deleteTrainingCourse(courseId: String) async throws -> TrainingMutationResponse {
        let request = try makeRequest(
            path: "/api/mobile/training/courses/\(courseId)",
            method: "DELETE",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(TrainingMutationResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func uploadTrainingContent(
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> TrainingUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        var request = try makeRequest(
            path: "/api/mobile/training/uploads",
            method: "POST",
            body: body,
            requiresAuth: true
        )
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            let data = try await performRequest(request)
            return try decode(TrainingUploadResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func assignTrainingCourse(
        courseId: String,
        request payload: AssignTrainingCourseRequest
    ) async throws -> AssignTrainingCourseResponse {
        let body = try encode(payload)

        let request = try makeRequest(
            path: "/api/mobile/training/courses/\(courseId)/assignments",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(AssignTrainingCourseResponse.self, from: data)
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

    private func invalidateSession(matching rejectedToken: String) {
        // A late response from an old request must not sign out a newly signed-in user.
        guard KeychainService.shared.loadToken() == rejectedToken else { return }
        clearSession()
    }

    func clearSession() {
        authToken = nil
        KeychainService.shared.deleteToken()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .didInvalidateSession, object: nil)
        }
    }
    

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        struct RenewableLogin: Encodable {
            let email: String
            let password: String
            let sessionVersion = 2
            let deviceName = "iPhone"
        }
        let payload = RenewableLogin(email: email, password: password)
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

        guard response.member != nil else { throw APIError.invalidResponse }
        if let refreshToken = response.refreshToken, let sessionId = response.sessionId {
            try KeychainService.shared.saveSession(MobileSessionCredentials(accessToken: token, refreshToken: refreshToken, sessionId: sessionId))
        } else if response.refreshToken == nil && response.sessionId == nil {
            // Backend-first rollout: a pre-renewal backend still returns a legacy session.
            KeychainService.shared.deleteSession()
        } else {
            throw APIError.invalidResponse
        }
        KeychainService.shared.saveToken(token)
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
            let data = try await performRequest(request, using: sessionValidationSession)
            return try decode(MemberResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func updateProfile(name: String, email: String, phone: String?) async throws -> MemberResponse {
        let payload = UpdateProfileRequest(
            name: name,
            email: email,
            phone: phone,
            confirmedFirstDueSync: true
        )
        let body = try encode(payload)

        let request = try makeRequest(
            path: "/api/mobile/profile",
            method: "PATCH",
            body: body,
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

    func fetchMobileAdminUsers() async throws -> MobileAdminUsersResponse {
        let request = try makeRequest(
            path: "/api/mobile/admin/users",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileAdminUsersResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func updateMobileAdminUser(_ payload: MobileAdminUserUpdateRequest) async throws -> MobileAdminUserUpdateResponse {
        let request = try makeRequest(
            path: "/api/mobile/admin/users",
            method: "PATCH",
            body: try encode(payload),
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileAdminUserUpdateResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func fetchNotificationPreferences() async throws -> NotificationPreferencesResponse {
        let request = try makeRequest(
            path: "/api/mobile/notification-preferences",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(NotificationPreferencesResponse.self, from: data)
        } catch {
            throw error
        }
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) async throws -> NotificationPreferencesResponse {
        let body = try encode(preferences)

        let request = try makeRequest(
            path: "/api/mobile/notification-preferences",
            method: "PATCH",
            body: body,
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(NotificationPreferencesResponse.self, from: data)
        } catch {
            throw error
        }
    }

    func fetchUniforms() async throws -> MobileUniformsResponse {
        let request = try makeRequest(
            path: "/api/mobile/uniforms",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileUniformsResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func submitUniformRequest(_ payload: UniformRequestSubmissionRequest) async throws -> MobileUniformsResponse {
        let body = try encode(payload)

        let request = try makeRequest(
            path: "/api/mobile/uniforms",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileUniformsResponse.self, from: data)
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

    // MARK: - Documents

    func fetchDocuments() async throws -> MobileDocumentsResponse {
        let request = try makeRequest(
            path: "/api/mobile/documents",
            method: "GET",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileDocumentsResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func downloadDocumentVersion(versionId: String) async throws -> Data {
        let request = try makeRequest(
            path: "/api/mobile/documents/version/\(versionId)/file",
            method: "GET",
            requiresAuth: true
        )

        do {
            return try await performRequest(request)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func acknowledgeDocumentVersion(versionId: String, password: String) async throws -> MobileDocumentAcknowledgementResponse {
        let payload = MobileDocumentAcknowledgementRequest(password: password)
        let body = try encode(payload)
        let request = try makeRequest(
            path: "/api/mobile/documents/version/\(versionId)/acknowledge",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(MobileDocumentAcknowledgementResponse.self, from: data)
        } catch APIError.unauthorized {
            throw APIError.serverError(statusCode: 401, message: "Incorrect password.")
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

    func deleteMessage(id: String) async throws -> DeleteMessageResponse {
        let request = try makeRequest(
            path: "/api/mobile/messages/\(id)",
            method: "DELETE",
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(DeleteMessageResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }


    func createCommandMessage(
        title: String,
        body: String,
        audience: String,
        priority: String = "NORMAL",
        type: String,
        stationNumberTarget: Int? = nil,
        expiresAt: String? = nil,
        isPinned: Bool = false,
        linkUrl: String? = nil,
        linkLabel: String? = nil
    ) async throws -> CreateCommandMessageResponse {
        let payload = CreateCommandMessageRequest(
            title: title,
            body: body,
            audience: audience,
            priority: priority,
            type: type,
            stationNumberTarget: stationNumberTarget,
            expiresAt: expiresAt,
            isPinned: isPinned,
            linkUrl: linkUrl,
            linkLabel: linkLabel
        )

        let request = try makeRequest(
            path: "/api/mobile/messages",
            method: "POST",
            body: try encode(payload),
            requiresAuth: true
        )

        do {
            let data = try await performRequest(request)
            return try decode(CreateCommandMessageResponse.self, from: data)
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }

    func startPasswordRecovery(identifier: String, publicKey: String) async throws -> RecoveryStartResponse {
        let body = try JSONSerialization.data(withJSONObject: ["identifier":identifier,"publicKey":publicKey])
        let request = try makeRequest(path:"/api/mobile/security/recovery/request",method:"POST",body:body)
        return try decode(RecoveryStartResponse.self,from:await performRequest(request))
    }
    func findRecoveryAccount(firstName: String, lastName: String, station: String) async throws -> RecoveryAccountLookupResponse {
        let body = try JSONSerialization.data(withJSONObject: ["firstName": firstName, "lastName": lastName, "station": station])
        let request = try makeRequest(path: "/api/mobile/security/recovery/lookup", method: "POST", body: body)
        return try decode(RecoveryAccountLookupResponse.self, from: await performRequest(request))
    }
    func startPasswordRecovery(lookupToken: String, publicKey: String) async throws -> RecoveryStartResponse {
        let body = try JSONSerialization.data(withJSONObject: ["lookupToken": lookupToken, "publicKey": publicKey])
        let request = try makeRequest(path: "/api/mobile/security/recovery/request", method: "POST", body: body)
        return try decode(RecoveryStartResponse.self, from: await performRequest(request))
    }
    func passwordRecoveryStatus(_ pending: PendingPasswordRecovery) async throws -> RecoveryStatusResponse {
        let request = try makeRequest(path:"/api/mobile/security/recovery/status",method:"POST",body:recoveryOwnerBody(pending))
        return try decode(RecoveryStatusResponse.self,from:await performRequest(request))
    }
    func passwordRecoveryChallenge(_ pending: PendingPasswordRecovery) async throws -> String {
        struct Response: Decodable { let challenge: String }
        let request = try makeRequest(path:"/api/mobile/security/recovery/challenge",method:"POST",body:recoveryOwnerBody(pending))
        return try decode(Response.self,from:await performRequest(request)).challenge
    }
    private func recoveryOwnerBody(_ pending: PendingPasswordRecovery) throws -> Data {
        try JSONSerialization.data(withJSONObject:["requestId":pending.requestId,"statusToken":pending.statusToken])
    }
    func completePasswordRecovery(_ pending: PendingPasswordRecovery, signature: String, password: String, confirmation: String) async throws -> String? {
        let body = try JSONSerialization.data(withJSONObject:["requestId":pending.requestId,"statusToken":pending.statusToken,
                                                             "signature":signature,"password":password,"confirmation":confirmation])
        let request = try makeRequest(path:"/api/mobile/security/recovery/complete",method:"POST",body:body)
        struct Response: Decodable { let identifier: String? }
        return try decode(Response.self, from: await performRequest(request)).identifier
    }
    struct RecoveryApproverMember: Decodable, Identifiable {
        let id: String
        let name: String?
        let email: String
        let role: String
        let canApprove: Bool
        let inheritedRoleAccess: Bool
        let isCurrentUser: Bool
    }

    func fetchRecoveryApprovers() async throws -> [RecoveryApproverMember] {
        struct Response: Decodable { let members: [RecoveryApproverMember] }
        let request = try makeRequest(path: "/api/mobile/admin/recovery/approvers", requiresAuth: true)
        return try decode(Response.self, from: await performRequest(request)).members
    }

    func setRecoveryApprover(userId: String, enabled: Bool, password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["userId": userId, "enabled": enabled, "password": password])
        let request = try makeRequest(path: "/api/mobile/admin/recovery/approvers", method: "PATCH", body: body, requiresAuth: true)
        _ = try await performRequest(request)
    }

    func fetchPasswordRecoveryRequests() async throws -> [AdminRecoveryRequest] {
        struct Response: Decodable { let requests: [AdminRecoveryRequest] }
        let request = try makeRequest(path:"/api/mobile/admin/recovery",requiresAuth:true)
        return try decode(Response.self,from:await performRequest(request)).requests
    }
    func decidePasswordRecovery(requestId: String, password: String, decision: String, matchCode: String,
                                method: String, verificationReference: String) async throws {
        var body = ["requestId":requestId,"password":password,"decision":decision,"matchCode":matchCode]
        if decision == "APPROVE" { body["method"]=method; body["verificationReference"]=verificationReference }
        let request = try makeRequest(path:"/api/mobile/admin/recovery",method:"POST",body:JSONSerialization.data(withJSONObject:body),requiresAuth:true)
        _ = try await performRequest(request)
    }

    func fetchDispatchUnits() async throws -> [DispatchUnitOption] {
        let request = try makeRequest(path: "/api/mobile/dispatch-units", requiresAuth: true)
        let data = try await performRequest(request)
        let response = try decode(DispatchUnitsResponse.self, from: data)
        guard response.success else { throw APIError.invalidResponse }
        return response.units ?? []
    }



    struct NotificationTestResponse: Decodable {
        struct Delivery: Decodable {
            let ok: Bool
            let status: Int
        }
        let success: Bool
        let results: [Delivery]?
        let error: String?
    }

    func sendNotificationTest(isCritical: Bool = false) async throws -> NotificationTestResponse {
        let body = try JSONSerialization.data(withJSONObject: [
            "title": isCritical ? "MTFD Critical Notification Test" : "MTFD Notification Test",
            "body": "Push test. No dispatch or response is required.",
            "alertKind": isCritical ? "critical" : "normal"
        ])
        var request = try makeRequest(path: "/api/admin/push/test", method: "POST", body: body, requiresAuth: true)
        request.timeoutInterval = 15
        return try decode(NotificationTestResponse.self, from: await performRequest(request))
    }

    func registerPushDevice(body: [String: Any]) async throws {
        let request = try makeRequest(path: "/api/mobile/push/register", method: "POST",
                                      body: JSONSerialization.data(withJSONObject: body), requiresAuth: true)
        _ = try await performRequest(request)
    }

    func revokeSession(refreshToken: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])
        let request = try makeRequest(path: "/api/mobile/session/logout", method: "POST", body: body)
        _ = try await performRequest(request)
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
            let response = try decode(DispatchHistoryResponse.self, from: data)
            return DispatchHistoryResponse(
                success: response.success,
                window: response.window,
                fetchedAt: response.fetchedAt,
                sourceLabel: response.sourceLabel,
                activeDispatches: response.activeDispatches.filter(\.isVisibleActiveDispatch),
                historicalDispatches: response.historicalDispatches
            )
        } catch APIError.unauthorized {
            clearSession()
            throw APIError.sessionExpired
        } catch {
            throw error
        }
    }
    func registerLiveActivityPushToStartToken(_ token: String) async throws {
        struct Body: Encodable {
            let token: String
            let activityType: String
            let platform: String
        }

        let body = Body(
            token: token,
            activityType: "DISPATCH",
            platform: "IOS"
        )

        let data = try JSONEncoder().encode(body)

        let request = try makeRequest(
            path: "/api/mobile/live-activities/push-to-start/register",
            method: "POST",
            body: data,
            requiresAuth: true
        )

        _ = try await performRequest(request)
    }

    func recordDispatchPushReceipt(
        dispatchId: String,
        event: String,
        notificationType: String,
        deviceToken: String?
    ) async throws {
        struct Body: Encodable {
            let dispatchId: String
            let event: String
            let notificationType: String
            let deviceToken: String?
        }

        let data = try JSONEncoder().encode(
            Body(
                dispatchId: dispatchId,
                event: event,
                notificationType: notificationType,
                deviceToken: deviceToken
            )
        )

        let request = try makeRequest(
            path: "/api/mobile/push/receipt",
            method: "POST",
            body: data,
            requiresAuth: true
        )

        _ = try await performRequest(request)
    }

    func fetchMobileSchedule(date: String? = nil) async throws -> MobileScheduleResponse {
        let path: String

        if let date, !date.isEmpty {
            path = "/api/mobile/schedule?date=\(date)"
        } else {
            path = "/api/mobile/schedule"
        }

        let request = try makeRequest(
            path: path,
            requiresAuth: true
        )

        let data = try await performRequest(request)
        return try decode(MobileScheduleResponse.self, from: data)
    }

    func fetchMobileUpcomingSchedule() async throws -> MobileUpcomingScheduleResponse {
        let request = try makeRequest(
            path: "/api/mobile/schedule/me/upcoming",
            requiresAuth: true
        )

        let data = try await performRequest(request)
        return try decode(MobileUpcomingScheduleResponse.self, from: data)
    }
}


// MARK: - Errors

extension APIClient {
    static func isRequestCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError { return urlError.code == .cancelled }
        if let apiError = error as? APIError, case .networkError(let urlError) = apiError {
            return urlError.code == .cancelled
        }
        return false
    }

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

    struct UpdateProfileRequest: Encodable {
        let name: String
        let email: String
        let phone: String?
        let confirmedFirstDueSync: Bool
    }

    struct CreateCommandMessageRequest: Encodable {
        let title: String
        let body: String
        let audience: String
        let priority: String
        let type: String
        let stationNumberTarget: Int?
        let expiresAt: String?
        let isPinned: Bool
        let linkUrl: String?
        let linkLabel: String?
    }

    struct MobileAdminUserUpdateRequest: Encodable {
        let id: String
        let role: String
        let status: String
        let company: String?
        let reportsToUserId: String?
        let badgeNumber: String?
        let stationMessageDelegate: Bool?
        let attributeIds: [String]?
        let actorPassword: String?
    }

    struct MemberAccessRequest: Encodable {
        let email: String
        let type: String
    }

    struct UniformRequestSubmissionRequest: Encodable {
        let comments: String?
        let replacementAcknowledged: Bool
        let items: [UniformRequestSubmissionItem]
    }

    struct UniformRequestSubmissionItem: Encodable {
        let sectionId: String
        let style: String
        let quantity: Int
        let size: String
    }
}

// MARK: - Response Models

extension APIClient {
    struct MemberAccessRequestResponse: Decodable {
        let ok: Bool
        let error: String?
        let devLink: String?
    }

    struct LoginResponse: Decodable {
        let success: Bool
        let token: String?
        let refreshToken: String?
        let sessionId: String?
        let member: Member?
        let error: String?
    }

    struct MemberResponse: Decodable {
        let success: Bool
        let member: Member
    }

    struct MemberTour: Decodable, Identifiable, Equatable {
        struct Lieutenant: Decodable, Equatable { let id: String; let name: String? }
        let id: String
        let name: String
        let isActive: Bool
        let lieutenant: Lieutenant?
        var displayName: String { name + (isActive ? "" : " (archived)") }
    }
    struct CurrentMemberTourResponse: Decodable { let success: Bool; let tour: MemberTour? }
    struct Member: Decodable {
        var tour: MemberTour? = nil
        let name: String
        let role: String
        let company: String?
        let memberId: String?
        let expiration: String?
        let email: String?
        let phone: String?
        let attributes: [String]?
        let permissions: MobileMemberPermissions?

        var canApprovePasswordRecovery: Bool {
            permissions?.canApprovePasswordRecovery == true || role == "ADMIN" || role == "CHIEF"
        }

        var canPostStationMessages: Bool {
            permissions?.canPostStationMessages == true
        }

        var canManageUsers: Bool {
            permissions?.canManageReporting == true
                || role == "OFFICER_CAREER"
                || isFireHeadquarters
        }

        var isReliefDriver: Bool {
            attributes?.contains { attribute in
                let normalized = attribute
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "-", with: "_")

                return normalized == "RELIEF_DRIVER"
                    || normalized == "RELIEFDRIVER"
            } == true
        }

        var isFireHeadquarters: Bool {
            let normalized = (company ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "-", with: "_")

            return normalized == "FIRE_HQ"
                || normalized == "HQ"
                || normalized == "FIRE_HEADQUARTERS"
        }

        var canAccessUniforms: Bool {
            role == "MEMBER_CAREER"
                || role == "OFFICER_CAREER"
                || isFireHeadquarters
                || isReliefDriver
        }
    }

    struct MobileMemberPermissions: Decodable {
        let canApprovePasswordRecovery: Bool?
        let canPostStationMessages: Bool?
        let canManageReporting: Bool?
    }

    struct MobileAdminUsersResponse: Decodable {
        let success: Bool
        let canEditDepartmentRoles: Bool
        let attributes: [MobileAdminAttribute]?
        let users: [MobileAdminUser]
    }

    struct MobileAdminUserUpdateResponse: Decodable {
        let success: Bool
        let user: MobileAdminUser
    }

    struct MobileAdminAttribute: Decodable, Identifiable, Equatable {
        let id: String
        let name: String
        let slug: String
        let description: String?
        let isActive: Bool
    }

    struct MobileAdminUser: Decodable, Identifiable, Equatable {
        let id: String
        let email: String
        let name: String?
        let phone: String?
        let role: String
        let status: String
        let company: String?
        let badgeNumber: String?
        let reportsToUserId: String?
        let attributes: [MobileAdminAttribute]?
        let canPostStationMessages: Bool?
        let stationMessageDelegate: Bool?
        let updatedAt: String?

        var displayName: String {
            let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName.isEmpty ? email : trimmedName
        }

        var searchableText: String {
            [
                name,
                email,
                phone,
                roleLabel,
                companyLabel,
                badgeNumber,
                attributes?.map(\.name).joined(separator: " ")
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        }

        var roleLabel: String {
            APIClient.MobileAdminUser.roleLabel(for: role)
        }

        var roleEmoji: String {
            switch role {
            case "ADMIN": return "🛠️"
            case "CHIEF", "BATTALION_CHIEF": return "🛡️"
            case "OFFICER_CAREER", "OFFICER_VOLUNTEER": return "🚒"
            case "MEMBER_CAREER", "MEMBER_VOLUNTEER": return "👤"
            default: return "👥"
            }
        }

        var companyLabel: String {
            APIClient.MobileAdminUser.companyLabel(for: company)
        }

        static func roleLabel(for role: String) -> String {
            switch role {
            case "ADMIN": return "Admin"
            case "CHIEF": return "Chief"
            case "BATTALION_CHIEF": return "Battalion Chief"
            case "OFFICER_CAREER": return "Officer (Career)"
            case "OFFICER_VOLUNTEER": return "Officer (Volunteer)"
            case "MEMBER_CAREER": return "Member (Career)"
            case "MEMBER_VOLUNTEER": return "Member (Volunteer)"
            default: return role
            }
        }

        static func companyLabel(for company: String?) -> String {
            switch company {
            case "MT_KEMBLE": return "Mt. Kemble Fire Company (Station 1)"
            case "COLLINSVILLE": return "Collinsville Fire Company (Station 2)"
            case "HILLSIDE": return "Hillside Fire Company (Station 3)"
            case "FAIRCHILD": return "Fairchild Fire Company (Station 4)"
            case "WOODLAND": return "Woodland Fire Company (Station 5)"
            case "FIRE_HQ": return "Fire Headquarters"
            case .some(let value): return value
            case .none: return "No company assigned"
            }
        }
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

    struct MobileUniformsResponse: Decodable {
        let success: Bool
        let canSubmit: Bool
        let memberType: String?
        let badgeNumber: String?
        let catalog: [UniformCatalogSection]
        let requests: [UniformRequest]
        let request: UniformRequest?
        let error: String?
    }

    struct UniformCatalogSection: Decodable, Identifiable {
        let id: String
        let title: String
        let note: String
        let items: [UniformCatalogItem]
    }

    struct UniformCatalogItem: Decodable, Identifiable {
        let style: String
        let description: String

        var id: String { style }
    }

    struct UniformRequest: Decodable, Identifiable {
        let id: String
        let referenceCode: String
        let memberType: String
        let badgeNumber: String?
        let comments: String?
        let totalItems: Int
        let status: String
        let statusLabel: String
        let reviewNote: String?
        let requestedAt: Date?
        let reviewedAt: Date?
        let updatedAt: Date?
        let assignedTo: UniformRequestPerson?
        let reviewedBy: UniformRequestPerson?
        let items: [UniformRequestItem]
    }

    struct UniformRequestPerson: Decodable {
        let id: String
        let name: String?
        let email: String?
    }

    struct UniformRequestItem: Decodable, Identifiable {
        let id: String
        let sectionId: String
        let sectionTitle: String
        let style: String
        let description: String
        let quantity: Int
        let size: String
    }

    struct DashboardResponse: Decodable {
        var scheduledTraining: [ScheduledTrainingItem]? = nil
        let success: Bool?
        let member: Member?
        let attentionItems: [AttentionItem]?
        let latestUpdates: [LatestUpdate]?
        let trainingSummary: TrainingSummary?
        let assignedTrainingPreview: [DashboardTrainingPreviewItem]?
        let volunteerContext: VolunteerContext?
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
        let apparatusWorkOrders: [ApparatusWorkOrder]?
        let apparatusWorkOrdersMessage: String?
        let historicalDispatches: [DispatchHistoryItem]?
        let notesConfigured: Bool?
        let notesMessage: String?
        let error: String?
    }

    struct VolunteerContext: Decodable {
        let company: String?
        let station: String?
        let officer: VolunteerOfficer?
        let apparatus: VolunteerApparatus?
        let stationApparatus: [VolunteerApparatus]?
    }

    struct VolunteerOfficer: Decodable {
        let id: String?
        let name: String?
        let email: String?
        let phone: String?
        let role: String?
    }

    struct VolunteerApparatus: Decodable {
        let displayName: String?
        let station: String?
        let dispatchUnitIds: String?
        let apparatusApiId: String?
        let unitId: String?
    }

    struct ApparatusWorkOrder: Decodable, Identifiable {
        let id: String
        let apparatusApiId: String?
        let apparatusName: String
        let title: String
        let status: String?
    }

    struct ActiveDispatch: Decodable, Identifiable {
        let id: String
        let callType: String
        let address: String?
        var address2: String? = nil
        let placeName: String?
        var city: String? = nil
        var state: String? = nil
        var latitude: Double? = nil
        var longitude: Double? = nil
        let message: String?
        let units: [String]
        let dispatchedAt: Date?
        let lastActivityAt: Date?
        let priority: String?
        let isWorkingFire: Bool?
        let status: String?
        let isClosed: Bool?
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

    struct DashboardTrainingPreviewItem: Decodable, Identifiable {
        let id: String
        let courseId: String
        let title: String
        let progressStatus: String
        let progressPercent: Int
        let dueAt: Date?
        let isOverdue: Bool?

        var progressText: String {
            switch progressStatus {
            case "COMPLETED":
                return "Completed"
            case "IN_PROGRESS":
                return "\(progressPercent)% complete"
            default:
                return progressPercent > 0 ? "\(progressPercent)% complete" : "Not started"
            }
        }
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

    struct MobileDocumentsResponse: Decodable {
        let success: Bool
        let folders: [MobileDocumentFolder]
        let documents: [MobileDocument]
        let error: String?
    }

    struct MobileDocumentFolder: Decodable, Identifiable {
        let id: String
        let name: String
        let parentId: String?
    }

    struct MobileDocument: Decodable, Identifiable {
        let id: String
        let title: String
        let description: String?
        let category: String
        let folderId: String?
        let updatedAt: Date?
        let latestVersion: MobileDocumentVersion?
    }

    struct MobileDocumentVersion: Decodable, Identifiable {
        let id: String
        let version: Int
        let fileName: String
        let mimeType: String
        let sizeBytes: Int
        let publishedAt: Date?
        let assigned: Bool
        let acknowledgedAt: Date?
        let requiresAcknowledgement: Bool
    }

    private struct MobileDocumentAcknowledgementRequest: Encodable {
        let password: String
    }

    struct MobileDocumentAcknowledgementResponse: Decodable {
        let success: Bool
        let acknowledgedAt: Date?
        let error: String?
    }

    struct DispatchStatsResponse: Codable {
        let success: Bool?
        let stats: DispatchStats?
        let department: DispatchBucket?
        let station: DispatchBucket?
        let stations: ChiefStationStats?
        let lastUpdated: String?
        let sourceLabel: String?
        let message: String?
    }

    struct ChiefStationStats: Codable {
        let all: DispatchBucket?
        let station1: DispatchBucket?
        let station2: DispatchBucket?
        let station3: DispatchBucket?
        let station4: DispatchBucket?
        let station5: DispatchBucket?
    }

    struct DispatchStats: Codable {
        let department24h: Int?
        let department7d: Int?
        let department30d: Int?
        let departmentYtd: Int?
        let station24h: Int?
        let station7d: Int?
        let station30d: Int?
        let stationYtd: Int?
    }

    struct DispatchBucket: Codable {
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
        let other24h: Int?
        let other7d: Int?
        let other30d: Int?
        let otherYtd: Int?
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
    
    struct MobileUpcomingScheduleResponse: Decodable {
        let success: Bool
        let isScheduleTrackedUser: Bool
        let isWorkingNow: Bool
        let nextShift: MobileUpcomingShift?
        let error: String?
    }

    struct MobileUpcomingShift: Decodable {
        let date: String?
        let title: String
        let station: String?
        let timeRange: String
        let assignment: String?
        let name: String?
        let startAt: String?
        let endAt: String?
        let source: String
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

// One renewal per process; dashboard, push registration and CarPlay share the result.
actor MobileSessionRenewal {
    static let shared = MobileSessionRenewal()
    private var inFlight: Task<String, Error>?

    func renew(rejectedToken: String, baseURL: String) async throws -> String {
        if let current = KeychainService.shared.loadSession(), current.accessToken != rejectedToken {
            return current.accessToken
        }
        if let inFlight { return try await inFlight.value }
        let task = Task<String, Error> {
            let original = try KeychainService.shared.prepareSessionRefresh()
            guard let url = URL(string: baseURL + "/api/mobile/session/refresh") else { throw APIClient.APIError.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "refreshToken": original.refreshToken, "requestId": original.refreshRequestId!
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIClient.APIError.invalidResponse }
            if http.statusCode == 401 { throw APIClient.APIError.sessionExpired }
            guard http.statusCode == 200 else {
                throw APIClient.APIError.serverError(statusCode: http.statusCode, message: "Unable to renew your session. Please try again.")
            }
            struct RenewalResponse: Decodable { let token: String; let refreshToken: String; let sessionId: String }
            let result = try JSONDecoder().decode(RenewalResponse.self, from: data)
            guard !result.token.isEmpty, !result.refreshToken.isEmpty, result.sessionId == original.sessionId else {
                throw APIClient.APIError.invalidResponse
            }
            try KeychainService.shared.replaceSession(MobileSessionCredentials(accessToken: result.token,
                refreshToken: result.refreshToken, sessionId: result.sessionId), matching: original)
            return result.token
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

extension APIClient {
    struct RecoveryAccountLookupResponse: Decodable {
        let maskedEmail: String
        let lookupToken: String
    }
    struct RecoveryStartResponse: Decodable {
        let requestId: String
        let statusToken: String
        let matchCode: String
        let expiresAt: String
        let maskedEmail: String?
    }
    struct RecoveryStatusResponse: Decodable { let status: String; let expiresAt: String }
    struct AdminRecoveryRequest: Decodable, Identifiable {
        let id: String
        let matchCode: String
        let createdAt: Date
        let expiresAt: Date
        let user: RecoveryMember?
    }
    struct RecoveryMember: Decodable { let id: String; let name: String?; let email: String; let role: String }
}
