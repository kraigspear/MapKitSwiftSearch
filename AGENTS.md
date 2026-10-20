# Repository Guidelines

## Project Structure & Module Organization
`Sources/MapKitSwiftSearch` holds the library: `LocationSearch` and the `Sendable` value types it returns. The code is the same on iOS and macOS. Tests live in `Tests/MapKitSwiftSearchTests`. `TestApp/` is a demo app outside the package build. Each documentation fact has one home: a symbol's contract (what it returns, throws, cancels) in its doc comment, which DocC renders; onboarding in `README.md` and `Documentation.docc` (landing page and `GettingStarted.md`); the reasoning behind a hard-to-reverse choice in a numbered ADR under `Docs/adr/`. When code changes a fact, edit its one home in the same commit.
Use the domain terms defined in `GLOSSARY.md` in new code, docs, ADRs, and tickets.

## Build, Test, and Development Commands
Use SwiftPM: `swift build` compiles the package and `swift test` runs the suite on the macOS host. Target a subset with `swift test --filter SomeTests`. `./scan.sh` runs Periphery. `scripts/check-readme-snippets.sh` compiles every Swift snippet in README.md. `.github/workflows/ci.yml` defines what CI checks. Open the package in Xcode with `xed .`.

## Coding Style & Naming Conventions
Format everything with `swiftformat .` (4-space indentation, explicit `self` removed, trailing commas). Keep types in PascalCase and file names matching their primary type.

## Testing Guidelines
Tests use Swift Testing; name files and suites with the `ThingTests` suffix. New behavior includes a happy-path and an edge-case assertion. `MapKitSwiftSearchTests.swift` calls live MapKit and needs network; `LocationSearchUnitTests` drives timing and MapKit failures through fakes passed to `LocationSearch`'s internal initializer.

## API Stability
The public surface is a semver commitment. Before 1.0, any public API change is a minor release. Releases are tagged by a person, never by an agent.
