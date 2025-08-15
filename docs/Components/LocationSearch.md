# LocationSearch API Documentation

## Overview

`LocationSearch` is the primary interface for performing location-based searches using MapKit. It provides a modern, async/await-based API that wraps MapKit's `MKLocalSearchCompleter` with additional features like debouncing, cancellation support, and structured error handling.

## Class Declaration

```swift
@MainActor
public final class LocationSearch
```

### Actor Isolation

The class is marked with `@MainActor` because:
- MapKit's `MKLocalSearchCompleter` requires main thread interaction
- Eliminates race conditions on internal state
- Provides clear concurrency semantics for callers
- Simplifies thread management for clients

## Initialization

### Primary Initializer

```swift
public init(
    numberOfCharactersBeforeSearching: Int = 5,
    debounceSearchDelay: Duration = .milliseconds(300)
)
```

#### Parameters

- **numberOfCharactersBeforeSearching**: Minimum character count before initiating search
  - **Default**: 5 characters
  - **Rationale**: Prevents excessive API calls with very short queries that typically return broad, less useful results
  - **Range**: Recommended 3-10 characters depending on use case

- **debounceSearchDelay**: Time delay to wait before executing search
  - **Default**: 300 milliseconds  
  - **Rationale**: Balances responsiveness with API efficiency for typing users
  - **Range**: 200-500ms recommended for most interactive applications

#### Example Usage

```swift
// Default configuration - good for most applications
let searcher = LocationSearch()

// Custom configuration for more aggressive searching
let aggressiveSearcher = LocationSearch(
    numberOfCharactersBeforeSearching: 3,
    debounceSearchDelay: .milliseconds(200)
)

// Conservative configuration for limited API quotas
let conservativeSearcher = LocationSearch(
    numberOfCharactersBeforeSearching: 7,
    debounceSearchDelay: .milliseconds(500)
)
```

## Public Methods

### search(queryFragment:)

The primary method for performing location searches.

```swift
public func search(queryFragment: String) async throws -> [LocalSearchCompletion]
```

#### Parameters

- **queryFragment**: The search text to use for finding locations
  - **Type**: `String`
  - **Validation**: Must meet minimum character requirements
  - **Format**: Natural language queries (e.g., "Coffee shops near me", "123 Main St")

#### Return Value

- **Type**: `[LocalSearchCompletion]`
- **Description**: Array of search results ranked by relevance
- **Empty Array**: Returned for empty query strings (no error thrown)

#### Error Cases

The method can throw the following `LocationSearchError` cases:

##### .debounce
```swift
catch LocationSearchError.debounce {
    // Request was cancelled due to debouncing
    // This is normal behavior during rapid typing
}
```
**When**: A new search request comes in before the debounce delay has elapsed
**Handling**: Usually safe to ignore, as it indicates user is still typing

##### .duplicateSearchCriteria
```swift
catch LocationSearchError.duplicateSearchCriteria {
    // Same query was submitted consecutively
    // Previous results are still valid
}
```
**When**: The same exact query string is submitted twice in a row
**Handling**: Use previously cached results or inform user no new search was needed

##### .invalidSearchCriteria
```swift
catch LocationSearchError.invalidSearchCriteria {
    // Query doesn't meet minimum character requirements
    // Prompt user to enter more characters
}
```
**When**: Query length is below `numberOfCharactersBeforeSearching` threshold
**Handling**: Display helpful message about minimum character requirements

##### .searchCompletionFailed
```swift
catch LocationSearchError.searchCompletionFailed {
    // Generic search failure
    // May be temporary network or service issue
}
```
**When**: The underlying MapKit search operation fails for unknown reasons
**Handling**: Retry mechanism or user notification of temporary failure

##### .mapKitError(MKError)
```swift
catch LocationSearchError.mapKitError(let mkError) {
    // Specific MapKit error with detailed information
    switch mkError.code {
    case .networkFailure:
        // Handle network-specific errors
    case .placemarkNotFound:
        // Handle location not found errors
    default:
        // Handle other MapKit errors
    }
}
```
**When**: MapKit returns a specific error condition
**Handling**: Examine the underlying `MKError` for specific recovery strategies

#### Usage Examples

##### Basic Search
```swift
do {
    let results = try await locationSearch.search(queryFragment: "Starbucks")
    // Process results
    for result in results {
        print("\(result.title) - \(result.subTitle)")
    }
} catch {
    // Handle errors appropriately
}
```

##### Error-Specific Handling
```swift
do {
    let results = try await locationSearch.search(queryFragment: query)
    updateUI(with: results)
} catch LocationSearchError.debounce {
    // Ignore debounce errors - user is still typing
} catch LocationSearchError.duplicateSearchCriteria {
    // Use cached results if available
    if let cachedResults = lastSearchResults {
        updateUI(with: cachedResults)
    }
} catch LocationSearchError.invalidSearchCriteria {
    showMessage("Please enter at least 5 characters")
} catch {
    showError("Search failed: \(error.localizedDescription)")
}
```

### placemark(for:)

Retrieves detailed placemark information for a search completion result.

```swift
public func placemark(for searchCompletion: LocalSearchCompletion) async throws -> Placemark?
```

#### Parameters

- **searchCompletion**: A `LocalSearchCompletion` result from a previous search
  - **Source**: Must be obtained from a `search(queryFragment:)` call
  - **Validity**: Results may become stale over time

#### Return Value

- **Type**: `Placemark?`
- **Nil Return**: Possible if the location is no longer available or resolvable
- **Success**: Contains detailed address components and coordinates

#### Error Cases

##### .mapKitError(MKError)
```swift
catch LocationSearchError.mapKitError(let mkError) {
    // MapKit-specific error during placemark resolution
}
```

##### .searchCompletionFailed  
```swift
catch LocationSearchError.searchCompletionFailed {
    // Failed to resolve the search completion to a placemark
}
```

#### Usage Examples

##### Basic Placemark Retrieval
```swift
// First, perform a search
let results = try await locationSearch.search(queryFragment: "Central Park")

// Then get detailed information for the first result
if let firstResult = results.first {
    let placemark = try await locationSearch.placemark(for: firstResult)
    
    if let place = placemark {
        print("Coordinates: \(place.coordinate)")
        print("Address: \(formatAddress(from: place))")
    }
}
```

##### Complete Search-to-Selection Flow
```swift
func searchAndSelect(_ query: String) async {
    do {
        // Search for locations
        let completions = try await locationSearch.search(queryFragment: query)
        
        // Let user select from results (UI implementation not shown)
        let selectedCompletion = await presentSelectionUI(completions)
        
        // Get detailed placemark
        if let placemark = try await locationSearch.placemark(for: selectedCompletion) {
            // Use the detailed location information
            await navigateToLocation(placemark)
        }
        
    } catch {
        await showError(error)
    }
}
```

## Internal Architecture

### State Management

```swift
private let debounceSearchDelay: Duration
private var lastSearchQuery: String?
private var localSearchCompletions: [LocalSearchCompletion] = []
private let numberOfCharactersBeforeSearching: Int

// Task management
private var currentSearchTask: SearchTask?
private var debounceTask: Task<Bool, Never>?
```

#### Why This Design?

- **Immutable Configuration**: `debounceSearchDelay` and `numberOfCharactersBeforeSearching` are set at initialization and never change
- **Minimal Mutable State**: Only `lastSearchQuery` and task references change during operation
- **Task-Based Cancellation**: Both debouncing and searching use `Task` for clean cancellation semantics

### Search Flow Implementation

The public `search` method orchestrates several private operations:

1. **Debounce Management**: Cancel previous debounce task and start new one
2. **Validation**: Check query length and duplication
3. **Task Cancellation**: Cancel any in-progress search
4. **Search Execution**: Delegate to `performSearch` method

#### Why Separate performSearch?

The `performSearch` method is extracted as a private method because:
- **Single Responsibility**: Handles only the MapKit interaction
- **Testability**: Can be tested independently of validation logic
- **Clarity**: Separates concerns between public API contract and implementation details
- **Maintainability**: Changes to search logic don't affect validation or error handling

## Performance Characteristics

### Memory Usage
- **Lightweight**: Minimal state maintained between searches
- **Automatic Cleanup**: Tasks are automatically deallocated when completed or cancelled
- **No Caching**: Results are not cached to avoid stale data issues

### Network Efficiency
- **Debouncing**: Prevents excessive API calls during typing
- **Cancellation**: Abandoned searches don't waste bandwidth
- **Fresh Completers**: Each search uses a new completer to avoid state pollution

### Thread Safety
- **MainActor**: All operations are main-actor-isolated
- **Task Isolation**: Each search operation runs in its own task context
- **State Protection**: Shared state is protected by actor isolation

## Common Usage Patterns

### Search-as-You-Type
```swift
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [LocalSearchCompletion] = []
    
    private let locationSearch = LocationSearch()
    
    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                Task { @MainActor in
                    await self?.performSearch(query)
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func performSearch(_ query: String) async {
        do {
            results = try await locationSearch.search(queryFragment: query)
        } catch LocationSearchError.debounce {
            // Ignore debounce errors in search-as-you-type
        } catch {
            // Handle other errors
            results = []
        }
    }
}
```

### Batch Processing
```swift
func searchMultipleLocations(_ queries: [String]) async -> [String: [LocalSearchCompletion]] {
    var results: [String: [LocalSearchCompletion]] = [:]
    
    for query in queries {
        do {
            let completions = try await locationSearch.search(queryFragment: query)
            results[query] = completions
        } catch {
            print("Failed to search '\(query)': \(error)")
            results[query] = []
        }
    }
    
    return results
}
```

## Best Practices

### Error Handling
- Always handle `LocationSearchError.debounce` gracefully in interactive UIs
- Provide user feedback for `invalidSearchCriteria` errors
- Implement retry logic for `mapKitError` network failures
- Log `searchCompletionFailed` errors for debugging

### Performance
- Use appropriate debounce delays for your use case (200-500ms)
- Set reasonable minimum character thresholds (3-7 characters)
- Cancel search operations when views disappear or become inactive
- Consider implementing result caching at the application level if needed

### User Experience
- Provide visual feedback during search operations
- Clear previous results when starting new searches
- Handle empty results gracefully with helpful messaging
- Respect user privacy by not logging search queries