# Follow-ups

## FU-2 (FOLLOW-UP): `swiftformat --lint .` fails on `main`

- Status: resolved by KLI-260 (#19), which migrated the test names to raw identifiers and added the lint to CI. This branch's tests were converted when it merged `main`.

- Review target: branch `kraigspear/kli-251-bridge-the-completer-to-async-inside-its-adapter` (KLI-251), base `13cb41e`. Red on `main` before this change.
- Evidence: with SwiftFormat 0.62.1, the enabled rule `swiftTestingTestCaseNames` (raw-identifier test names by default) flags every `@Test` in all five test files (56 errors on `main`). `.swiftformat` doesn't disable it.
- Cost: the lint check tickets name (`swiftformat --lint .`) can't pass, so it no longer catches real formatting drift. `swiftformat .`, the command `CLAUDE.md` and `AGENTS.md` give, would rewrite every test name.
- Next action: decide once for the repository: add `--disable swiftTestingTestCaseNames` to `.swiftformat`, or migrate the test names to raw identifiers.
- Why it doesn't block: it predates this change, CI doesn't run it, and this change adds only hits of the same rule.

## FU-3 (FOLLOW-UP): TestApp doesn't build outside a checkout named `MapKitSwiftSearch`

- Status: resolved by KLI-263, which points the package reference at `..` and drops `formatcode.sh` from the project. A TestApp build in CI is still open.

- Review target: branch `kraigspear/kli-256-placemarks-interface-states-only-what-can-happen` (KLI-256), base `2935662`. Pre-existing on `main`.
- Evidence: `TestApp/TestApp.xcodeproj/project.pbxproj` references the package as `relativePath = ../../MapKitSwiftSearch`, so a git worktree in any other directory fails package resolution. The same project lists `formatcode.sh` in the TestApp target's Resources phase, but the file isn't in the repository, so `xcodebuild build -scheme TestApp` fails with "The file “formatcode.sh” couldn’t be opened".
- Cost: TestApp can't be built from a clean clone, so a public API change can't show TestApp still compiles without hand-editing the project; KLI-256 verified it only from a scratch copy with an empty `formatcode.sh`.
- Next action: point the package reference at `..` and drop `formatcode.sh` from the project, then add a TestApp build to CI if it should stay compiling.
- Why it doesn't block: it predates this change, and this change's TestApp edit builds for macOS and the iOS Simulator from that scratch copy.
