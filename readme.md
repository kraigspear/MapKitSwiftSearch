# MapKitSwiftSearch

A Swift-native wrapper around MapKit's location search functionality, providing a modern async/await interface with proper error handling and thread safety.

## Overview

MapKitSwiftSearch provides a safe and idiomatic Swift interface for location search operations using MapKit. While MapKit is powerful, its completion-based APIs can lead to complex callback structures. This library wraps those APIs to provide:

- ✅ Modern Swift concurrency with async/await
- ✅ Type-safe error handling
- ✅ Thread safety through @MainActor attribution
- ✅ Built-in request debouncing
- ✅ Sendable-compliant search results
- ✅ Cross-platform support (iOS and macOS)

## Architecture

```mermaid
classDiagram
    class LocationSearch {
        -MKLocalSearchCompleter searchCompleter
        -LocalSearchCompleterHandler handler
        +search(queryFragment: String) [LocalSearchCompletion]
        +placemark(for: LocalSearchCompletion) Placemark
    }
    
    class LocalSearchCompletion {
        +String title
        +String subTitle
        +HighlightRange? titleHighlightRange
        +HighlightRange? subtitleHighlightRange
    }
    
    class Placemark {
        +CLLocationCoordinate2D coordinate
        +String? name
        +String? thoroughfare
        +String? locality
    }
    
    LocationSearch ..> LocalSearchCompletion : creates
    LocationSearch ..> Placemark : creates
```

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/MapKitSwiftSearch.git", from: "1.0.0")
]
```

## Usage

### Basic Location Search

```swift
// Create a location search instance
let searcher = LocationSearch()

do {
    // Search for locations
    let results = try await searcher.search(queryFragment: "Coffee shops")
    
    // Process results
    for result in results {
        print("Found: \(result.title) - \(result.subTitle)")
    }
} catch {
    print("Search failed: \(error)")
}
```

### Getting Detailed Location Information

```swift
// Get detailed information for a search result
if let firstResult = results.first {
    if let placemark = try await searcher.placemark(for: firstResult) {
        print("Name: \(placemark.name ?? "")")
        print("Address: \(placemark.thoroughfare ?? "")")
        print("City: \(placemark.locality ?? "")")
        print("Coordinate: \(placemark.coordinate)")
    }
}
```

### Error Handling

```swift
do {
    let results = try await searcher.search(queryFragment: "Co")
} catch LocationSearchError.invalidSearchCriteria {
    // Handle insufficient search text
} catch LocationSearchError.debounce {
    // Handle debounced request
} catch LocationSearchError.mapKitError(let error) {
    // Handle MapKit specific errors
} catch {
    // Handle other errors
}
```

## Search Flow

```mermaid
sequenceDiagram
    participant App
    participant LocationSearch
    participant MKLocalSearchCompleter
    participant MapKit
    
    App->>LocationSearch: search("Coffee")
    activate LocationSearch
    LocationSearch->>LocationSearch: Debounce (300ms)
    LocationSearch->>MKLocalSearchCompleter: Set queryFragment
    activate MKLocalSearchCompleter
    MKLocalSearchCompleter->>MapKit: Search Request
    MapKit-->>MKLocalSearchCompleter: Results
    MKLocalSearchCompleter-->>LocationSearch: Completions
    deactivate MKLocalSearchCompleter
    LocationSearch-->>App: [LocalSearchCompletion]
    deactivate LocationSearch
    
    App->>LocationSearch: placemark(for: completion)
    activate LocationSearch
    LocationSearch->>MapKit: Detailed Search
    MapKit-->>LocationSearch: Place Details
    LocationSearch-->>App: Placemark
    deactivate LocationSearch
```

## Features

### Debouncing
The `LocationSearch` class includes built-in debouncing to prevent excessive API calls. This is particularly useful in search-as-you-type scenarios:

```swift
// Customize debounce delay (default is 300ms)
let searcher = LocationSearch(debounceSearchDelay: .milliseconds(500))
```

### Cross-Platform Text Highlighting
The library provides platform-specific highlighting for search results:

```swift
// iOS
let attributedTitle = searchResult.highlightedTitle(
    foregroundColor: .lightGray,
    highlightColor: .white
)

// macOS
let attributedSubtitle = searchResult.highlightedSubTitle(
    foregroundColor: .lightGray,
    highlightColor: .white
)
```

## Requirements
- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## License
This project is licensed under the MIT License - see the LICENSE file for details.