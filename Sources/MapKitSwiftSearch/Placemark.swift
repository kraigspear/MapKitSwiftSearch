//
//  Placemark.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/27/24.
//

import MapKit

/// A structure that represents a geographic location with associated address information.
///
/// `Placemark` provides a lightweight wrapper around `MKPlacemark` that conforms to `Sendable`,
/// making it safe to pass between concurrent contexts. It stores location coordinates and address
/// components such as street address, city, state, and country.
///
/// Example of creating a Placemark from an MKPlacemark:
/// ```swift
/// let mkPlacemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDict)
/// let placemark = Placemark(placemark: mkPlacemark)
/// ```
public struct Placemark: Sendable, Equatable, Hashable {
    /// The geographic coordinates of the placemark.
    public let coordinate: CLLocationCoordinate2D

    /// The name of the placemark, if any.
    ///
    /// This might represent a point of interest or landmark name.
    public let name: String?

    /// The street name of the address.
    public let thoroughfare: String?

    /// The building number or unit number of the address.
    public let subThoroughfare: String?

    /// The city name of the address.
    public let locality: String?

    /// The neighborhood or district within the city.
    public let subLocality: String?

    /// The state or province of the address.
    public let administrativeArea: String?

    /// The county within the state.
    public let subAdministrativeArea: String?

    /// The postal code (ZIP code in the United States) of the address.
    public let postalCode: String?

    /// The ISO country code of the address.
    ///
    /// This represents the two-letter ISO 3166-1 country code.
    public let countryCode: String?

    /// The full name of the country.
    public let countryName: String?

    /// Creates a new placemark from an `MKPlacemark` instance.
    ///
    /// This initializer copies all relevant address and location data from the provided
    /// `MKPlacemark` into a new `Placemark` instance.
    ///
    /// - Parameter placemark: The `MKPlacemark` instance to copy data from.
    public init(placemark: MKPlacemark) {
        coordinate = placemark.coordinate
        name = placemark.name
        thoroughfare = placemark.thoroughfare
        subThoroughfare = placemark.subThoroughfare
        locality = placemark.locality
        subLocality = placemark.subLocality
        administrativeArea = placemark.administrativeArea
        subAdministrativeArea = placemark.subAdministrativeArea
        postalCode = placemark.postalCode
        countryCode = placemark.countryCode
        countryName = placemark.country
    }

    /// Converts this placemark back to an `MKPlacemark` instance.
    ///
    /// This method creates a new `MKPlacemark` with all the address components
    /// and coordinate information from this `Placemark`.
    ///
    /// - Returns: A new `MKPlacemark` instance containing the same location and address information.
    public func toMKPlacemark() -> MKPlacemark {
        MKPlacemark(
            coordinate: coordinate,
            addressDictionary: [
                "name": name as Any,
                "thoroughfare": thoroughfare as Any,
                "subThoroughfare": subThoroughfare as Any,
                "locality": locality as Any,
                "subLocality": subLocality as Any,
                "administrativeArea": administrativeArea as Any,
                "subAdministrativeArea": subAdministrativeArea as Any,
                "postalCode": postalCode as Any,
                "countryCode": countryCode as Any,
                "country": countryName as Any,
            ],
        )
    }

    // MARK: - Equatable

    public static func == (lhs: Placemark, rhs: Placemark) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.name == rhs.name &&
            lhs.thoroughfare == rhs.thoroughfare &&
            lhs.subThoroughfare == rhs.subThoroughfare &&
            lhs.locality == rhs.locality &&
            lhs.subLocality == rhs.subLocality &&
            lhs.administrativeArea == rhs.administrativeArea &&
            lhs.subAdministrativeArea == rhs.subAdministrativeArea &&
            lhs.postalCode == rhs.postalCode &&
            lhs.countryCode == rhs.countryCode &&
            lhs.countryName == rhs.countryName
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(name)
        hasher.combine(thoroughfare)
        hasher.combine(subThoroughfare)
        hasher.combine(locality)
        hasher.combine(subLocality)
        hasher.combine(administrativeArea)
        hasher.combine(subAdministrativeArea)
        hasher.combine(postalCode)
        hasher.combine(countryCode)
        hasher.combine(countryName)
    }
}
