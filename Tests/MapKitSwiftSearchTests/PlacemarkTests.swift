import Foundation
import MapKit
import Testing
@testable import MapKitSwiftSearch

struct PlacemarkTests {
    @Test("Placemark keeps the map item's time zone")
    func placemarkKeepsMapItemTimeZone() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))

        let placemark = Placemark(mapItem: makeMapItem(timeZone: tokyo))

        #expect(placemark.timeZone == tokyo)
    }

    @Test("Placemark has no time zone when the map item has none")
    func placemarkTimeZoneIsNilWithoutMapItemTimeZone() {
        let placemark = Placemark(mapItem: makeMapItem(timeZone: nil))

        #expect(placemark.timeZone == nil)
    }

    @Test("Placemarks that differ only in time zone are not equal")
    func placemarksDifferingOnlyInTimeZoneAreNotEqual() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))

        let inTokyo = Placemark(mapItem: makeMapItem(timeZone: tokyo))
        let inSeoul = Placemark(mapItem: makeMapItem(timeZone: seoul))
        let withoutZone = Placemark(mapItem: makeMapItem(timeZone: nil))

        #expect(inTokyo != inSeoul)
        #expect(inTokyo != withoutZone)
        #expect(inTokyo == Placemark(mapItem: makeMapItem(timeZone: tokyo)))
    }

    private func makeMapItem(timeZone: TimeZone?) -> MKMapItem {
        let mapItem = MKMapItem(location: CLLocation(latitude: 35.6762, longitude: 139.6503), address: nil)
        mapItem.name = "Tokyo"
        mapItem.timeZone = timeZone
        return mapItem
    }
}
