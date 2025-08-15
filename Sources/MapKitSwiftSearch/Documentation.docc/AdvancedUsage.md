# Advanced Usage

Explore advanced features, performance optimization, and customization options for MapKitSwiftSearch.

## Overview

MapKitSwiftSearch provides several advanced features for customizing search behavior, optimizing performance, and handling complex use cases. This guide covers configuration options, concurrent search management, and performance best practices.

## Configuration Options

### Search Timing Configuration

Customize when searches are triggered and how they're debounced:

```swift
// Quick search for instant feedback (good for business names)
let quickSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 2,
    debounceSearchDelay: .milliseconds(150)
)

// Standard search with moderate delay (good for general use)
let standardSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 5,
    debounceSearchDelay: .milliseconds(300)
)

// Careful search with longer delay (good for expensive operations)
let carefulSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 8,
    debounceSearchDelay: .milliseconds(500)
)
```

### Use Case Specific Configurations

```swift
// For address autocomplete
let addressSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 6,  // Wait for partial address
    debounceSearchDelay: .milliseconds(400) // Longer delay for typing addresses
)

// For POI (Point of Interest) search
let poiSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 3,  // Start early for business names
    debounceSearchDelay: .milliseconds(200) // Quick feedback
)

// For international search
let internationalSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 7,  // Allow for longer place names
    debounceSearchDelay: .milliseconds(350)
)
```

## Managing Concurrent Searches

### Search Cancellation and Task Management

```swift
@MainActor
class AdvancedSearchController: ObservableObject {
    @Published var searchResults: [LocalSearchCompletion] = []
    @Published var isSearching = false
    
    private let locationSearch = LocationSearch()
    private var currentSearchTask: Task<Void, Never>?
    private var searchCache: [String: [LocalSearchCompletion]] = [:]
    
    func performSearch(_ query: String) {
        // Cancel any existing search
        currentSearchTask?.cancel()
        
        // Check cache first
        if let cachedResults = searchCache[query] {
            searchResults = cachedResults
            return
        }
        
        currentSearchTask = Task {
            await executeSearch(query)
        }
    }
    
    private func executeSearch(_ query: String) async {
        isSearching = true
        
        do {
            let results = try await locationSearch.search(queryFragment: query)
            
            // Only update if this search wasn't cancelled
            guard !Task.isCancelled else { return }
            
            searchResults = results
            searchCache[query] = results
            
        } catch LocationSearchError.debounce {
            // Expected during rapid typing
        } catch {
            // Handle other errors
            if !Task.isCancelled {
                searchResults = []
            }
        }
        
        isSearching = false
    }
    
    func cancelCurrentSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
        isSearching = false
    }
}
```

### Multiple Search Instances

For complex applications, you might need multiple search instances:

```swift
class MultiContextSearchManager {
    // Different search instances for different contexts
    private let quickSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 2,
        debounceSearchDelay: .milliseconds(100)
    )
    
    private let detailedSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 5,
        debounceSearchDelay: .milliseconds(400)
    )
    
    private let backgroundSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 3,
        debounceSearchDelay: .milliseconds(200)
    )
    
    // Quick suggestions for autocomplete
    func getQuickSuggestions(_ query: String) async throws -> [LocalSearchCompletion] {
        return try await quickSearch.search(queryFragment: query)
    }
    
    // Detailed search for main results
    func getDetailedResults(_ query: String) async throws -> [LocalSearchCompletion] {
        return try await detailedSearch.search(queryFragment: query)
    }
    
    // Background search for preloading
    func preloadSuggestions(_ query: String) async {
        try? await backgroundSearch.search(queryFragment: query)
    }
}
```

## Performance Optimization

### Result Caching

Implement intelligent caching for better performance:

```swift
actor SearchCache {
    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize = 100
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    struct CacheEntry {
        let results: [LocalSearchCompletion]
        let timestamp: Date
    }
    
    func getResults(for query: String) -> [LocalSearchCompletion]? {
        guard let entry = cache[query] else { return nil }
        
        // Check if cache entry is still valid
        if Date().timeIntervalSince(entry.timestamp) > cacheTimeout {
            cache.removeValue(forKey: query)
            return nil
        }
        
        return entry.results
    }
    
    func setResults(_ results: [LocalSearchCompletion], for query: String) {
        // Implement LRU cache behavior
        if cache.count >= maxCacheSize {
            // Remove oldest entry
            let oldestKey = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let keyToRemove = oldestKey {
                cache.removeValue(forKey: keyToRemove)
            }
        }
        
        cache[query] = CacheEntry(results: results, timestamp: Date())
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

@MainActor
class CachedSearchController: ObservableObject {
    @Published var searchResults: [LocalSearchCompletion] = []
    
    private let locationSearch = LocationSearch()
    private let cache = SearchCache()
    
    func performSearch(_ query: String) async {
        // Check cache first
        if let cachedResults = await cache.getResults(for: query) {
            searchResults = cachedResults
            return
        }
        
        do {
            let results = try await locationSearch.search(queryFragment: query)
            searchResults = results
            
            // Cache the results
            await cache.setResults(results, for: query)
            
        } catch LocationSearchError.debounce {
            // Ignore debounced searches
        } catch {
            searchResults = []
        }
    }
}
```

### Placemark Caching

Cache placemark details to avoid repeated API calls:

```swift
actor PlacemarkCache {
    private var placemarkCache: [String: Placemark] = [:]
    
    func getPlacemark(for completion: LocalSearchCompletion) -> Placemark? {
        return placemarkCache[completion.id]
    }
    
    func setPlacemark(_ placemark: Placemark, for completion: LocalSearchCompletion) {
        placemarkCache[completion.id] = placemark
    }
}

class OptimizedLocationService {
    private let locationSearch = LocationSearch()
    private let placemarkCache = PlacemarkCache()
    
    func getPlacemark(for completion: LocalSearchCompletion) async throws -> Placemark? {
        // Check cache first
        if let cachedPlacemark = await placemarkCache.getPlacemark(for: completion) {
            return cachedPlacemark
        }
        
        // Fetch from API
        let placemark = try await locationSearch.placemark(for: completion)
        
        // Cache the result
        if let placemark = placemark {
            await placemarkCache.setPlacemark(placemark, for: completion)
        }
        
        return placemark
    }
}
```

## Advanced Search Patterns

### Progressive Search

Implement progressive search that shows different types of results as the user types:

```swift
@MainActor
class ProgressiveSearchController: ObservableObject {
    @Published var quickResults: [LocalSearchCompletion] = []
    @Published var detailedResults: [LocalSearchCompletion] = []
    @Published var searchPhase: SearchPhase = .initial
    
    enum SearchPhase {
        case initial
        case quickSearch
        case detailedSearch
        case complete
    }
    
    private let quickSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 2,
        debounceSearchDelay: .milliseconds(100)
    )
    
    private let detailedSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 5,
        debounceSearchDelay: .milliseconds(300)
    )
    
    func performProgressiveSearch(_ query: String) async {
        let characterCount = query.count
        
        if characterCount >= 2 && characterCount < 5 {
            searchPhase = .quickSearch
            await performQuickSearch(query)
        } else if characterCount >= 5 {
            searchPhase = .detailedSearch
            await performDetailedSearch(query)
        } else {
            searchPhase = .initial
            quickResults = []
            detailedResults = []
        }
    }
    
    private func performQuickSearch(_ query: String) async {
        do {
            let results = try await quickSearch.search(queryFragment: query)
            quickResults = results
        } catch {
            quickResults = []
        }
    }
    
    private func performDetailedSearch(_ query: String) async {
        do {
            let results = try await detailedSearch.search(queryFragment: query)
            detailedResults = results
            searchPhase = .complete
        } catch {
            detailedResults = []
        }
    }
}
```

### Parallel Search Strategies

Search multiple contexts simultaneously:

```swift
class ParallelSearchController {
    private let primarySearch = LocationSearch()
    private let secondarySearch = LocationSearch(
        numberOfCharactersBeforeSearching: 3,
        debounceSearchDelay: .milliseconds(200)
    )
    
    func performParallelSearch(_ query: String) async -> SearchResults {
        async let primaryResults = searchWithFallback(primarySearch, query: query)
        async let secondaryResults = searchWithFallback(secondarySearch, query: query)
        
        let (primary, secondary) = await (primaryResults, secondaryResults)
        
        return SearchResults(
            primary: primary,
            secondary: secondary,
            combined: mergeDeduplicated(primary: primary, secondary: secondary)
        )
    }
    
    private func searchWithFallback(
        _ search: LocationSearch,
        query: String
    ) async -> [LocalSearchCompletion] {
        do {
            return try await search.search(queryFragment: query)
        } catch {
            return []
        }
    }
    
    private func mergeDeduplicated(
        primary: [LocalSearchCompletion],
        secondary: [LocalSearchCompletion]
    ) -> [LocalSearchCompletion] {
        var seen = Set<String>()
        var result: [LocalSearchCompletion] = []
        
        // Add primary results first
        for completion in primary {
            if !seen.contains(completion.id) {
                seen.insert(completion.id)
                result.append(completion)
            }
        }
        
        // Add secondary results that aren't duplicates
        for completion in secondary {
            if !seen.contains(completion.id) {
                seen.insert(completion.id)
                result.append(completion)
            }
        }
        
        return result
    }
}

struct SearchResults {
    let primary: [LocalSearchCompletion]
    let secondary: [LocalSearchCompletion]
    let combined: [LocalSearchCompletion]
}
```

## Memory Management

### Automatic Cleanup

Implement automatic cleanup for long-running applications:

```swift
@MainActor
class ManagedSearchController: ObservableObject {
    @Published var searchResults: [LocalSearchCompletion] = []
    
    private let locationSearch = LocationSearch()
    private var cleanupTimer: Timer?
    private var lastSearchTime = Date()
    
    init() {
        setupCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.performCleanupIfNeeded()
            }
        }
    }
    
    private func performCleanupIfNeeded() {
        let timeSinceLastSearch = Date().timeIntervalSince(lastSearchTime)
        
        // Clear results if no search activity for 5 minutes
        if timeSinceLastSearch > 300 {
            searchResults = []
        }
    }
    
    func performSearch(_ query: String) async {
        lastSearchTime = Date()
        
        do {
            let results = try await locationSearch.search(queryFragment: query)
            searchResults = results
        } catch {
            searchResults = []
        }
    }
}
```

## Performance Monitoring

### Search Analytics

Track search performance and usage patterns:

```swift
struct SearchMetrics {
    let query: String
    let resultCount: Int
    let searchDuration: TimeInterval
    let wasSuccessful: Bool
    let errorType: String?
    let timestamp: Date
}

class SearchAnalytics {
    private var metrics: [SearchMetrics] = []
    
    func recordSearch(
        query: String,
        resultCount: Int,
        duration: TimeInterval,
        error: Error? = nil
    ) {
        let metric = SearchMetrics(
            query: query,
            resultCount: resultCount,
            searchDuration: duration,
            wasSuccessful: error == nil,
            errorType: error?.localizedDescription,
            timestamp: Date()
        )
        
        metrics.append(metric)
        
        // Limit stored metrics
        if metrics.count > 1000 {
            metrics.removeFirst(100)
        }
    }
    
    func getAverageSearchTime() -> TimeInterval {
        guard !metrics.isEmpty else { return 0 }
        let totalTime = metrics.reduce(0) { $0 + $1.searchDuration }
        return totalTime / Double(metrics.count)
    }
    
    func getSuccessRate() -> Double {
        guard !metrics.isEmpty else { return 0 }
        let successCount = metrics.filter { $0.wasSuccessful }.count
        return Double(successCount) / Double(metrics.count)
    }
}

class InstrumentedSearchController {
    private let locationSearch = LocationSearch()
    private let analytics = SearchAnalytics()
    
    func performSearch(_ query: String) async -> [LocalSearchCompletion] {
        let startTime = Date()
        
        do {
            let results = try await locationSearch.search(queryFragment: query)
            
            analytics.recordSearch(
                query: query,
                resultCount: results.count,
                duration: Date().timeIntervalSince(startTime)
            )
            
            return results
            
        } catch {
            analytics.recordSearch(
                query: query,
                resultCount: 0,
                duration: Date().timeIntervalSince(startTime),
                error: error
            )
            
            return []
        }
    }
}
```

## Best Practices Summary

### Configuration
- Choose appropriate character thresholds based on your use case
- Adjust debounce delays based on user expectations
- Consider multiple search instances for different contexts

### Performance
- Implement result caching for frequently searched terms
- Cache placemark details to avoid repeated API calls
- Monitor and limit memory usage in long-running applications

### Concurrency
- Always cancel previous searches when starting new ones
- Use proper task management to avoid memory leaks
- Handle cancellation gracefully in your UI

### Monitoring
- Track search performance and success rates
- Monitor for patterns in failed searches
- Use analytics to optimize search configuration

## Next Steps

- **<doc:PlatformDifferences>** - Learn about iOS and macOS specific features
- **<doc:ErrorHandling>** - Review comprehensive error handling strategies
- **<doc:WorkingWithSearchResults>** - Understand result display and interaction patterns