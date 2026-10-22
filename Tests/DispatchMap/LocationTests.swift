import Foundation
import MapKit
import CoreLocation

private final class FixturePlacemark: CLPlacemark {
    let point: CLLocation
    let street: String?
    let number: String?
    init(latitude: Double = 40.815, longitude: Double = -74.52, street: String? = "Test Road", number: String? = "123") {
        point = CLLocation(latitude: latitude, longitude: longitude); self.street = street; self.number = number
        super.init(placemark: MKPlacemark(coordinate: point.coordinate))
    }
    required init?(coder: NSCoder) { fatalError("Unused fixture coder") }
    override var location: CLLocation? { point }
    override var thoroughfare: String? { street }
    override var subThoroughfare: String? { number }
    override var name: String? { street }
    override var administrativeArea: String? { "NJ" }
    override var locality: String? { "Morristown" }
}
private enum FixtureError: Error { case unavailable }
@main struct DispatchMapTests {
    @MainActor static func main() async {
        var lookups = 0
        let supplied = await DispatchIncidentLocationResolver.resolve(address: "123 Test Rd", latitude: 40.82, longitude: -74.55, geocode: { _ in lookups += 1; return [] }, search: { _ in lookups += 1; return [] })
        assert(supplied?.latitude == 40.82 && supplied?.longitude == -74.55 && lookups == 0, "Dispatch coordinates must take priority")
        let geocoded = await DispatchIncidentLocationResolver.resolve(address: "123 Test Rd", geocode: { query in assert(query.contains("Morristown")); return [FixturePlacemark()] }, search: { _ in lookups += 1; return [] })
        assert(geocoded?.latitude == 40.815 && lookups == 0, "A resolved address must not be independently searched again for its fallback map")
        let searched = await DispatchIncidentLocationResolver.resolve(address: "123 Test Rd", geocode: { _ in throw FixtureError.unavailable }, search: { _ in lookups += 1; return [FixturePlacemark()] })
        assert(searched?.longitude == -74.52 && lookups == 1, "Search recovers a failed geocoder")
        let centroid = FixturePlacemark(latitude: 40.7968, longitude: -74.4815, street: nil, number: nil)
        let recovered = await DispatchIncidentLocationResolver.resolve(address: "123 Test Rd", geocode: { _ in [centroid] }, search: { _ in [FixturePlacemark()] })
        assert(recovered?.latitude == 40.815, "A city centroid must not stand in for a numbered address")
        let unresolved = await DispatchIncidentLocationResolver.resolve(address: "123 Test Rd", latitude: 0, longitude: 0, geocode: { _ in [centroid, FixturePlacemark(number: "124"), FixturePlacemark(street: "Other Road")] }, search: { _ in [] })
        assert(unresolved == nil, "Unresolved calls must not show a downtown incident pin")
        let outside = await DispatchIncidentLocationResolver.resolve(address: "123 Test Rd", latitude: 41, longitude: -74, geocode: { _ in [FixturePlacemark(latitude: 41)] }, search: { _ in [] })
        assert(outside == nil, "Existing Morris-area guard must remain enforced")
        let unknown = await DispatchIncidentLocationResolver.resolve(address: "Unknown Location", geocode: { _ in assertionFailure("No unknown-address lookup"); return [] }, search: { _ in [] })
        assert(unknown == nil)
        let cancelled = Task { @MainActor in await DispatchIncidentLocationResolver.resolve(address: "123 Test Rd", geocode: { _ in [] }, search: { _ in [FixturePlacemark()] }) }
        cancelled.cancel(); let cancelledValue = await cancelled.value; assert(cancelledValue == nil, "Cancelled calls cannot overwrite the next incident")
        print("Dispatch map regression tests passed: coordinates first, shared geocode, search recovery, centroid/wrong-address rejection, no fabricated fallback, cancellation.")
    }
}
