# ``MapKitSwiftSearch``

A modern Swift interface for location search operations using MapKit with async/await support and structured concurrency.

## Overview

MapKitSwiftSearch provides a clean, type-safe wrapper around MapKit's `MKLocalSearchCompleter` that embraces modern Swift patterns. It offers async/await APIs, structured concurrency, built-in debouncing, and platform-specific UI helpers for both iOS and macOS.

### Key Features

- **Modern Swift**: Uses async/await and structured concurrency
- **Type Safety**: Swift-native error types and Sendable-compliant results
- **Performance**: Built-in debouncing and intelligent search management
- **Cross-Platform**: Works on both iOS and macOS with platform-specific UI helpers
- **Thread Safety**: All operations are `@MainActor` attributed for UI safety

## Quick Start

```swift
import MapKitSwiftSearch

let locationSearch = LocationSearch()

do {
    let results = try await locationSearch.search(queryFragment: "Coffee shops")
    for result in results {
        print("\(result.title) - \(result.subTitle)")
    }
} catch {
    print("Search failed: \(error)")
}
```

## Topics

### Getting Started

- <doc:GettingStarted>

### Core Functionality

- <doc:BasicSearchFunctionality>
- <doc:WorkingWithSearchResults>
- <doc:ErrorHandling>

### Advanced Topics

- <doc:AdvancedUsage>
- <doc:PlatformDifferences>

### API Reference

- ``LocationSearch``
- ``LocalSearchCompletion``
- ``Placemark``
- ``HighlightRange``
- ``LocationSearchError``

## Requirements

- iOS 18.0+ or macOS 15.0+
- Swift 6.2+
- Xcode 16.0+

## Installation

Add MapKitSwiftSearch to your project using Swift Package Manager:

```
https://github.com/yourusername/MapKitSwiftSearch
```

## See Also

- [MapKit Documentation](https://developer.apple.com/documentation/mapkit)
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)