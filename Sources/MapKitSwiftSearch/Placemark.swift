import MapKit

/// A `Sendable` snapshot of a MapKit map item's location, address, and time zone.
public struct Placemark: Sendable, Equatable, Hashable {
    /// The geographic coordinates of the placemark.
    public let coordinate: CLLocationCoordinate2D

    /// The place's name, such as a business or landmark, if MapKit has one.
    public let name: String?

    /// The full formatted address string from `MKAddress.fullAddress`.
    public let fullAddress: String?

    /// The short formatted address string from `MKAddress.shortAddress`.
    public let shortAddress: String?

    /// The place's time zone from `MKMapItem.timeZone`, or `nil` when MapKit gives none.
    public let timeZone: TimeZone?

    /// Creates a placemark from a MapKit map item.
    public init(mapItem: MKMapItem) {
        coordinate = mapItem.location.coordinate
        name = mapItem.name
        fullAddress = mapItem.address?.fullAddress
        shortAddress = mapItem.address?.shortAddress
        timeZone = mapItem.timeZone
    }

    // MARK: - Equatable

    // Equatable and Hashable are written by hand because CLLocationCoordinate2D conforms to neither

    public static func == (lhs: Placemark, rhs: Placemark) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.name == rhs.name &&
            lhs.fullAddress == rhs.fullAddress &&
            lhs.shortAddress == rhs.shortAddress &&
            lhs.timeZone == rhs.timeZone
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(name)
        hasher.combine(fullAddress)
        hasher.combine(shortAddress)
        hasher.combine(timeZone)
    }
}
