# Repository Guidelines

## Project Structure & Module Organization
`Sources/MapKitSwiftSearch` holds the library: `LocationSearch` and the `Sendable` value types it returns. UIKit and AppKit specifics live in `Sources/MapKitSwiftSearch/PlatformSpecific/`. Tests live in `Tests/MapKitSwiftSearchTests`. `TestApp/` is a demo app outside the package build. User documentation (guides and API reference) lives only in `Sources/MapKitSwiftSearch/Documentation.docc`; `docs/` holds contributor design notes. Write user-facing docs in DocC, never in `docs/`, so there is one copy to keep current.

## Build, Test, and Development Commands
Use SwiftPM: `swift build` compiles the package and `swift test` runs the suite on the macOS host. Target a subset with `swift test --filter SomeTests`. `./scan.sh` runs Periphery. Open the package in Xcode with `xed .`.

## Coding Style & Naming Conventions
Format everything with `swiftformat .` (4-space indentation, explicit `self` removed, trailing commas). Keep types in PascalCase and file names matching their primary type.

## Testing Guidelines
Tests use Swift Testing; name files and suites with the `ThingTests` suffix. New behavior includes a happy-path and an edge-case assertion.

## API Stability
The public surface is a semver commitment. Before 1.0, any public API change is a minor release. Releases are tagged by a person, never by an agent.
