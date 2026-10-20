# Getting Started

Search as the user types, highlight the matches, and resolve the pick to a placemark.

## Overview

``LocationSearch`` is `@MainActor`. Give each search field its own instance, because a newer search supersedes an older one on the same instance.

### Search as the user types

Call ``LocationSearch/search(queryFragment:)`` on every change to the text. Only the latest call returns completions; a superseded call throws `CancellationError`, which means "keep the current results." Any other error is a failure. MapKit throttles bursts of searches with `MKError.loadingThrottled`, which clears by itself, so keep the current results for that too rather than alerting.

```swift
import MapKit
import MapKitSwiftSearch
import Observation

@MainActor
@Observable
final class SearchModel {
    private let locationSearch = LocationSearch()
    private(set) var completions: [LocalSearchCompletion] = []
    private(set) var searchError: (any Error)?

    func queryChanged(to query: String) async {
        do {
            completions = try await locationSearch.search(queryFragment: query)
            searchError = nil
        } catch is CancellationError {
            // A newer query superseded this one: keep the current completions
        } catch let LocationSearchError.mapKitError(error) where error.code == .loadingThrottled {
            // MapKit throttles bursts of searches and recovers by itself: keep the current completions
        } catch {
            searchError = error
        }
    }

    func placemark(for completion: LocalSearchCompletion) async throws -> Placemark {
        try await locationSearch.placemark(for: completion)
    }
}
```

### Show and resolve the results

``LocalSearchCompletion/highlightedTitle(foreground:highlight:)`` and ``LocalSearchCompletion/highlightedSubTitle(foreground:highlight:)`` color every part of the text that matches the query fragment. ``LocationSearch/placemark(for:)`` resolves the completion the user picks. On iOS, `.searchable` needs a navigation container to show its search field.

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
                        do {
                            let placemark = try await model.placemark(for: completion)
                            print(placemark.name ?? "", placemark.coordinate)
                        } catch {
                            print("Couldn't resolve \(completion.title): \(error)")
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
            Text(completion.highlightedTitle())
            Text(completion.highlightedSubTitle())
                .font(.caption)
        }
    }
}
```

`.task(id:)` cancels the previous task when the text changes. ``LocationSearch`` ends that call with `CancellationError` and cancels its MapKit search, the same as when a newer call supersedes it.
