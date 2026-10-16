# Follow-ups

## FU-2 (FOLLOW-UP): `swiftformat --lint .` fails on `main`

- Review target: branch `kraigspear/kli-251-bridge-the-completer-to-async-inside-its-adapter` (KLI-251), base `13cb41e`. Red on `main` before this change.
- Evidence: with SwiftFormat 0.62.1, the enabled rule `swiftTestingTestCaseNames` (raw-identifier test names by default) flags every `@Test` in all five test files (56 errors on `main`). `.swiftformat` doesn't disable it.
- Cost: the lint check tickets name (`swiftformat --lint .`) can't pass, so it no longer catches real formatting drift. `swiftformat .`, the command `CLAUDE.md` and `AGENTS.md` give, would rewrite every test name.
- Next action: decide once for the repository: add `--disable swiftTestingTestCaseNames` to `.swiftformat`, or migrate the test names to raw identifiers.
- Why it doesn't block: it predates this change, CI doesn't run it, and this change adds only hits of the same rule.
