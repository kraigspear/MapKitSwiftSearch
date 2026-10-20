# One cancellable task per search call

Supersedes ADR 0001.

## Context

ADR 0004 says a superseded search ends only with `CancellationError`, and KLI-252 adds two more rules. A newer call ends an older one at once, even during its debounce. Cancelling the caller's task cancels its MapKit search.

ADR 0001's two stored handles can't satisfy both. A newer call cancelled the MapKit search only after its own debounce, so a call already waiting on MapKit learned it was superseded only when the newer call's debounce ended. Awaiting the search task's value didn't forward the caller's cancellation.

## Decision

Each call to `search(queryFragment:)` runs its debounce and its MapKit search in one unstructured task, and `currentSearch`, a stored handle on the `@MainActor` instance, holds the latest one.

- Every call cancels `currentSearch` on entry, before the empty-query and minimum-length exits, so a superseded call ends at once wherever it is.
- The caller awaits the task inside a cancellation handler that cancels it, so the caller's own cancellation reaches the debounce and MapKit.
- MapKit can answer in the same main-actor turn a newer call arrives, so a superseded task can finish with completions or a failure. After the task ends, the caller throws `CancellationError` unless its task is still `currentSearch` and its own task isn't cancelled.

A repeated query fragment gets no special treatment: it cancels the MapKit search for the same text and starts a new one after its debounce. Nothing is cached.

## Alternatives considered

KLI-252 first let a newer call with the same query fragment as a running MapKit search take that search over, so a caller that searched the same text twice in a row, such as a view re-running its search task without the text changing, cost no extra request. Any different fragment in between already cancelled that search, so typing a character and deleting it gained nothing. Taking over meant holding the MapKit search apart from the call that started it, a wait that answered the call's cancellation without cancelling the search (`valueUntilCancelled()`, one extra task per wait), and a counter so a cancelled call could tell whether a newer call still wanted the search. That machinery caused all three bugs found reviewing KLI-252: a dropped continuation resume that hung the tests, a superseded takeover that restarted a search it had given up, and a cancelled short query that returned no completions instead of throwing. KLI-262 dropped it. The cost is one extra MapKit request, and a restarted debounce, when the same query fragment is searched twice in a row before MapKit answers.

## Consequences

- Cancelling the caller's task cancels its debounce and MapKit search, which ADR 0001's design couldn't.
- Searching the same query fragment twice in a row before MapKit answers restarts the search and its debounce, and counts one more request toward MapKit's throttle.
- The handle needs no lock only because `LocationSearch` is `@MainActor`.
- Two search fields that share one `LocationSearch` still supersede each other. Give each field its own instance.
