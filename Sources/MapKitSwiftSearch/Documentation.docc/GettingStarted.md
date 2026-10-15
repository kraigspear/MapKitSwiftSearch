# Getting Started

Search as the user types, highlight the matches, and resolve the pick to a placemark.

## Overview

``LocationSearch`` is `@MainActor`. Give each search field its own instance, because a newer search supersedes an older one on the same instance.

### Search as the user types

Call ``LocationSearch/search(queryFragment:)`` on every change to the text. A superseded call throws ``LocationSearchError/debounce``, or `CancellationError` if its MapKit search had already started. Repeating the previous query throws ``LocationSearchError/duplicateSearchCriteria``. All three mean "keep the current results."

```swift
import MapKitSwiftSearch
import Observation

@MainActor
@Observable
final class SearchModel {
    private let locationSearch = LocationSearch()
    private(set) var completions: [LocalSearchCompletion] = []

    func queryChanged(to query: String) async {
        do {
            completions = try await locationSearch.search(queryFragment: query)
        } catch LocationSearchError.debounce, LocationSearchError.duplicateSearchCriteria {
            // Superseded by newer input, or the text didn't change
        } catch is CancellationError {
            // Superseded after the MapKit search started
        } catch {
            completions = []
        }
    }

    func placemark(for completion: LocalSearchCompletion) async throws -> Placemark? {
        try await locationSearch.placemark(for: completion)
    }
}
```

### Show and resolve the results

``LocalSearchCompletion/highlightedTitle(foregroundColor:highlightColor:)`` and ``LocalSearchCompletion/highlightedSubTitle(foregroundColor:highlightColor:)`` color the text MapKit matched. Their default colors, light gray with a white highlight, suit only a dark background, so pass the system label colors to adapt to both appearances. ``LocationSearch/placemark(for:)`` resolves the completion the user picks. On iOS, `.searchable` needs a navigation container to show its search field.

```swift
import MapKitSwiftSearch
import SwiftUI

struct SearchView: View {
    @State private var model = SearchModel()
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(model.completions) { completion in
                Button {
                    Task {
                        if let placemark = try? await model.placemark(for: completion) {
                            print(placemark.name ?? "", placemark.coordinate)
                        }
                    }
                } label: {
                    CompletionRow(completion: completion)
                }
            }
            .searchable(text: $query)
            .task(id: query) {
                await model.queryChanged(to: query)
            }
        }
    }
}

struct CompletionRow: View {
    let completion: LocalSearchCompletion

    var body: some View {
        VStack(alignment: .leading) {
            Text(completion.highlightedTitle(foregroundColor: Self.unmatchedColor, highlightColor: Self.matchedColor))
            Text(completion.highlightedSubTitle(foregroundColor: Self.unmatchedColor, highlightColor: Self.matchedColor))
                .font(.caption)
        }
    }

    #if os(iOS)
    private static let unmatchedColor = UIColor.secondaryLabel
    private static let matchedColor = UIColor.label
    #else
    private static let unmatchedColor = NSColor.secondaryLabelColor
    private static let matchedColor = NSColor.labelColor
    #endif
}
```

`.task(id:)` cancels the previous task when the text changes, but that cancellation doesn't reach ``LocationSearch``; the newer call is what supersedes the older one.
