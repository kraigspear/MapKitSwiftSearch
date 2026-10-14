# Testing Strategies and Patterns

## Overview

This document outlines the comprehensive testing strategies used in MapKitSwiftSearch, explaining both the implemented tests and the reasoning behind the testing approach. The testing philosophy emphasizes reliability, maintainability, and real-world scenario coverage.

## Testing Philosophy

### Core Principles

1. **Test Behavior, Not Implementation**: Focus on what the code does, not how it does it
2. **Fast Feedback Loops**: Tests should run quickly to enable frequent execution
3. **Realistic Scenarios**: Tests should reflect actual usage patterns
4. **Regression Prevention**: Critical bugs should have specific tests to prevent reoccurrence
5. **Maintainable Test Code**: Test code should be as clean and well-structured as production code

### Testing Pyramid

```mermaid
graph TD
    A[Integration Tests<br/>Real MapKit Integration] --> B[Component Tests<br/>Individual Class Testing]
    B --> C[Unit Tests<br/>Pure Function Testing]
    C --> D[Property Tests<br/>Edge Case Coverage]

    style A fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#ffffff
    style B fill:#ed8936,stroke:#c05621,stroke-width:2px,color:#ffffff
    style C fill:#38a169,stroke:#2f855a,stroke-width:2px,color:#ffffff
    style D fill:#2b6cb1,stroke:#1a365d,stroke-width:2px,color:#ffffff
```

## Current Test Implementation

### 1. LocationSearch Integration Tests

`MapKitSwiftSearchTests.swift` runs end-to-end tests against real MapKit services. Behavior that depends on timing or MapKit failures is covered by unit tests with fakes (section 6).

```swift
@MainActor
struct LocationSearchTest {
    @Test("Successful search")
    func successfulSearch() async throws {
        let locationSearch = LocationSearch()
        let localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan, In")

        #expect(!localSearchCompletions.isEmpty, "Expected results")
        let foundLocation = localSearchCompletions.first { $0.title == "Sheridan, IN" }
        #expect(foundLocation != nil, "Didn't find Sheridan")
    }
}
```

**Why This Approach**:
- **Real Data**: Tests against actual MapKit services to catch integration issues
- **End-to-End Validation**: Verifies the complete search flow including networking
- **Realistic Results**: Uses real location data that users would encounter

### 2. Concurrency and Cancellation Tests

Tests verify proper behavior under concurrent access patterns:

```swift
@Test("If a search is in progress, cancel if we get another search request")
func multipleSearches() async throws {
    let locationSearch = LocationSearch(debounceSearchDelay: .milliseconds(200))

    let search1 = Task {
        await #expect(throws: LocationSearchError.debounce) {
            _ = try await locationSearch.search(queryFragment: "Sheridan, In")
        }
    }

    try await Task.sleep(for: .milliseconds(50))

    do {
        _ = try await locationSearch.search(queryFragment: "Caledonia, Mi")
    } catch {
        print("task2 cancelled")
    }

    _ = await search1.value
}
```

**Key Testing Patterns**:
- **Concurrent Execution**: Starts the first search in a `Task` so the second overlaps it
- **Cancellation Verification**: Confirms the earlier call loses its debounce and throws `.debounce`
- **Race Condition Prevention**: Validates that the system handles overlapping requests correctly

### 3. Edge Case Coverage

Tests handle boundary conditions and edge cases:

```swift
@Test("Results cleared when searching empty query")
func resultsClearedWhenSearchingEmptyQuery() async throws {
    let locationSearch = LocationSearch()
    var localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan, In")
    #expect(!localSearchCompletions.isEmpty, "Expected results")

    localSearchCompletions = try await locationSearch.search(queryFragment: "")
    #expect(localSearchCompletions.isEmpty, "Results should be cleared")
}
```

### 4. Validation Logic Tests

Tests verify input validation and error handling:

```swift
@Test("Not searching with less than 5 characters")
func notEnoughCharactersToSearch() async throws {
    let locationSearch = LocationSearch(numberOfCharactersBeforeSearching: 5)

    await #expect(throws: LocationSearchError.invalidSearchCriteria) {
        _ = try await locationSearch.search(queryFragment: "S")
    }
}
```

### 5. Regression Prevention Tests

Specific tests prevent known bugs from reoccurring:

```swift
@Test("Verify highlightedSubTitle uses correct highlight range")
func verifyHighlightedSubTitleUsesCorrectRange() {
    let subtitleRange = NSRange(location: 4, length: 4)
    let completion = LocalSearchCompletion(
        title: "Pizza Place",
        subTitle: "123 Main Street",
        titleHighlightRange: HighlightRange(nsRange: NSRange(location: 0, length: 3)),
        subtitleHighlightRange: HighlightRange(nsRange: subtitleRange),
    )

    let attributedSubtitle = completion.highlightedSubTitle(foregroundColor: .red, highlightColor: .blue)
    let nsAttributed = NSAttributedString(attributedSubtitle)

    // The highlight color must start at subtitleHighlightRange, not titleHighlightRange
    var highlightRange = NSRange()
    _ = nsAttributed.attribute(.foregroundColor, at: subtitleRange.location, effectiveRange: &highlightRange)
    #expect(highlightRange == subtitleRange)
}
```

**Why Distinct Ranges**:
- **Copy-Paste Error Prevention**: Platform-specific code is prone to copy-paste errors
- **Behavior, Not Source**: Title and subtitle ranges differ, so using the wrong one changes where the color lands
- **Documentation**: Test name clearly describes what was fixed

### 6. Unit Tests with Injected Fakes

`LocationSearchUnitTests` builds `LocationSearch` through its internal initializer, which takes a completer factory, a local-search factory, and `debounceSleep`. `FakeSearchCompleter` and `FakeLocalSearch` stand in for MapKit, so tests can deliver results or failures at a chosen moment:

```swift
@Test("Search completer errors map to searchCompletionFailed")
func searchCompleterErrorMapsToSearchCompletionFailed() async throws {
    let fakeCompleter = FakeSearchCompleter()
    let locationSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 1,
        debounceSearchDelay: .milliseconds(1),
        completerFactory: { fakeCompleter },
        localSearchFactory: { _ in FakeLocalSearch() },
    )

    fakeCompleter.onQueryFragmentSet = { _ in
        fakeCompleter.sendError(NSError(domain: "MapKitSwiftSearchTests", code: 1))
    }
    // ... expect LocationSearchError.searchCompletionFailed
}
```

These tests cover what real MapKit can't reproduce on demand: completer failures, `placemark(for:)` error mapping, a newer call superseding an in-flight search, and MapKit answering a search after it was superseded.

## Advanced Testing Strategies

### 1. Property-Based Testing

Test invariant properties across a wide range of inputs:

```swift
// Example property-based test (not currently implemented)
@Test("Search results maintain ordering consistency")
func searchResultsOrderingProperty() async throws {
    let locationSearch = LocationSearch()
    let queries = generateRandomQueries(count: 100)
    
    for query in queries {
        do {
            let results = try await locationSearch.search(queryFragment: query)
            
            // Property: Results should be consistently ordered
            let secondResults = try await locationSearch.search(queryFragment: query)
            #expect(results.map(\.id) == secondResults.map(\.id), 
                   "Results should be consistently ordered for query: \(query)")
                   
        } catch LocationSearchError.invalidSearchCriteria {
            // Expected for short queries
            continue
        }
    }
}
```

### 2. Performance Testing

Measure and validate performance characteristics:

```swift
// Example performance test (not currently implemented)
@Test("Search performance under load")
func searchPerformanceUnderLoad() async throws {
    let locationSearch = LocationSearch()
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // Simulate rapid user typing
    let queries = ["C", "Co", "Cof", "Coff", "Coffe", "Coffee"]
    
    for query in queries {
        do {
            _ = try await locationSearch.search(queryFragment: query)
        } catch LocationSearchError.invalidSearchCriteria {
            // Expected for short queries
        }
    }
    
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    #expect(timeElapsed < 5.0, "Search sequence should complete within 5 seconds")
}
```

## Test Data Management

### 1. Test Location Selection

Current tests use specific, stable locations:

```swift
// Good test locations (used in current tests):
// - "Sheridan, IN" - Small town with consistent results
// - "Caledonia, MI" - Another small town for variety
// - "Pensacola, FL" - Larger city for different result patterns

// Why these locations:
// 1. Stable over time (unlikely to change)
// 2. Unique names (unlikely to have ambiguous results)
// 3. Different geographic regions for variety
// 4. Different population sizes for result diversity
```

### 2. Test Result Validation

Strategies for validating search results:

```swift
// Pattern 1: Exact Match Validation
let foundLocation = localSearchCompletions.first { $0.title == "Sheridan, IN" }
#expect(foundLocation != nil, "Didn't find exact match")

// Pattern 2: Fuzzy Match Validation
let hasExpectedResult = localSearchCompletions.contains { completion in
    completion.title.contains("Sheridan") && completion.subTitle.contains("IN")
}
#expect(hasExpectedResult, "Should find location containing expected terms")

// Pattern 3: Structure Validation
#expect(!localSearchCompletions.isEmpty, "Should return some results")
#expect(localSearchCompletions.count <= 10, "Should limit result count")
```

## Error Testing Strategies

### 1. Comprehensive Error Coverage

Test all error cases systematically:

```swift
@Test("Debounce error handling")
func debounceErrorHandling() async throws {
    let locationSearch = LocationSearch()
    
    let task1 = Task {
        await #expect(throws: LocationSearchError.debounce) {
            _ = try await locationSearch.search(queryFragment: "Pensacola, FL")
        }
    }
    
    let task2 = Task {
        _ = try await locationSearch.search(queryFragment: "Sheridan, In")
    }
    
    await task1.value
    try await task2.value
}
```

### 2. Network Error Simulation

Testing network failure scenarios:

```swift
// Future enhancement: Network condition testing
@Test("Network failure handling")
func networkFailureHandling() async throws {
    // Would require network mocking or simulation
    // This is a placeholder for future implementation
}
```

## Test Organization Patterns

### 1. Nested Test Structures

Current organization uses nested structures for clarity:

```swift
@MainActor
struct LocationSearchTest {
    @MainActor
    struct Search {
        // All search-related tests
    }
    
    @MainActor 
    struct Select {
        // All placemark selection tests
    }
}
```

**Benefits**:
- **Logical Grouping**: Related tests are grouped together
- **Clear Navigation**: Easy to find specific test categories
- **Maintainable**: New tests can be added to appropriate groups

### 2. Test Naming Conventions

Clear, descriptive test names:

```swift
// Good: Describes what and expected outcome
@Test("Successful search")
@Test("If a search is in progress, cancel if we get another search request")
@Test("Results cleared when searching empty query")

// Pattern: [Action] + [Expected Outcome]
// Or: [Condition] + [Expected Behavior]
```

## Testing Anti-Patterns to Avoid

### 1. Over-Mocking

**Problem**: Mocking everything can make tests meaningless
```swift
// Avoid: Testing mock behavior instead of real behavior
let mockCompleter = MockMKLocalSearchCompleter()
mockCompleter.results = [mockResult]
// This tests the mock, not the real integration
```

**Solution**: Use integration tests for critical paths, mocks for specific scenarios

### 2. Brittle Tests

**Problem**: Tests that break with minor changes
```swift
// Avoid: Testing exact result counts or order
#expect(results.count == 5, "Should return exactly 5 results")
// MapKit results can vary over time
```

**Solution**: Test properties that should remain stable

### 3. Test Interdependence

**Problem**: Tests that depend on other tests running first
```swift
// Avoid: Shared state between tests
static var cachedResults: [LocalSearchCompletion] = []
```

**Solution**: Each test should be independent and self-contained

## Future Testing Enhancements

### 1. Automated Performance Regression Detection

```swift
// Benchmark tests to detect performance regressions
@Test("Search latency benchmark")
func searchLatencyBenchmark() async throws {
    let locationSearch = LocationSearch()
    
    measure {
        _ = try await locationSearch.search(queryFragment: "Coffee shops")
    }
}
```

### 2. Chaos Testing

```swift
// Test system behavior under adverse conditions
@Test("Chaos testing - random cancellations")
func chaosTestingRandomCancellations() async throws {
    let locationSearch = LocationSearch()
    
    // Randomly cancel searches to test resilience
    for _ in 0..<50 {
        let task = Task {
            try await locationSearch.search(queryFragment: randomQuery())
        }
        
        if Bool.random() {
            task.cancel()
        }
        
        _ = try? await task.value
    }
}
```

### 3. Contract Testing

```swift
// Verify API contracts are maintained
@Test("API contract validation")
func apiContractValidation() async throws {
    let locationSearch = LocationSearch()
    let results = try await locationSearch.search(queryFragment: "Valid Query")
    
    // Contract: All results must have valid IDs
    for result in results {
        #expect(!result.id.isEmpty, "All results must have non-empty IDs")
        #expect(!result.title.isEmpty, "All results must have non-empty titles")
    }
}
```

## Best Practices Summary

### 1. Test Structure
- Use nested structures for logical organization
- Group related tests together
- Use descriptive, intention-revealing names

### 2. Test Data
- Use stable, real-world locations for integration tests
- Avoid hardcoding specific result counts or orders
- Test with various query lengths and types

### 3. Error Testing
- Test all error conditions explicitly
- Verify proper error propagation
- Test error recovery scenarios

### 4. Concurrency Testing
- Test actual concurrent scenarios
- Verify cancellation behavior
- Test race condition prevention

### 5. Maintenance
- Keep tests simple and focused
- Update tests when behavior intentionally changes
- Remove or update tests for deprecated functionality

This comprehensive testing strategy ensures that MapKitSwiftSearch remains reliable, performant, and maintainable as it evolves. The combination of integration tests, unit tests, and specialized regression tests provides confidence in the package's behavior across a wide range of real-world scenarios.