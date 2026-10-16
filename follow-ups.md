# Follow-ups

## FU-1 (FOLLOW-UP): No test reaches the completer adapter's cancellation path

- Review target: branch `kraigspear/kli-251-bridge-the-completer-to-async-inside-its-adapter` (KLI-251), base `13cb41e`.
- Evidence: `Sources/MapKitSwiftSearch/LocationSearch.swift`, `MKLocalSearchCompleterAdapter.completions(for:)`. Unit tests replace the adapter with `FakeSearchCompleter`, and the live test in `Tests/MapKitSwiftSearchTests/MapKitSwiftSearchTests.swift` supersedes a search during its debounce, before MapKit starts. Nothing runs the adapter's `onCancel`, its already-cancelled guard, or its `completer.cancel()`.
- Cost: a later edit that drops the resume in `onCancel` hangs a superseded caller forever, and a double resume crashes; `swift test` catches neither.
- Next action: add a live test that supersedes a search while MapKit is searching and asserts the first call finishes, with either outcome.
- Why it doesn't block: the ticket chose this seam, and both reviewers traced the exactly-once logic by reading it.

## FU-2 (FOLLOW-UP): `swiftformat --lint .` fails on `main`

- Review target: as FU-1. Red on `main` before this change.
- Evidence: SwiftFormat 0.62.1 added the default rule `swiftTestingTestCaseNames`, which `.swiftformat` doesn't disable. It flags every `@Test` in all five test files (56 errors on `main`).
- Cost: the lint check that `CLAUDE.md` and tickets name can't pass, so it no longer catches real formatting drift.
- Next action: decide once for the repository: add `--disable swiftTestingTestCaseNames` to `.swiftformat`, or migrate the test names to raw identifiers.
- Why it doesn't block: it predates this change, CI doesn't run it, and this change adds only hits of the same rule.
