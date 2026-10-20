# Highlight every match

Supersedes ADR 0003.

## Context

ADR 0003 kept only the first highlight range MapKit reports for each field. Its premise fails: MapKit reports one range per matched word, not always in text order, and the ranges can overlap. For "coffee main", "Mains Treat Coffeehouse" arrives with `{12, 6}` and `{0, 4}`, so only "Coffee" was highlighted. For "Sheridan, In", "Sheridan, IN" arrives with `{0, 8}`, `{10, 2}`, and `{0, 12}`, so only "Sheridan" was.

The interface around that one range was shallow as well. `HighlightRange` only forwarded to Foundation's `Range(_:in:)`. The iOS and macOS highlighting files were identical apart from `UIColor` and `NSColor`. Their default colors, light gray with a white highlight, read only on a dark background. Callers (Klimate, TestApp, and the README) used only `highlightedTitle()` and `highlightedSubTitle()`, never the range properties.

## Decision

`LocalSearchCompletion` colors every highlight, through one cross-platform pair of methods: `highlightedTitle(foreground:highlight:)` and `highlightedSubTitle(foreground:highlight:)`. They take SwiftUI `Color`s, defaulting to `.secondary` and `.primary`, which read in light and dark appearance, and set SwiftUI's `foregroundColor` attribute.

- The snapshot converts all of MapKit's ranges once, to `[Range<String.Index>]` against a native UTF-8 copy of the text, so highlights built from a Swift string compare and hash the same. A range that doesn't fit the text is dropped, never a crash.
- Ranges are colored in any order and may overlap; overlapping ranges color their union.
- `==` and `hash(into:)` cover the title, the subtitle, and the highlights. `id` stays the title and subtitle.
- `HighlightRange`, `titleHighlightRange`, `subtitleHighlightRange`, and the `PlatformSpecific/` files are removed. The highlights stay internal; the internal memberwise initializer takes them as `titleHighlights:` and `subtitleHighlights:`.

## Alternatives considered

- **Marked text that the caller styles.** Return an `AttributedString` whose matches carry a presentation intent and let callers style them. Rejected: SwiftUI renders the marking as bold, so every caller that wants color instead would need styling code.
- **Arrays of ranges plus the platform files.** Make the two range properties arrays and keep the per-platform color methods. Rejected: the shallow pieces stay, and two copies of the coloring code keep drifting apart.

## Consequences

- Every word of a multi-word query is highlighted.
- Removing public types and properties changes the public API, so it ships in a minor release (0.3.0); Klimate pins `.upToNextMinor`.
- Callers that passed `UIColor` or `NSColor` pass SwiftUI `Color`s instead. Klimate passes none, and its dark-only UI keeps nearly the same look with the new defaults.
- The library links SwiftUI, on both platforms.
