# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Before changing public API or documentation, read [AGENTS.md](AGENTS.md): it says where each documentation fact lives and how API changes are released. Its rules apply here too.

## Project Overview

MapKitSwiftSearch wraps MapKit's location search in async/await. It ships one library product, `MapKitSwiftSearch`, and Klimate uses it for its location search.

- `LocationSearch` (`@MainActor`): `search(queryFragment:)` returns debounced completions from `MKLocalSearchCompleter`; `placemark(for:)` resolves one completion through `MKLocalSearch`.
- `LocalSearchCompletion`: a `Sendable` snapshot of one completion, with its highlight ranges. Platform-specific highlighting lives in `Sources/MapKitSwiftSearch/PlatformSpecific/`.
- `Placemark`: a `Sendable` snapshot of an `MKMapItem`, so callers never hold MapKit types across isolation boundaries.
- `HighlightRange`, `LocationSearchError`: supporting types.

`TestApp/` is a demo app for trying the search by hand. It is not part of the package build.

## Build Commands

```bash
# Build the package
swift build

# Run tests (macOS host; the package supports iOS 26 and macOS 26)
swift test

# Run a specific test
swift test --filter LocationSearchUnitTests

# Format code using SwiftFormat (config in .swiftformat)
swiftformat .

# Detect unused code with Periphery
./scan.sh

# Compile every Swift snippet in README.md against the package
scripts/check-readme-snippets.sh
```

CI (`.github/workflows/ci.yml`) runs build, test, and the README snippet check on every PR and push to `main`.

## Conventions

- Swift 6.4 tools. Every target enables `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`. Use Swift concurrency, not GCD.
- Public value types declare `Sendable` explicitly; inference does not cross module boundaries.
- Tests use Swift Testing (`@Test`, `#expect`, `#require`) in `Tests/MapKitSwiftSearchTests/`.
- Use SwiftDoc comments on public API. Comments say why; code says how.
- "A Philosophy of Software Design" guides review: deep modules, simple interfaces.

## Issue Tracker

Work is tracked in Linear, team Klimate (`KLI-` keys), with the `MapKitSwiftSearch` label. Commit and PR titles end with the key, `(KLI-nn)`.

## Releases

Releases are semver tags (`0.2.0`) on `main`, with a GitHub release. Before 1.0 any change to the public API is a minor release, because Klimate pins this package with `.upToNextMinor(from:)`. A person tags each release; agents never do.
