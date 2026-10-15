# Search tasks owned through stored handles

## Context

Callers invoke `LocationSearch.search(queryFragment:)` on every keystroke, each from its own task: a SwiftUI `onChange`, a UIKit delegate callback. A newer call has to stop the older call's debounce and MapKit search. Structured concurrency only lets a parent cancel its children, and the newer call is not the older call's parent.

## Decision

`search(queryFragment:)` runs the debounce and the MapKit search as unstructured `Task`s and keeps their handles in `debounceTask` and `currentSearchTask`, so any later call can cancel them. Callers then make one call per keystroke and track no tasks of their own. The alternative, a stateless `LocationSearch` whose callers cancel through `.task(id:)` or their own handles, would have every consumer rebuild debounce and supersede.

A newer call supersedes an older one by these rules, in the order `search(queryFragment:)` applies them:

1. Every call cancels the previous call's debounce on entry. An older call still waiting out its debounce throws `LocationSearchError.debounce`; one already past its debounce is unaffected by this step.
2. After its own debounce, a call repeating the previous query throws `.duplicateSearchCriteria` before it cancels any in-flight search. A search already running for that query keeps running and delivers, which covers a user typing a character and deleting it.
3. A different query cancels the in-flight search before the empty-query and minimum-length exits. Otherwise the older search would deliver after the newer call returned (KLI-244).
4. A cancelled search throws `CancellationError` even when MapKit answered first. MapKit's answer can resume the search task before its cancellation handler runs, so `search` checks `task.isCancelled` after awaiting the result.

## Consequences

- Cancelling the caller's task cancels neither the debounce nor the MapKit search: awaiting an unstructured task's value does not forward cancellation. The call runs to its normal end.
- Callers treat `.debounce`, `.duplicateSearchCriteria`, and `CancellationError` as "keep the current results", not as failures.
- The handles need no lock only because `LocationSearch` is `@MainActor`.
- Two search fields that share one `LocationSearch` supersede each other's searches. Give each field its own instance.
