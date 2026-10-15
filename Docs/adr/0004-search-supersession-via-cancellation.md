# Search supersession via cancellation

## Context

Callers invoke `search(queryFragment:)` on every change to the query fragment, and a newer call supersedes an older one (ADR 0001). Callers have to decode four outcomes as separate errors: `LocationSearchError.debounce` for a call superseded during its debounce, `.duplicateSearchCriteria` for a repeated query fragment, `.invalidSearchCriteria` for a non-empty one shorter than the minimum, and `CancellationError` for a call superseded while MapKit was searching.

The README, the DocC error-handling article (removed in KLI-249), TestApp, and Klimate each decoded them differently, and three of them got it wrong. The DocC article reported a superseded search as an unexpected error. TestApp empties its list on every superseded keystroke. Klimate, in production, catches only `.mapKitError`, which `search` never throws, so a real search failure shows no alert.

## Decision

`search(queryFragment:)` keeps debounce and supersession inside the module. A superseded search ends only with `CancellationError`, whether the newer call arrives during its debounce or while MapKit is searching. The debounce, duplicate, and short-query outcomes stop crossing the interface, so a caller ignores `CancellationError` and treats any other error as a failure. KLI-252 implements this.

Two alternatives were rejected:

- An observable results state. It would move Klimate's model from awaiting a call to observing state, and results would be stored in two places: the package's state and the caller's model.
- A plain lookup whose caller owns the debounce. It pushes debounce into every caller.

## Consequences

- Every caller gets the same debounce and supersession without writing its own, and keeps its completions in one place, its own model.
- Removing `.debounce`, `.duplicateSearchCriteria`, and `.invalidSearchCriteria` changes the public API, so it needs a minor release before 1.0. Klimate adopts it separately.
- ADR 0001's rules 1 and 2, and its advice to treat `.debounce` and `.duplicateSearchCriteria` as "keep the current results", describe the code until KLI-252 changes it.
