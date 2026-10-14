# Search Flow Sequence Diagrams

## Overview

This document contains sequence diagrams that illustrate the flow of operations within MapKitSwiftSearch for key user interactions. These diagrams help understand the timing, actor interactions, and error handling patterns in the system.

## Primary Search Flow

The following diagram shows the complete flow from user input to search results, including debouncing, validation, and MapKit interaction.

```mermaid
sequenceDiagram
    participant User
    participant LocationSearch
    participant DebounceTask
    participant SearchTask
    participant LocalSearchCompleterHandler
    participant MKLocalSearchCompleterAdapter
    
    User->>LocationSearch: search(queryFragment: "Starbucks")
    
    Note over LocationSearch: Cancel previous debounce task
    LocationSearch->>DebounceTask: Create Task { sleep(300ms) }
    
    alt User types again before debounce completes
        User->>LocationSearch: search(queryFragment: "Starbucks NY")
        LocationSearch->>DebounceTask: cancel()
        LocationSearch-->>User: throw .debounce (previous call)
        LocationSearch->>DebounceTask: Create new Task { sleep(300ms) }
    end
    
    DebounceTask->>LocationSearch: return true (debounce complete)
    
    Note over LocationSearch: Validation phase
    alt Query same as previous
        LocationSearch-->>User: throw .duplicateSearchCriteria
    end
    Note over LocationSearch: Cancel in-flight search
    alt Query is empty
        LocationSearch-->>User: return []
    else Query too short
        LocationSearch-->>User: throw .invalidSearchCriteria
    end
    
    Note over LocationSearch: Begin search operation
    LocationSearch->>SearchTask: Create Task { performSearch() }
    SearchTask->>MKLocalSearchCompleterAdapter: create via completerFactory
    SearchTask->>LocalSearchCompleterHandler: create, set as delegate
    
    SearchTask->>MKLocalSearchCompleterAdapter: queryFragment = "Starbucks"
    
    Note over MKLocalSearchCompleterAdapter: MapKit performs search
    MKLocalSearchCompleterAdapter->>MKLocalSearchCompleterAdapter: map to LocalSearchCompletion
    MKLocalSearchCompleterAdapter->>LocalSearchCompleterHandler: completerDidUpdateResults(results)
    LocalSearchCompleterHandler->>SearchTask: completion(.success(results))
    SearchTask->>LocationSearch: return results
    LocationSearch-->>User: return [LocalSearchCompletion]
    
    alt MapKit Error
        MKLocalSearchCompleterAdapter->>LocalSearchCompleterHandler: completerDidFail(with: error)
        LocalSearchCompleterHandler->>SearchTask: completion(.failure(.searchCompletionFailed))
        SearchTask-->>LocationSearch: throw .searchCompletionFailed
        LocationSearch-->>User: throw .searchCompletionFailed
    end
```

## Placemark Retrieval Flow

This diagram shows the process of converting a search completion result into detailed placemark information.

```mermaid
sequenceDiagram
    participant User
    participant LocationSearch
    participant LocalSearchCompletion
    participant MKLocalSearch
    participant MKLocalSearchRequest
    participant MapKit
    
    User->>LocationSearch: placemark(for: completion)
    LocationSearch->>LocalSearchCompletion: localSearch()
    LocalSearchCompletion->>MKLocalSearchRequest: create with naturalLanguageQuery
    LocalSearchCompletion->>MKLocalSearch: init(request: request)
    LocalSearchCompletion-->>LocationSearch: return MKLocalSearch
    
    LocationSearch->>MKLocalSearch: start { response, error in ... }
    
    Note over MKLocalSearch: Performs detailed search
    MKLocalSearch->>MapKit: Execute search request
    
    alt Successful Response
        MapKit->>MKLocalSearch: return MKLocalSearchResponse
        MKLocalSearch->>LocationSearch: callback(response, nil)
        LocationSearch->>LocationSearch: take first map item
        LocationSearch->>LocationSearch: create Placemark(mapItem:)
        LocationSearch-->>User: return Placemark?
    else MapKit Error
        MapKit->>MKLocalSearch: return MKError
        MKLocalSearch->>LocationSearch: callback(nil, MKError)
        LocationSearch-->>User: throw .mapKitError(MKError)
    else No Results
        MapKit->>MKLocalSearch: return empty response
        MKLocalSearch->>LocationSearch: callback(response, nil)
        Note over LocationSearch: response.mapItems.isEmpty
        LocationSearch-->>User: throw .searchCompletionFailed
    end
```

## Concurrent Search Cancellation

This diagram illustrates how the system handles multiple concurrent search requests and proper cancellation behavior.

```mermaid
sequenceDiagram
    participant User
    participant LocationSearch
    participant SearchTask1
    participant SearchTask2
    participant Completer1 as MKLocalSearchCompleterAdapter 1
    participant Completer2 as MKLocalSearchCompleterAdapter 2
    
    User->>LocationSearch: search("Coffee")
    LocationSearch->>SearchTask1: Create Task { performSearch("Coffee") }
    SearchTask1->>Completer1: create & start search
    
    Note over User: User continues typing
    User->>LocationSearch: search("Coffee shop")
    Note over LocationSearch: Newer call's debounce completes
    LocationSearch->>SearchTask1: cancel()
    LocationSearch->>SearchTask2: Create Task { performSearch("Coffee shop") }
    
    Note over SearchTask1: Task cancellation
    SearchTask1->>Completer1: cancel()
    SearchTask1-->>LocationSearch: throw CancellationError
    LocationSearch-->>User: throw CancellationError (first call)
    
    SearchTask2->>Completer2: create & start search
    Completer2->>SearchTask2: return results
    SearchTask2->>LocationSearch: return results
    LocationSearch-->>User: return results for "Coffee shop"
    
    Note over LocationSearch: The first call throws CancellationError even if MapKit answered before the cancel landed
```

## Error Handling Flow

This diagram shows the comprehensive error handling throughout the search process.

```mermaid
sequenceDiagram
    participant User
    participant LocationSearch
    participant Validation
    participant DebounceTask
    participant SearchTask
    participant MapKit
    
    User->>LocationSearch: search(queryFragment)
    
    LocationSearch->>DebounceTask: sleep(debounceDelay)
    alt Debounce cancelled
        DebounceTask-->>LocationSearch: return false
        LocationSearch-->>User: throw .debounce
    end
    
    LocationSearch->>Validation: check criteria
    alt Duplicate query
        Validation-->>LocationSearch: same as last query
        LocationSearch-->>User: throw .duplicateSearchCriteria
    else Empty query
        Validation-->>LocationSearch: empty string
        LocationSearch-->>User: return [] (no error)
    else Insufficient characters
        Validation-->>LocationSearch: too short
        LocationSearch-->>User: throw .invalidSearchCriteria
    end
    
    LocationSearch->>SearchTask: performSearch()
    SearchTask->>MapKit: execute search
    
    alt MapKit success
        MapKit-->>SearchTask: return completions
        SearchTask-->>LocationSearch: return results
        LocationSearch-->>User: return [LocalSearchCompletion]
    else Completer failure
        MapKit-->>SearchTask: didFailWithError
        SearchTask-->>LocationSearch: throw .searchCompletionFailed
        LocationSearch-->>User: throw .searchCompletionFailed
    else Superseded by a newer call
        LocationSearch->>SearchTask: cancel()
        LocationSearch-->>User: throw CancellationError
    end
```

## Highlight Range Processing

This diagram shows how highlight ranges are processed from MapKit through to UI display.

```mermaid
sequenceDiagram
    participant MKLocalSearchCompleter
    participant LocalSearchCompletion
    participant HighlightRange
    participant PlatformExtension
    participant AttributedString
    
    MKLocalSearchCompleter->>LocalSearchCompletion: init(MKLocalSearchCompletion)
    Note over LocalSearchCompletion: Extract highlight ranges
    LocalSearchCompletion->>HighlightRange: init(nsValue: titleHighlightRanges.first)
    HighlightRange->>HighlightRange: convert NSValue to NSRange
    LocalSearchCompletion->>HighlightRange: init(nsValue: subtitleHighlightRanges.first)
    
    Note over LocalSearchCompletion: Store ranges as optional properties
    
    PlatformExtension->>LocalSearchCompletion: highlightedTitle(colors...)
    LocalSearchCompletion->>AttributedString: create from title string
    LocalSearchCompletion->>HighlightRange: toAttributedStringRange(in: attributedString)
    
    alt Valid range
        HighlightRange->>HighlightRange: convert to AttributedString.Index range
        HighlightRange-->>LocalSearchCompletion: return Range<AttributedString.Index>
        LocalSearchCompletion->>AttributedString: apply highlight color to range
        LocalSearchCompletion-->>PlatformExtension: return highlighted AttributedString
    else Invalid range
        HighlightRange-->>LocalSearchCompletion: return nil
        LocalSearchCompletion-->>PlatformExtension: return AttributedString with base color only
    end
```

## Key Design Insights

### Cancellation Strategy
- **New Completer Per Search**: Avoids complex state management and continuation conflicts
- **Task-Based Cancellation**: Clean cancellation semantics using Swift's structured concurrency
- **Resource Cleanup**: Cancelled completers are automatically disposed

### Error Isolation
- **Layered Validation**: Multiple validation points prevent invalid requests from reaching MapKit
- **Specific Error Types**: Different error cases enable appropriate user experience responses
- **Graceful Degradation**: System continues operating even when individual searches fail

### Thread Safety
- **MainActor Isolation**: All LocationSearch operations are main-actor bound
- **Task Encapsulation**: Each search runs in its own task context
- **Immutable Results**: Search results are immutable and Sendable

### Performance Optimization
- **Debouncing**: Prevents excessive API calls during rapid user input
- **Early Termination**: Validation checks prevent unnecessary network requests
- **Memory Efficiency**: Fresh completers prevent memory accumulation from long-running searches

These sequence diagrams provide a comprehensive view of the system's behavior under various conditions, helping developers understand not just what happens, but when and why each interaction occurs.