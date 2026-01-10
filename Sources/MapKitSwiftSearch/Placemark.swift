import MapKit

/// A structure that represents a geographic location with associated address information.
///
/// `Placemark` provides a lightweight wrapper around `MKMapItem` that conforms to `Sendable`,
/// making it safe to pass between concurrent contexts. It stores location coordinates and
/// formatted address strings.
///
/// Example of creating a Placemark from an MKMapItem:
/// ```swift
/// let placemark = Placemark(mapItem: mapItem)
/// print("Location: \(placemark.name ?? "Unknown")")
/// print("Address: \(placemark.fullAddress ?? "No address")")
/// ```
public struct Placemark: Sendable, Equatable, Hashable {
    /// The geographic coordinates of the placemark.
    public let coordinate: CLLocationCoordinate2D

    /// The name of the placemark, if any.
    ///
    /// This might represent a point of interest or landmark name.
    public let name: String?

    /// The full formatted address string from `MKAddress.fullAddress`.
    public let fullAddress: String?

    /// The short formatted address string from `MKAddress.shortAddress`.
    public let shortAddress: String?

    /// Creates a new placemark from an `MKMapItem` instance.
    ///
    /// This initializer extracts location and address data from the provided
    /// `MKMapItem` using the `location` and `address` properties.
    ///
    /// - Parameter mapItem: The `MKMapItem` instance to extract data from.
    public init(mapItem: MKMapItem) {
        coordinate = mapItem.location.coordinate
        name = mapItem.name
        fullAddress = mapItem.address?.fullAddress
        shortAddress = mapItem.address?.shortAddress
    }

    // MARK: - Equatable

    public static func == (lhs: Placemark, rhs: Placemark) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.name == rhs.name &&
            lhs.fullAddress == rhs.fullAddress &&
            lhs.shortAddress == rhs.shortAddress
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(name)
        hasher.combine(fullAddress)
        hasher.combine(shortAddress)
    }
}
