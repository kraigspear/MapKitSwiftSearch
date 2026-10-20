# ``MapKitSwiftSearch``

Async/await location search for iOS and macOS, built on MapKit's search completer.

## Overview

MapKit's search completer reports results through a delegate, which makes search-as-you-type awkward to write with Swift concurrency. ``LocationSearch`` wraps it in two async calls: ``LocationSearch/search(queryFragment:)`` returns completions as the user types, and ``LocationSearch/placemark(for:)`` resolves one completion to a coordinate and address. Results are `Sendable` value types that don't expose MapKit objects, so they cross isolation boundaries.

Requires iOS 26 or macOS 26, and Swift 6.4 (Xcode 27). Add the package with Swift Package Manager:

```swift
.package(url: "https://github.com/kraigspear/MapKitSwiftSearch.git", .upToNextMinor(from: "0.1.2"))
```

The package is pre-1.0, so a minor release can change the public API. `.upToNextMinor` takes patch releases and waits for you to opt in to the next minor.

The articles follow `main`. From 0.3.0, ``LocationSearch/placemark(for:)`` returns a ``Placemark``; in 0.2.x and earlier it returns `Placemark?`, so unwrap its result there.

## Topics

### Essentials

- <doc:GettingStarted>
- ``LocationSearch``

### Results

- ``LocalSearchCompletion``
- ``Placemark``

### Errors

- ``LocationSearchError``
