# Resolve through the boxed MapKit completion

Amends ADR 0002.

## Context

ADR 0002's snapshot dropped the `MKLocalSearchCompletion` MapKit returned, so `placemark(for:)` resolved a completion by running a new text search for its title and subtitle and taking the first map item. A probe on 2026-10-15 (macOS 27.2 and iOS 26.5, 56 pairs, Detroit area) compared that with `MKLocalSearch.Request(completion:)`:

- Cities and addresses resolved to the same place.
- Points of interest landed within 68 m, but sometimes at a different branch or under another name ("Grand Rapids Airport" became "Gerald R. Ford International Airport").
- "Search Nearby" category completions failed with `placemarkNotFound` 9 times out of 11, and once resolved 11,256 km away: "Pizza Restaurants" became a restaurant in Rawalpindi. The completion request always resolved them, to the nearest branch.

## Decision

`LocalSearchCompletion` keeps MapKit's completion in a private box, and `placemark(for:)` resolves it with `MKLocalSearch.Request(completion:)`.

- The box is `@unchecked Sendable`. Sharing it is safe because MapKit never mutates a completion after delivering it, and the package reads it only on the main actor, through `LocationSearch`.
- The box stays out of `==`, `hash(into:)`, and `id`: two snapshots with the same fields are the same completion to a caller.
- The public interface still holds no MapKit type, as ADR 0002 decided. Only the internal accessor opens the box.
- A completion with no MapKit completion behind it, which only the internal memberwise initializer builds, throws `LocationSearchError.mapKitError` with `.placemarkNotFound`.
- Cancelling the caller's task cancels the `MKLocalSearch`. Calls don't supersede each other; a caller that wants only the latest tap cancels the earlier call's task.

## Consequences

- A tapped completion resolves to the place MapKit suggested, including "Search Nearby" completions.
- ADR 0002 rejected `@unchecked Sendable` for public results. This box is the one exception, and it stays private, so no caller relies on MapKit's undocumented thread safety.
- Tests reach the resolution through `LocalSearchProtocol`, which returns map items rather than `MKLocalSearch.Response`, because tests can't build a response.
