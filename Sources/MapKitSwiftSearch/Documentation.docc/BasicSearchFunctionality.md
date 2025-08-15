# Basic Search Functionality

Learn how to perform location searches effectively using MapKitSwiftSearch.

## Overview

The `LocationSearch` class provides a simple but powerful interface for finding locations using natural language queries. It handles the complexity of MapKit's search APIs while providing modern Swift concurrency support.

## Creating a LocationSearch Instance

The `LocationSearch` class is the main entry point for all search operations:

```swift
import MapKitSwiftSearch

// Create with default settings
let locationSearch = LocationSearch()

// Create with custom minimum character count
let customSearch = LocationSearch(numberOfCharactersBeforeSearching: 3)

// Create with custom debounce delay
let fastSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 2,
    debounceSearchDelay: .milliseconds(150)
)
```

### Configuration Options

- **numberOfCharactersBeforeSearching**: Minimum characters required before search begins (default: 5)
- **debounceSearchDelay**: Time to wait before executing search (default: 300ms)

## Performing Searches

### Basic Search

The `search(queryFragment:)` method accepts natural language queries:

```swift
let locationSearch = LocationSearch()

do {
    let results = try await locationSearch.search(queryFragment: "Starbucks")
    print("Found \(results.count) locations")
} catch {
    print("Search failed: \(error)")
}
```

### Search Query Examples

MapKitSwiftSearch works with various types of queries:

```swift
// Points of Interest
let coffeeShops = try await locationSearch.search(queryFragment: "Coffee shops near me")
let restaurants = try await locationSearch.search(queryFragment: "Italian restaurants")

// Addresses
let address = try await locationSearch.search(queryFragment: "123 Main Street")
let partialAddress = try await locationSearch.search(queryFragment: "Main St, San Francisco")

// Landmarks and Places
let landmarks = try await locationSearch.search(queryFragment: "Golden Gate Bridge")
let airports = try await locationSearch.search(queryFragment: "San Francisco Airport")

// Business Names
let business = try await locationSearch.search(queryFragment: "Apple Park")
let stores = try await locationSearch.search(queryFragment: "Target store")
```

## Understanding Search Results

Search operations return an array of `LocalSearchCompletion` objects:

```swift
let results = try await locationSearch.search(queryFragment: "Pizza")

for result in results {
    print("Title: \(result.title)")           // "Joe's Pizza"
    print("Subtitle: \(result.subTitle)")     // "123 Main St, New York, NY"
    print("ID: \(result.id)")                 // Unique identifier
    
    // Check for highlight ranges (useful for UI)
    if let titleHighlight = result.titleHighlightRange {
        print("Title has highlighting")
    }
    
    if let subtitleHighlight = result.subtitleHighlightRange {
        print("Subtitle has highlighting")
    }
}
```

### LocalSearchCompletion Properties

- **title**: Primary name or description of the location
- **subTitle**: Additional details like address or region
- **id**: Unique identifier for the completion
- **titleHighlightRange**: Range of text in title that matches the search query
- **subtitleHighlightRange**: Range of text in subtitle that matches the search query

## Real-Time Search Implementation

Here's a complete example for implementing real-time search as the user types:

```swift
import SwiftUI
import MapKitSwiftSearch

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [LocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private let locationSearch = LocationSearch()
    
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let results = try await locationSearch.search(queryFragment: query)
            searchResults = results
        } catch LocationSearchError.debounce {
            // Search was debounced, this is normal
        } catch LocationSearchError.invalidSearchCriteria {
            // Not enough characters, clear results
            searchResults = []
        } catch LocationSearchError.duplicateSearchCriteria {
            // Same search as before, ignore
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        VStack {
            SearchField(text: $viewModel.searchText) {
                Task {
                    await viewModel.search()
                }
            }
            
            SearchResultsList(
                results: viewModel.searchResults,
                isSearching: viewModel.isSearching,
                errorMessage: viewModel.errorMessage
            )
        }
    }
}
```

## Search Performance Tips

### Debouncing

The built-in debouncing prevents excessive API calls:

```swift
// Fast typing won't trigger multiple searches
textField.onChange(of: searchText) { newValue in
    Task {
        do {
            // Only the final search after 300ms will execute
            let results = try await locationSearch.search(queryFragment: newValue)
            // Handle results
        } catch LocationSearchError.debounce {
            // Previous searches were cancelled - this is expected
        }
    }
}
```

### Minimum Character Requirements

Set appropriate minimum character counts for your use case:

```swift
// For general location search
let generalSearch = LocationSearch(numberOfCharactersBeforeSearching: 5)

// For quick business name lookup
let businessSearch = LocationSearch(numberOfCharactersBeforeSearching: 3)

// For detailed address search
let addressSearch = LocationSearch(numberOfCharactersBeforeSearching: 8)
```

### Managing Search State

Handle concurrent searches properly:

```swift
class SearchController {
    private let locationSearch = LocationSearch()
    private var currentSearchTask: Task<Void, Never>?
    
    func performSearch(_ query: String) {
        // Cancel previous search
        currentSearchTask?.cancel()
        
        // Start new search
        currentSearchTask = Task {
            do {
                let results = try await locationSearch.search(queryFragment: query)
                await updateUI(with: results)
            } catch {
                await handleSearchError(error)
            }
        }
    }
    
    @MainActor
    private func updateUI(with results: [LocalSearchCompletion]) {
        // Update your UI with results
    }
    
    @MainActor
    private func handleSearchError(_ error: Error) {
        // Handle search errors
    }
}
```

## Search Scope Considerations

### Geographic Bias

MapKit automatically biases results based on:
- Device location (if location services are enabled)
- Previous search context
- Regional settings

### Result Limits

- MapKit typically returns 10-15 results per search
- Results are ranked by relevance and proximity
- More specific queries generally return fewer, more relevant results

## Next Steps

- **<doc:WorkingWithSearchResults>** - Learn how to handle and display search results
- **<doc:ErrorHandling>** - Understand different error scenarios
- **<doc:AdvancedUsage>** - Explore customization and performance optimization