# Consumers own their ports

## Context

Consumers own their ports. Klimate's `LocationSearchViewDependencies` covers search and resolve, GPS, and location-permission state in one protocol, so its tests and previews replace all of them together. A port inside the package would have only one real adapter, `LocationSearch`, and it couldn't replace the consumer's own port: Klimate would still need `LocationSearchViewDependencies` for GPS and permission state.

What a consumer lacks is a way to build the values its port returns. Klimate's `LocationSearchViewAlertTests` builds a completion through the internal `LocalSearchCompletion(MKLocalSearchCompletion())`, reached with `@testable import`.

## Decision

The package exposes values that can be built: `LocalSearchCompletion`'s memberwise initializer, which KLI-257 makes public, and `Placemark(mapItem:)`. A consumer's fake of its own port returns them. The package does not ship a `LocationSearch` protocol or a fake that returns canned results.

A package-level protocol and fake was suggested in the 2026-10-15 architecture review and rejected for the reasons above.

## Consequences

- Each consumer writes the fake for its own port. The package's tests keep their internal fakes, passed through `LocationSearch`'s internal initializer.
- `LocationSearch` stays a concrete `final class`. A consumer wraps it in its port's live adapter, as Klimate's `LiveLocationSearchViewDependencies` does.
- A public initializer for a value is public API. Adding one needs a minor release before 1.0, and changing it later breaks consumers' fakes.
