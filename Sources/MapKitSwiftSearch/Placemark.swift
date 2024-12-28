//
//  Placemark.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/27/24.
//

import MapKit

public struct Placemark: Sendable, Equatable, Hashable {
    public let coordinate: CLLocationCoordinate2D  // Non-optional, matches MKPlacemark
    public let name: String?
    public let thoroughfare: String?          // Street address
    public let subThoroughfare: String?       // Building number
    public let locality: String?              // City
    public let subLocality: String?           // Neighborhood
    public let administrativeArea: String?    // State
    public let subAdministrativeArea: String? // County
    public let postalCode: String?
    public let countryCode: String?
    public let countryName: String?
    
    public init(placemark: MKPlacemark) {
        self.coordinate = placemark.coordinate  // This is guaranteed to exist
        self.name = placemark.name
        self.thoroughfare = placemark.thoroughfare
        self.subThoroughfare = placemark.subThoroughfare
        self.locality = placemark.locality
        self.subLocality = placemark.subLocality
        self.administrativeArea = placemark.administrativeArea
        self.subAdministrativeArea = placemark.subAdministrativeArea
        self.postalCode = placemark.postalCode
        self.countryCode = placemark.countryCode
        self.countryName = placemark.country
    }
    
    // Convert back to MKPlacemark if needed
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
                "country": countryName as Any
            ]
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
