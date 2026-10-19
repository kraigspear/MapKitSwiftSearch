# Search calls share one MapKit search

Supersedes ADR 0001.

## Context

ADR 0004 says a superseded search ends only with `CancellationError`, and KLI-252 adds three more rules. A newer call ends an older one at once, even during its debounce. Cancelling the caller's task cancels its MapKit search. A newer call with the same query fragment as a MapKit search still running takes that search over instead of starting another.

ADR 0001's two stored handles can't satisfy all three. Its debounce task was shared by every call, so a superseded call learned it was superseded only when its debounce ended. Its MapKit search task belonged to the call that started it, so ending that call either cancelled the search or left it running with nobody waiting.

## Decision

`search(queryFragment:)` keeps two kinds of unstructured task, still held in stored handles on the `@MainActor` instance:

- **The call**: one task per call for its debounce and its wait. `currentCall` holds the latest one, and every new call cancels it on entry. The caller awaits it inside a cancellation handler that cancels it too, so the caller's own cancellation reaches the debounce and the wait.
- **The MapKit search**: `inFlightSearch` holds one per query fragment, apart from any call. A call waits on it with `valueUntilCancelled()`, which ends the wait when the call is cancelled but leaves the search running for whichever call takes it over.

A call cancels the MapKit search only when nothing else wants it. A new call with a different query fragment, an empty one, or one that is too short cancels it on entry. A call whose caller was cancelled cancels it, but only if it is still the latest call, which a counter, `generation`, tells it. A finished or failed search is removed, so the next call with the same query fragment searches again.

MapKit can answer in the same main-actor turn a newer call arrives, so the call's task can finish with completions after it was superseded. The caller compares `generation` after the call's task ends and throws `CancellationError` when a newer call has arrived.

## Consequences

- Cancelling the caller's task now cancels its debounce and MapKit search, which ADR 0001's design couldn't.
- Taking over a search needs a wait that answers cancellation without cancelling what it waits on. `Task.value` can't, so `valueUntilCancelled()` starts one extra task per wait.
- The handles and the counter need no lock only because `LocationSearch` is `@MainActor`.
- Two search fields that share one `LocationSearch` still supersede each other. Give each field its own instance.
