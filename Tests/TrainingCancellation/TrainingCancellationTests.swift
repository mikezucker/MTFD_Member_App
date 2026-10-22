import Foundation
@main struct TrainingCancellationTests {
    static func main() {
        let cancellations: [Error] = [CancellationError(), URLError(.cancelled), APIClient.APIError.networkError(URLError(.cancelled))]
        for error in cancellations { assert(APIClient.isRequestCancellation(error), "Cancellation should not become a training failure") }
        let failures: [Error] = [URLError(.notConnectedToInternet), APIClient.APIError.networkError(URLError(.timedOut)), APIClient.APIError.serverError(statusCode: 500, message: nil), APIClient.APIError.sessionExpired, APIClient.APIError.decodingError("Missing field")]
        for error in failures { assert(!APIClient.isRequestCancellation(error), "Real errors must remain visible for retry") }
        print("PASS: raw, task and wrapped cancellations recognized; offline, timeout, server, authentication and decoding failures remain visible")
    }
}
