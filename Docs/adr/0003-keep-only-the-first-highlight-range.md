# Keep only the first highlight range

## Context

MapKit reports text matches as arrays of ranges: `titleHighlightRanges` and `subtitleHighlightRanges` on `MKLocalSearchCompletion`.

## Decision

`LocalSearchCompletion` keeps one optional `HighlightRange` per field, taken from the first entry in MapKit's array. `highlightedTitle()` and `highlightedSubTitle()` color that one range. The reason given in the code was that MapKit reports one meaningful range per field, and a single optional keeps the API small.

## Consequences

- That premise holds only for single-word queries. A probe of live MapKit (macOS 27, October 2026) found one range per matched word, and the ranges were not always in text order. For "coffee main", MapKit returned "Mains Treat Coffeehouse" with ranges `{12, 6}` and `{0, 4}`, so only "Coffee" is highlighted. For "Sheridan, In", it returned "Sheridan, IN" with `{0, 8}`, `{10, 2}`, and `{0, 12}`, so only "Sheridan" is highlighted. Ranges can overlap.
- To highlight every match, `titleHighlightRange` and `subtitleHighlightRange` must become arrays, or new properties must be added. Either way the public API changes, so a minor release is needed; Klimate pins `.upToNextMinor`.
