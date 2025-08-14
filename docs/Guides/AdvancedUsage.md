# Advanced Usage Guide

## Overview

This guide covers advanced patterns and techniques for using MapKitSwiftSearch in complex applications. These examples demonstrate how to handle sophisticated use cases while maintaining performance and reliability.

## Advanced Search Patterns

### 1. Batch Location Processing

When you need to search for multiple locations efficiently:

```swift
@MainActor
class BatchLocationSearcher {
    private let locationSearch = LocationSearch()
    private let maxConcurrentSearches = 3
    
    /// Searches for multiple locations with controlled concurrency
    func searchMultipleLocations(_ queries: [String]) async -> [String: [LocalSearchCompletion]] {
        var results: [String: [LocalSearchCompletion]] = [:]
        
        // Process queries in batches to avoid overwhelming the API
        for queryBatch in queries.chunked(into: maxConcurrentSearches) {
            await withTaskGroup(of: (String, [LocalSearchCompletion]).self) { group in
                for query in queryBatch {
                    group.addTask { [weak self] in
                        guard let self = self else { return (query, []) }
                        
                        do {
                            let completions = try await self.locationSearch.search(queryFragment: query)
                            return (query, completions)
                        } catch {
                            print("Failed to search '\(query)': \(error)")
                            return (query, [])
                        }
                    }
                }
                
                for await (query, completions) in group {
                    results[query] = completions
                }
            }
        }
        
        return results
    }
}

// Extension for array chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

### 2. Smart Caching with Expiration

Implement intelligent caching to reduce API calls while maintaining data freshness:

```swift
@MainActor
class CachedLocationSearch {
    private let locationSearch = LocationSearch()
    private let cache = NSCache<NSString, CachedSearchResult>()
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    init() {
        cache.countLimit = 100 // Limit cache size
    }
    
    func search(queryFragment: String) async throws -> [LocalSearchCompletion] {
        let cacheKey = NSString(string: queryFragment.lowercased())
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey),
           !cached.isExpired {
            print("Cache hit for query: \(queryFragment)")
            return cached.results
        }
        
        // Perform fresh search
        let results = try await locationSearch.search(queryFragment: queryFragment)
        
        // Cache the results
        let cachedResult = CachedSearchResult(
            results: results,
            timestamp: Date()
        )
        cache.setObject(cachedResult, forKey: cacheKey)
        
        return results
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

class CachedSearchResult {
    let results: [LocalSearchCompletion]
    let timestamp: Date
    
    init(results: [LocalSearchCompletion], timestamp: Date) {
        self.results = results
        self.timestamp = timestamp
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}
```

### 3. Progressive Search Enhancement

Implement a search system that progressively enhances results:

```swift
@MainActor
class ProgressiveLocationSearch: ObservableObject {
    @Published var results: [EnhancedSearchResult] = []
    @Published var isSearching = false
    
    private let locationSearch = LocationSearch()
    private var enhancementTasks: [String: Task<Void, Never>] = [:]
    
    func search(queryFragment: String) async {
        isSearching = true
        
        do {
            // Phase 1: Get basic search completions
            let completions = try await locationSearch.search(queryFragment: queryFragment)
            
            // Convert to enhanced results with basic info
            results = completions.map { completion in
                EnhancedSearchResult(
                    completion: completion,
                    placemark: nil,
                    distance: nil,
                    isEnhancing: true
                )
            }
            
            // Phase 2: Enhance results with detailed information
            await enhanceResults()
            
        } catch {
            print("Search failed: \(error)")
            results = []
        }
        
        isSearching = false
    }
    
    private func enhanceResults() async {
        // Cancel previous enhancement tasks
        enhancementTasks.values.forEach { $0.cancel() }
        enhancementTasks.removeAll()
        
        // Enhance each result concurrently
        for (index, result) in results.enumerated() {
            let task = Task { [weak self] in
                await self?.enhanceResult(at: index, result: result)
            }
            enhancementTasks[result.completion.id] = task
        }
        
        // Wait for all enhancements to complete
        for task in enhancementTasks.values {
            await task.value
        }
    }
    
    private func enhanceResult(at index: Int, result: EnhancedSearchResult) async {
        do {
            // Get detailed placemark information
            let placemark = try await locationSearch.placemark(for: result.completion)
            
            // Calculate distance if we have user location
            let distance = calculateDistance(to: placemark)
            
            // Update the result
            let enhancedResult = EnhancedSearchResult(
                completion: result.completion,
                placemark: placemark,
                distance: distance,
                isEnhancing: false
            )
            
            // Update on main thread
            if index < results.count {
                results[index] = enhancedResult
            }
            
        } catch {
            print("Failed to enhance result: \(error)")
            // Mark as not enhancing even if failed
            if index < results.count {
                results[index] = EnhancedSearchResult(
                    completion: result.completion,
                    placemark: nil,
                    distance: nil,
                    isEnhancing: false
                )
            }
        }
    }
    
    private func calculateDistance(to placemark: Placemark?) -> CLLocationDistance? {
        // Implementation would calculate distance to user's current location
        // This is a placeholder
        return nil
    }
}

struct EnhancedSearchResult: Identifiable {
    let id: String
    let completion: LocalSearchCompletion
    let placemark: Placemark?
    let distance: CLLocationDistance?
    let isEnhancing: Bool
    
    init(completion: LocalSearchCompletion, placemark: Placemark?, distance: CLLocationDistance?, isEnhancing: Bool) {
        self.id = completion.id
        self.completion = completion
        self.placemark = placemark
        self.distance = distance
        self.isEnhancing = isEnhancing
    }
}
```

## Error Recovery and Resilience

### 1. Exponential Backoff with Circuit Breaker

Implement robust error recovery for network failures:

```swift
@MainActor
class ResilientLocationSearch {
    private let locationSearch = LocationSearch()
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let maxFailures = 5
    private let circuitBreakerTimeout: TimeInterval = 60 // 1 minute
    
    enum CircuitState {
        case closed    // Normal operation
        case open      // Circuit breaker tripped
        case halfOpen  // Testing if service is back
    }
    
    private var circuitState: CircuitState = .closed
    
    func search(queryFragment: String) async throws -> [LocalSearchCompletion] {
        // Check circuit breaker
        switch circuitState {
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > circuitBreakerTimeout {
                circuitState = .halfOpen
            } else {
                throw LocationSearchError.searchCompletionFailed
            }
            
        case .halfOpen:
            // Allow one request through to test service
            break
            
        case .closed:
            // Normal operation
            break
        }
        
        do {
            let results = try await searchWithRetry(queryFragment: queryFragment)
            
            // Success - reset failure count and close circuit
            failureCount = 0
            circuitState = .closed
            lastFailureTime = nil
            
            return results
            
        } catch {
            // Handle failure
            failureCount += 1
            lastFailureTime = Date()
            
            if failureCount >= maxFailures {
                circuitState = .open
            }
            
            throw error
        }
    }
    
    private func searchWithRetry(queryFragment: String, attempt: Int = 1) async throws -> [LocalSearchCompletion] {
        let maxRetries = 3
        
        do {
            return try await locationSearch.search(queryFragment: queryFragment)
        } catch LocationSearchError.mapKitError(let mkError) where mkError.code == .networkFailure && attempt < maxRetries {
            // Exponential backoff: 1s, 2s, 4s
            let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
            try await Task.sleep(for: .seconds(delay))
            
            return try await searchWithRetry(queryFragment: queryFragment, attempt: attempt + 1)
        } catch {
            throw error
        }
    }
}
```

### 2. Graceful Degradation

Provide fallback functionality when services are unavailable:

```swift
@MainActor
class GracefulLocationSearch {
    private let primarySearch = LocationSearch()
    private let fallbackResults: [LocalSearchCompletion] = [
        // Pre-defined popular locations as fallback
    ]
    
    func search(queryFragment: String) async -> SearchResult {
        do {
            let results = try await primarySearch.search(queryFragment: queryFragment)
            return SearchResult(completions: results, source: .live, isComplete: true)
            
        } catch LocationSearchError.mapKitError(let mkError) where mkError.code == .networkFailure {
            // Network failure - provide cached/offline results
            let filtered = fallbackResults.filter { completion in
                completion.title.localizedCaseInsensitiveContains(queryFragment) ||
                completion.subTitle.localizedCaseInsensitiveContains(queryFragment)
            }
            return SearchResult(completions: filtered, source: .cached, isComplete: false)
            
        } catch LocationSearchError.invalidSearchCriteria {
            // Invalid input - provide empty results with guidance
            return SearchResult(completions: [], source: .guidance, isComplete: true)
            
        } catch {
            // Other errors - provide fallback
            return SearchResult(completions: [], source: .error, isComplete: false)
        }
    }
}

struct SearchResult {
    let completions: [LocalSearchCompletion]
    let source: SearchSource
    let isComplete: Bool
}

enum SearchSource {
    case live      // Real-time API results
    case cached    // Cached/offline results
    case guidance  // User guidance needed
    case error     // Error state
}
```

## Performance Optimization

### 1. Search Request Coalescing

Combine rapid search requests to improve efficiency:

```swift
@MainActor
class CoalescedLocationSearch {
    private let locationSearch = LocationSearch()
    private var pendingRequests: [String: [CheckedContinuation<[LocalSearchCompletion], Error>]] = [:]
    
    func search(queryFragment: String) async throws -> [LocalSearchCompletion] {
        // Check if there's already a request for this query
        if pendingRequests[queryFragment] != nil {
            // Join the existing request
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests[queryFragment, default: []].append(continuation)
            }
        }
        
        // Start new request
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[queryFragment] = [continuation]
            
            Task {
                do {
                    let results = try await locationSearch.search(queryFragment: queryFragment)
                    
                    // Notify all waiting continuations
                    let waitingContinuations = pendingRequests.removeValue(forKey: queryFragment) ?? []
                    for waitingContinuation in waitingContinuations {
                        waitingContinuation.resume(returning: results)
                    }
                    
                } catch {
                    // Notify all waiting continuations of the error
                    let waitingContinuations = pendingRequests.removeValue(forKey: queryFragment) ?? []
                    for waitingContinuation in waitingContinuations {
                        waitingContinuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
```

### 2. Memory-Efficient Result Streaming

Handle large result sets efficiently:

```swift
@MainActor
class StreamingLocationSearch {
    private let locationSearch = LocationSearch()
    
    func searchStream(queryFragment: String) -> AsyncThrowingStream<LocalSearchCompletion, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let results = try await locationSearch.search(queryFragment: queryFragment)
                    
                    // Stream results one at a time
                    for result in results {
                        continuation.yield(result)
                        
                        // Optional: Add small delay to allow UI updates
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// Usage example
class StreamingSearchViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    private let streamingSearch = StreamingLocationSearch()
    private var searchResults: [LocalSearchCompletion] = []
    
    @MainActor
    private func performStreamingSearch(query: String) async {
        searchResults.removeAll()
        tableView.reloadData()
        
        do {
            for try await completion in streamingSearch.searchStream(queryFragment: query) {
                searchResults.append(completion)
                
                // Update UI incrementally
                let indexPath = IndexPath(row: searchResults.count - 1, section: 0)
                tableView.insertRows(at: [indexPath], with: .fade)
            }
        } catch {
            showError(error)
        }
    }
}
```

## Integration Patterns

### 1. Custom Search Result Ranking

Implement custom ranking logic on top of MapKit results:

```swift
@MainActor
class RankedLocationSearch {
    private let locationSearch = LocationSearch()
    private let userLocation: CLLocation?
    
    init(userLocation: CLLocation? = nil) {
        self.userLocation = userLocation
    }
    
    func search(queryFragment: String, preferences: SearchPreferences = .default) async throws -> [RankedSearchResult] {
        let completions = try await locationSearch.search(queryFragment: queryFragment)
        
        // Get detailed information for ranking
        let detailedResults = await withTaskGroup(of: RankedSearchResult?.self) { group in
            var results: [RankedSearchResult] = []
            
            for completion in completions {
                group.addTask { [weak self] in
                    await self?.createRankedResult(completion: completion, preferences: preferences)
                }
            }
            
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            return results
        }
        
        // Sort by rank score
        return detailedResults.sorted { $0.rankScore > $1.rankScore }
    }
    
    private func createRankedResult(completion: LocalSearchCompletion, preferences: SearchPreferences) async -> RankedSearchResult? {
        do {
            let placemark = try await locationSearch.placemark(for: completion)
            let distance = calculateDistance(to: placemark)
            let rankScore = calculateRankScore(
                completion: completion,
                placemark: placemark,
                distance: distance,
                preferences: preferences
            )
            
            return RankedSearchResult(
                completion: completion,
                placemark: placemark,
                distance: distance,
                rankScore: rankScore
            )
            
        } catch {
            return nil
        }
    }
    
    private func calculateDistance(to placemark: Placemark?) -> CLLocationDistance? {
        guard let userLocation = userLocation,
              let placemark = placemark else { return nil }
        
        let placemarkLocation = CLLocation(
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
        
        return userLocation.distance(from: placemarkLocation)
    }
    
    private func calculateRankScore(
        completion: LocalSearchCompletion,
        placemark: Placemark?,
        distance: CLLocationDistance?,
        preferences: SearchPreferences
    ) -> Double {
        var score = 100.0 // Base score
        
        // Distance factor
        if let distance = distance {
            let distanceKm = distance / 1000.0
            score += max(0, 50 - distanceKm) * preferences.distanceWeight
        }
        
        // Name match quality
        if completion.titleHighlightRange != nil {
            score += 20 * preferences.nameMatchWeight
        }
        
        // Address completeness
        if let placemark = placemark {
            let addressCompleteness = [
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea
            ].compactMap { $0 }.count
            
            score += Double(addressCompleteness) * 5 * preferences.addressCompletenessWeight
        }
        
        return score
    }
}

struct RankedSearchResult {
    let completion: LocalSearchCompletion
    let placemark: Placemark?
    let distance: CLLocationDistance?
    let rankScore: Double
}

struct SearchPreferences {
    let distanceWeight: Double
    let nameMatchWeight: Double
    let addressCompletenessWeight: Double
    
    static let `default` = SearchPreferences(
        distanceWeight: 1.0,
        nameMatchWeight: 1.5,
        addressCompletenessWeight: 0.5
    )
}
```

### 2. Multi-Platform Search Coordination

Coordinate search across multiple platforms and services:

```swift
protocol SearchProvider {
    func search(queryFragment: String) async throws -> [LocalSearchCompletion]
}

@MainActor
class AggregatedLocationSearch {
    private let providers: [SearchProvider]
    private let maxResultsPerProvider: Int
    
    init(providers: [SearchProvider], maxResultsPerProvider: Int = 10) {
        self.providers = providers
        self.maxResultsPerProvider = maxResultsPerProvider
    }
    
    func search(queryFragment: String) async throws -> [LocalSearchCompletion] {
        let results = await withTaskGroup(of: [LocalSearchCompletion].self) { group in
            var allResults: [LocalSearchCompletion] = []
            
            for provider in providers {
                group.addTask {
                    do {
                        let results = try await provider.search(queryFragment: queryFragment)
                        return Array(results.prefix(self.maxResultsPerProvider))
                    } catch {
                        print("Provider failed: \(error)")
                        return []
                    }
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
            
            return allResults
        }
        
        // Deduplicate and merge results
        return deduplicateResults(results)
    }
    
    private func deduplicateResults(_ results: [LocalSearchCompletion]) -> [LocalSearchCompletion] {
        var seen = Set<String>()
        return results.filter { completion in
            let key = "\(completion.title)-\(completion.subTitle)".lowercased()
            return seen.insert(key).inserted
        }
    }
}

// Implementation for MapKitSwiftSearch
extension LocationSearch: SearchProvider {
    // Already conforms through existing search method
}
```

This advanced usage guide demonstrates sophisticated patterns for building robust, performant applications with MapKitSwiftSearch. These techniques help handle complex real-world scenarios while maintaining the clean, concurrent design principles of the library.