# Sendable snapshots instead of MapKit types

## Context

MapKit's `MKLocalSearchCompletion` and `MKMapItem` are `NSObject` subclasses with no `Sendable` annotation (macOS 27 SDK). Callers keep search results in view models and pass them across isolation domains. Under Swift 6 strict concurrency, a MapKit object can't make that crossing.

## Decision

Public results are value types that copy what callers need out of MapKit at the boundary and declare `Sendable` explicitly. `LocalSearchCompletion.init(_:)` copies the title, the subtitle, and every highlight (ADR 0008). `Placemark.init(mapItem:)` copies the coordinate, name, full and short address, and time zone. `Placemark.init(mapItem:)` is the only public API that touches a MapKit object.

Returning MapKit objects was rejected. So was wrapping them as `@unchecked Sendable` in the public interface, which would promise a thread safety MapKit doesn't document. ADR 0007 keeps one privately, opened only on the main actor.

## Consequences

- The snapshot first dropped MapKit's completion, so `placemark(for:)` ran a new text search for the completion's title and subtitle, which got "Search Nearby" completions wrong. ADR 0007 keeps the completion in a private box and resolves it directly.
- Callers get only the fields copied. Adding one, as KLI-239 added the time zone, changes the public API and needs a minor release before 1.0.
- A snapshot has no MapKit identity. `LocalSearchCompletion.id` is built from the title and subtitle, so two completions with the same text share an `id`.
