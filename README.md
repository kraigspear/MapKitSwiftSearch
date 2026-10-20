# MapKitSwiftSearch

[![Swift 6.4](https://img.shields.io/badge/Swift-6.4-F05138.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2026%20%7C%20macOS%2026-lightgrey.svg)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Async/await location search for iOS and macOS, built on MapKit's `MKLocalSearchCompleter` and `MKLocalSearch`.

## Overview

MapKit's search completer reports results through a delegate, which makes search-as-you-type awkward to write with Swift concurrency. MapKitSwiftSearch wraps it in two async calls: `search(queryFragment:)` returns completions as the user types, and `placemark(for:)` resolves one completion to a coordinate and address. Results are `Sendable` value types that don't expose MapKit objects, so they cross isolation boundaries.

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

The examples below follow `main`. From 0.3.0, `placemark(for:)` returns a `Placemark`; in 0.2.x and earlier it returns `Placemark?`, so unwrap its result there.

## Quick Start

`LocationSearch` is `@MainActor`; call it from the main actor.

```swift
import MapKitSwiftSearch

let locationSearch = LocationSearch()

let completions = try await locationSearch.search(queryFragment: "Apple Park")
if let first = completions.first {
    let placemark = try await locationSearch.placemark(for: first)
    print(placemark.name ?? "", placemark.coordinate)
}
```

## Usage

### Search as the user types

Call `search(queryFragment:)` on every change to the text. MapKit is asked only after the debounce delay, and only the latest call returns completions: a newer call supersedes an older one at once, and the older one throws `CancellationError`. Ignore it and keep the current results. Any other error is a MapKit failure, `LocationSearchError.mapKitError(_:)` for an `MKError`. MapKit throttles bursts of searches with `.loadingThrottled`, which clears by itself, so keep the current results for that too.

```swift
import MapKit
import MapKitSwiftSearch
import Observation

@MainActor
@Observable
final class SearchModel {
    private let locationSearch = LocationSearch()
    private(set) var completions: [LocalSearchCompletion] = []
    private(set) var searchError: (any Error)?

    func queryChanged(to query: String) async {
        do {
            completions = try await locationSearch.search(queryFragment: query)
            searchError = nil
        } catch is CancellationError {
            // A newer query superseded this one: keep the current completions
        } catch let LocationSearchError.mapKitError(error) where error.code == .loadingThrottled {
            // MapKit throttles bursts of searches and recovers by itself: keep the current completions
        } catch {
            searchError = error
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

An empty query, or one shorter than the minimum, returns no completions straight away, without the debounce.

### Resolve a placemark

`placemark(for:)` runs an `MKLocalSearch` for the completion and returns a `Placemark`:

```swift
let placemark = try await locationSearch.placemark(for: completion)
print(placemark.coordinate)
print(placemark.name ?? "")
print(placemark.fullAddress ?? "")
print(placemark.shortAddress ?? "")
```

A MapKit failure throws `LocationSearchError.mapKitError(_:)` with the underlying `MKError`, which is `.placemarkNotFound` when MapKit finds no place. Cancelling the calling task throws `CancellationError`.

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
