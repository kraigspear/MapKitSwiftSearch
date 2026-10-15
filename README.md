# MapKitSwiftSearch

[![Swift 6.4](https://img.shields.io/badge/Swift-6.4-F05138.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2026%20%7C%20macOS%2026-lightgrey.svg)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Async/await location search for iOS and macOS, built on MapKit's `MKLocalSearchCompleter` and `MKLocalSearch`.

## Overview

MapKit's search completer reports results through a delegate, which makes search-as-you-type awkward to write with Swift concurrency. MapKitSwiftSearch wraps it in two async calls: `search(queryFragment:)` returns completions as the user types, and `placemark(for:)` resolves one completion to a coordinate and address. Results are `Sendable` value types, so they cross isolation boundaries without carrying MapKit objects.

## Requirements

- iOS 26+ / macOS 26+
- Swift 6.4+ (Xcode 27+)

## Installation

### Swift Package Manager

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kraigspear/MapKitSwiftSearch.git", .upToNextMinor(from: "0.1.2")),
]
```

Then add the product to your target:

```swift
.target(
    name: "MyApp",
    dependencies: ["MapKitSwiftSearch"]
)
```

In Xcode, choose **File > Add Package Dependencies…** and enter the repository URL.

The package is pre-1.0, so a minor release can change the public API. `.upToNextMinor` takes patch releases and waits for you to opt in to the next minor.

## Quick Start

`LocationSearch` is `@MainActor`; call it from the main actor.

```swift
import MapKitSwiftSearch

let locationSearch = LocationSearch()

let completions = try await locationSearch.search(queryFragment: "Apple Park")
if let first = completions.first,
   let placemark = try await locationSearch.placemark(for: first) {
    print(placemark.name ?? "", placemark.coordinate)
}
```

## Usage

### Search as the user types

Call `search(queryFragment:)` on every change to the text. Each call waits out the debounce delay, and a newer call with a different query supersedes an older one. The superseded call throws `LocationSearchError.debounce`, or `CancellationError` if its MapKit search had already started. Treat both as "keep the current results," not as failures.

```swift
import MapKitSwiftSearch
import Observation

@MainActor
@Observable
final class SearchModel {
    private let locationSearch = LocationSearch()
    private(set) var completions: [LocalSearchCompletion] = []

    func queryChanged(to query: String) async {
        do {
            completions = try await locationSearch.search(queryFragment: query)
        } catch LocationSearchError.debounce, LocationSearchError.duplicateSearchCriteria {
            // Superseded by newer input, or the text didn't change
        } catch is CancellationError {
            // Superseded after the MapKit search started
        } catch {
            completions = []
        }
    }
}
```

### Configure debounce and minimum length

```swift
let locationSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 3, // default: 5
    debounceSearchDelay: .milliseconds(200) // default: 300 ms
)
```

A query shorter than the minimum throws `LocationSearchError.invalidSearchCriteria`. An empty query returns no completions. Repeating the previous query throws `LocationSearchError.duplicateSearchCriteria`, even when the query is empty.

### Resolve a placemark

`placemark(for:)` runs an `MKLocalSearch` for the completion and returns a `Placemark`:

```swift
if let placemark = try await locationSearch.placemark(for: completion) {
    print(placemark.coordinate)
    print(placemark.name ?? "")
    print(placemark.fullAddress ?? "")
    print(placemark.shortAddress ?? "")
}
```

A MapKit failure throws `LocationSearchError.mapKitError(_:)` with the underlying `MKError`.

### Highlight matched text

Each completion carries the first range MapKit matched in its title and in its subtitle. `highlightedTitle()` and `highlightedSubTitle()` return an `AttributedString` with the match drawn in a highlight color:

```swift
import MapKitSwiftSearch
import SwiftUI

struct CompletionRow: View {
    let completion: LocalSearchCompletion

    var body: some View {
        VStack(alignment: .leading) {
            Text(completion.highlightedTitle())
            Text(completion.highlightedSubTitle())
                .font(.caption)
        }
    }
}
```

The defaults, light gray with a white highlight, suit a dark background. Pass `foregroundColor:` and `highlightColor:` to change them; they take `UIColor` on iOS and `NSColor` on macOS.

## Documentation

API reference and a Getting Started guide live in the [DocC catalog](Sources/MapKitSwiftSearch/Documentation.docc). To browse them in Xcode, open the package and choose **Product > Build Documentation**. Design decisions, with the reasoning behind them, are recorded in [Docs/adr](Docs/adr).

## Development

```bash
swift build
swift test
swiftformat .
```

`TestApp/` is a SwiftUI demo app for trying search by hand. Repository conventions are in [AGENTS.md](AGENTS.md).

## License

MapKitSwiftSearch is available under the MIT license. See [LICENSE](LICENSE).
