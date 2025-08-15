# Placemark API Documentation

## Overview

`Placemark` is a `Sendable` wrapper around MapKit's `MKPlacemark` that provides thread-safe access to geographic location data with associated address information. It serves as a bridge between MapKit's reference-type placemarks and Swift's modern concurrency model.

## Structure Declaration

```swift
public struct Placemark: Sendable, Equatable, Hashable
```

### Protocol Conformances

#### Sendable
- **Purpose**: Safe to pass between concurrent contexts without data races
- **Benefit**: Enables use in async/await operations and actor-isolated code
- **Implementation**: All properties are value types or immutable references

#### Equatable
- **Use Case**: Comparison of locations for deduplication and change detection
- **Implementation**: Compares all address components and coordinates
- **Precision**: Uses exact coordinate matching (no tolerance for floating-point precision)

#### Hashable
- **Use Case**: Efficient storage in `Set` collections and as `Dictionary` keys
- **Implementation**: Combines all property values for hash calculation
- **Performance**: Optimized for typical address data patterns

## Properties

### Geographic Properties

```swift
public let coordinate: CLLocationCoordinate2D
```

#### coordinate: CLLocationCoordinate2D
- **Type**: Core Location coordinate structure
- **Components**: `latitude` and `longitude` in decimal degrees
- **Precision**: Full double-precision accuracy from MapKit
- **Validation**: MapKit ensures coordinates are valid before creating MKPlacemark

### Address Components

The address properties follow the standard Address Book framework structure used throughout Apple's platforms:

```swift
public let name: String?
public let thoroughfare: String?          // Street name
public let subThoroughfare: String?       // Building/unit number  
public let locality: String?              // City
public let subLocality: String?           // Neighborhood/district
public let administrativeArea: String?     // State/province
public let subAdministrativeArea: String? // County
public let postalCode: String?            // ZIP/postal code
public let countryCode: String?           // ISO country code
public let countryName: String?           // Full country name
```

#### Why Optional Properties?

All address components are optional because:
- **Real-World Data**: Many locations have incomplete address information
- **Global Compatibility**: Address formats vary significantly between countries
- **Data Source Limitations**: MapKit may not have complete information for all locations
- **Rural Locations**: Remote areas often lack formal street addresses

#### Property Details

##### name: String?
- **Content**: Point of interest or landmark name
- **Examples**: "Starbucks", "Central Park", "San Francisco International Airport"
- **Nil Case**: Generic locations without specific names
- **Usage**: Primary display name for the location

##### thoroughfare: String?
- **Content**: Street name without building number
- **Examples**: "Main Street", "Broadway", "Highway 101"
- **International**: May include street type suffixes based on locale
- **Nil Case**: Locations without formal street addresses

##### subThoroughfare: String?
- **Content**: Building number, unit number, or suite identifier
- **Examples**: "123", "456A", "Suite 200"
- **Format**: Usually numeric but can contain letters for units
- **Nil Case**: Locations without specific building identifiers

##### locality: String?
- **Content**: City or town name
- **Examples**: "New York", "San Francisco", "London"
- **Scope**: Primary municipal area containing the location
- **Nil Case**: Very rural or unincorporated areas

##### subLocality: String?
- **Content**: Neighborhood, district, or borough within a city
- **Examples**: "Manhattan", "Mission District", "Downtown"
- **Usage**: Provides more specific location context within large cities
- **Nil Case**: Locations without defined neighborhood boundaries

##### administrativeArea: String?
- **Content**: State, province, or primary administrative division
- **Examples**: "California", "New York", "Ontario"
- **Format**: May be full name or abbreviation depending on data source
- **Nil Case**: Countries without state-level divisions

##### subAdministrativeArea: String?
- **Content**: County or secondary administrative division
- **Examples**: "Los Angeles County", "King County"
- **Usage**: Intermediate level between city and state
- **Nil Case**: Areas without county-level organization

##### postalCode: String?
- **Content**: ZIP code, postal code, or equivalent
- **Examples**: "90210", "SW1A 1AA", "75001"
- **Format**: Varies by country postal system
- **Nil Case**: Rural areas without postal service

##### countryCode: String?
- **Content**: Two-letter ISO 3166-1 country code
- **Examples**: "US", "CA", "GB", "JP"
- **Standard**: International standard for country identification
- **Nil Case**: Should rarely be nil for valid locations

##### countryName: String?
- **Content**: Full country name in current locale
- **Examples**: "United States", "Canada", "United Kingdom"
- **Localization**: Name appears in user's preferred language
- **Nil Case**: Should rarely be nil for valid locations

## Initialization

### Primary Initializer

```swift
public init(placemark: MKPlacemark)
```

#### Purpose
Creates a new `Placemark` instance by copying all relevant data from an `MKPlacemark`.

#### Implementation
```swift
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
    countryName = placemark.country  // Note: .country vs .countryName
}
```

#### Why Copy Rather Than Wrap?

The design copies data rather than holding a reference to `MKPlacemark` because:
- **Sendable Compliance**: Reference types cannot be `Sendable` without careful synchronization
- **Lifecycle Independence**: `Placemark` instances can outlive the original `MKPlacemark`
- **Memory Efficiency**: Avoids keeping entire `MKPlacemark` in memory for simple address data
- **Thread Safety**: No shared mutable state between concurrent operations

## Public Methods

### toMKPlacemark()

```swift
public func toMKPlacemark() -> MKPlacemark
```

#### Purpose
Converts the `Placemark` back to an `MKPlacemark` for use with MapKit APIs that require the original type.

#### Implementation
```swift
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
        ]
    )
}
```

#### Why Address Dictionary?

The method uses `addressDictionary` because:
- **Completeness**: Preserves all address components in a single initialization
- **Compatibility**: Matches the format used internally by MapKit
- **Flexibility**: Handles optional values gracefully with `as Any` casting
- **Accuracy**: Ensures the created `MKPlacemark` has identical data

#### Usage Examples

```swift
// Convert back to MKPlacemark for map annotations
let placemark = try await locationSearch.placemark(for: completion)
if let place = placemark {
    let mkPlacemark = place.toMKPlacemark()
    let annotation = MKPointAnnotation()
    annotation.coordinate = mkPlacemark.coordinate
    annotation.title = mkPlacemark.name
    mapView.addAnnotation(annotation)
}

// Use with MKLocalSearch.Request
let mkPlacemark = placemark.toMKPlacemark()
let request = MKLocalSearch.Request()
request.region = MKCoordinateRegion(center: mkPlacemark.coordinate, 
                                   latitudinalMeters: 1000, 
                                   longitudinalMeters: 1000)
```

## Equality and Hashing Implementation

### Equality Comparison

```swift
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
```

#### Design Decisions

1. **Exact Coordinate Matching**: Uses exact equality rather than tolerance-based comparison
   - **Rationale**: Preserves precision from MapKit's data
   - **Trade-off**: May consider very close coordinates as different
   - **Use Case**: Ensures identical placemarks are truly identical

2. **All Properties Included**: Compares every address component
   - **Rationale**: Two locations with same coordinates but different addresses are different places
   - **Example**: Different apartments in the same building
   - **Completeness**: Ensures comprehensive equality semantics

### Hash Implementation

```swift
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
```

#### Why Include All Properties?

- **Consistency**: Hash implementation must match equality semantics
- **Distribution**: Using all properties provides better hash distribution
- **Collision Avoidance**: Reduces hash collisions for similar locations
- **Performance**: Swift's `Hasher` efficiently combines multiple values

## Common Usage Patterns

### Address Formatting

```swift
extension Placemark {
    /// Creates a formatted address string from available components
    var formattedAddress: String {
        let components = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            postalCode
        ].compactMap { $0 }
        
        return components.joined(separator: ", ")
    }
    
    /// Creates a single-line address suitable for display
    var displayAddress: String {
        if let name = name {
            return formattedAddress.isEmpty ? name : "\(name), \(formattedAddress)"
        }
        return formattedAddress
    }
}
```

### Distance Calculations

```swift
extension Placemark {
    /// Calculates distance to another placemark
    func distance(to other: Placemark) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coordinate.latitude, 
                                  longitude: coordinate.longitude)
        let location2 = CLLocation(latitude: other.coordinate.latitude, 
                                  longitude: other.coordinate.longitude)
        return location1.distance(from: location2)
    }
    
    /// Checks if placemark is within specified distance of another
    func isWithin(_ distance: CLLocationDistance, of other: Placemark) -> Bool {
        return self.distance(to: other) <= distance
    }
}
```

### Filtering and Sorting

```swift
// Filter placemarks by country
let usPlacemarks = placemarks.filter { $0.countryCode == "US" }

// Sort by city name
let sortedByCity = placemarks.sorted { 
    ($0.locality ?? "") < ($1.locality ?? "")
}

// Group by state
let groupedByState = Dictionary(grouping: placemarks) { placemark in
    placemark.administrativeArea ?? "Unknown"
}

// Find unique cities
let uniqueCities = Set(placemarks.compactMap { $0.locality })
```

### Coordinate Validation

```swift
extension Placemark {
    /// Checks if the coordinate represents a valid location
    var hasValidCoordinate: Bool {
        CLLocationCoordinate2DIsValid(coordinate)
    }
    
    /// Checks if the placemark has minimal address information
    var hasAddressInfo: Bool {
        name != nil || thoroughfare != nil || locality != nil
    }
}
```

## Performance Considerations

### Memory Usage
- **Value Semantics**: Automatic memory management with no reference cycles
- **String Storage**: Efficient storage using Swift's string optimization
- **Copy Overhead**: Minimal due to Swift's copy-on-write string implementation

### Collection Performance
- **Hashing**: Efficient for `Set` and `Dictionary` operations
- **Equality**: Fast comparison optimized for early termination
- **Sorting**: Predictable performance for coordinate-based or address-based sorting

### Thread Safety
- **Immutable**: All properties are immutable after initialization
- **Sendable**: Safe to pass between concurrent contexts
- **No Synchronization**: No locks or atomic operations required

## Best Practices

### Data Validation
```swift
func validatePlacemark(_ placemark: Placemark) -> Bool {
    guard placemark.hasValidCoordinate else {
        print("Invalid coordinates: \(placemark.coordinate)")
        return false
    }
    
    guard placemark.hasAddressInfo else {
        print("No address information available")
        return false
    }
    
    return true
}
```

### Error Handling
```swift
func safeDisplayName(for placemark: Placemark) -> String {
    if let name = placemark.name, !name.isEmpty {
        return name
    }
    
    if let thoroughfare = placemark.thoroughfare {
        let number = placemark.subThoroughfare ?? ""
        return "\(number) \(thoroughfare)".trimmingCharacters(in: .whitespaces)
    }
    
    if let locality = placemark.locality {
        return locality
    }
    
    return "Unknown Location"
}
```

### Memory Management
```swift
// Avoid keeping large arrays of placemarks indefinitely
func processPlacemarks(_ placemarks: [Placemark]) {
    // Process in batches for large datasets
    let batchSize = 100
    for batch in placemarks.chunked(into: batchSize) {
        processBatch(batch)
    }
}

// Use lazy evaluation for expensive operations
let distanceSortedPlacemarks = placemarks.lazy
    .map { (placemark: $0, distance: currentLocation.distance(to: $0)) }
    .sorted { $0.distance < $1.distance }
    .map { $0.placemark }
```

This comprehensive documentation provides developers with everything they need to effectively use `Placemark` in their applications while understanding the design decisions that ensure thread safety, performance, and usability.