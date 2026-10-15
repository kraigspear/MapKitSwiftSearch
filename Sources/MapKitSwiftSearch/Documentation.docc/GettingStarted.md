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

``LocalSearchCompletion/highlightedTitle(foregroundColor:highlightColor:)`` and ``LocalSearchCompletion/highlightedSubTitle(foregroundColor:highlightColor:)`` color the text MapKit matched. ``LocationSearch/placemark(for:)`` resolves the completion the user picks.

```swift
import MapKitSwiftSearch
import SwiftUI

struct SearchView: View {
    @State private var model = SearchModel()
    @State private var query = ""

    var body: some View {
        List(model.completions) { completion in
            Button {
                Task {
                    if let placemark = try? await model.placemark(for: completion) {
                        print(placemark.name ?? "", placemark.coordinate)
                    }
                }
            } label: {
                VStack(alignment: .leading) {
                    Text(completion.highlightedTitle())
                    Text(completion.highlightedSubTitle())
                        .font(.caption)
                }
            }
        }
        .searchable(text: $query)
        .task(id: query) {
            await model.queryChanged(to: query)
        }
    }
}
```

`.task(id:)` cancels the previous task when the text changes, but that cancellation doesn't reach ``LocationSearch``; the newer call is what supersedes the older one.
