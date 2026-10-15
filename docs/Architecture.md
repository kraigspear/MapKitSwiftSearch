# MapKitSwiftSearch Architecture

## Overview

MapKitSwiftSearch is a modern Swift package that provides a clean, concurrent-friendly interface for location search operations using MapKit. The package wraps Apple's `MKLocalSearchCompleter` and related APIs to provide a more Swift-idiomatic experience with structured concurrency, type safety, and cross-platform compatibility.

## Design Philosophy

The architecture follows the principles outlined in "A Philosophy of Software Design" by John Ousterhout, emphasizing:

- **Deep Modules**: Each component provides significant functionality while maintaining simple interfaces
- **Information Hiding**: Internal implementation details are encapsulated, exposing only essential APIs
- **Layer Separation**: Clear boundaries between data models, search logic, and platform-specific UI concerns
- **Consistent Abstractions**: Similar operations use consistent patterns throughout the API

## Core Components

### Primary Classes and Structures

```mermaid
classDiagram
    class LocationSearch {
        -debounceSearchDelay: Duration
        -lastSearchQuery: String?
        -numberOfCharactersBeforeSearching: Int
        -currentSearchTask: SearchTask?
        -debounceTask: Task<Bool, Never>?
        +init(numberOfCharactersBeforeSearching: Int, debounceSearchDelay: Duration)
        +search(queryFragment: String) async throws -> [LocalSearchCompletion]
        +placemark(for: LocalSearchCompletion) async throws -> Placemark?
        -performSearch(queryFragment: String) async throws -> [LocalSearchCompletion]
    }
    
    class LocalSearchCompletion {
        +id: String
        +title: String
        +subTitle: String
        +titleHighlightRange: HighlightRange?
        +subtitleHighlightRange: HighlightRange?
        ~init(MKLocalSearchCompletion)
        +highlightedTitle() -> AttributedString
        +highlightedSubTitle() -> AttributedString
    }
    
    class Placemark {
        +coordinate: CLLocationCoordinate2D
        +name: String?
        +fullAddress: String?
        +shortAddress: String?
        +init(mapItem: MKMapItem)
    }
    
    class HighlightRange {
        -location: Int
        -length: Int
        +init(nsRange: NSRange)
        ~init(nsValue: NSValue)
        +toAttributedStringRange(in: AttributedString) -> Range<AttributedString.Index>?
    }
    
    class LocationSearchError {
        <<enumeration>>
        +searchCompletionFailed
        +mapKitError(MKError)
        +invalidSearchCriteria
        +duplicateSearchCriteria
        +debounce
    }
    
    class MKLocalSearchCompleterAdapter {
        -completer: MKLocalSearchCompleter
        +delegate: LocalSearchCompleterDelegate?
        +queryFragment: String
        +cancel()
    }

    class LocalSearchCompleterHandler {
        +completionHandler: ((Result<[LocalSearchCompletion], Error>) -> Void)?
        +completerDidUpdateResults([LocalSearchCompletion])
        +completerDidFail(with: Error)
    }
    
    LocationSearch --> LocalSearchCompletion : returns
    LocationSearch --> Placemark : returns
    LocationSearch --> LocationSearchError : throws
    LocationSearch --> MKLocalSearchCompleterAdapter : creates per search
    LocationSearch --> LocalSearchCompleterHandler : creates per search
    MKLocalSearchCompleterAdapter --> LocalSearchCompleterHandler : reports to
    LocalSearchCompletion --> HighlightRange : contains
    LocalSearchCompletion --> MKLocalSearchCompletion : snapshots
    Placemark --> MKMapItem : snapshots

    style LocationSearch fill:#2d3748,stroke:#4a5568,stroke-width:2px,color:#ffffff
    style LocalSearchCompletion fill:#2b6cb1,stroke:#1a365d,stroke-width:2px,color:#ffffff
    style Placemark fill:#38a169,stroke:#2f855a,stroke-width:2px,color:#ffffff
    style HighlightRange fill:#805ad5,stroke:#553c9a,stroke-width:2px,color:#ffffff
    style LocationSearchError fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#ffffff
    style LocalSearchCompleterHandler fill:#ed8936,stroke:#c05621,stroke-width:2px,color:#ffffff
    style MKLocalSearchCompleterAdapter fill:#ed8936,stroke:#c05621,stroke-width:2px,color:#ffffff
```

`~` marks internal members. `MKLocalSearchCompleterAdapter` and `MKLocalSearchAdapter` sit behind internal protocols (`LocalSearchCompleterProtocol`, `LocalSearchProtocol`) so tests can replace MapKit.

## Key Architectural Decisions

### 1. MainActor Attribution on LocationSearch

**Decision**: The `LocationSearch` class is marked with `@MainActor`.

**Rationale**: 
- MapKit's `MKLocalSearchCompleter` requires main thread interaction
- Ensures thread safety by eliminating race conditions on shared state
- Provides clear concurrency semantics for callers
- Simplifies the API by removing the need for manual thread management

**Trade-offs**:
- Slightly less flexible for background processing scenarios
- All search operations must be called from the main actor context
- Balanced against the complexity reduction and safety guarantees

### 2. Task-Based Cancellation Strategy

**Decision**: Each search operation creates a new `Task` that can be cancelled independently. A newer call cancels the in-flight search once its own debounce ends, and the superseded call throws `CancellationError`.

**Rationale**:
- Prevents resource waste when users type quickly and cancel previous searches
- Provides clean cancellation semantics through `Task` handles
- Eliminates callback-based complexity from the MapKit delegate pattern
- A superseded caller never receives stale results, so it can't overwrite newer ones

**Implementation Details**:
```swift
lastSearchQuery = queryFragment

// Cancel before the early exits below, or the older search would deliver
// its results after this call returns
currentSearchTask?.cancel()

guard !queryFragment.isEmpty else { return [] }
// ... minimum-length guard ...

let task = SearchTask {
    try await performSearch(queryFragment: queryFragment)
}
currentSearchTask = task

let searchResult = await task.result

// MapKit's answer can resume the task before its cancellation handler runs,
// so a superseded search can still finish with results or a MapKit error
guard !task.isCancelled else {
    throw CancellationError()
}
return try searchResult.get()
```

The cancel sits after the duplicate-query guard, so repeating the in-flight query leaves that search running.

### 3. New MKLocalSearchCompleter Per Search

**Decision**: A fresh `MKLocalSearchCompleter` instance is created for each search operation.

**Rationale**:
- **Continuation Safety**: Avoids potential conflicts when multiple async/await continuations might be waiting on the same delegate
- **Clean State**: Each search starts with a clean slate, preventing state pollution from previous searches
- **Simplified Error Handling**: Eliminates complex state management around delegate callbacks
- **Cancellation Clarity**: When a search is cancelled, the entire completer instance is discarded

**Alternative Considered**: Reusing a single completer instance was considered but rejected due to the complexity of managing multiple concurrent continuations and ensuring proper cleanup.

### 4. Debouncing Strategy

**Decision**: Implement debouncing at the API level using `Task.sleep`, injected as `debounceSleep` so tests control when a debounce ends.

**Rationale**:
- Reduces unnecessary API calls when users are actively typing
- Provides a responsive feel while preventing API abuse
- Uses structured concurrency for clean timeout management
- Configurable delay allows customization for different use cases

**Implementation**:
```swift
debounceTask?.cancel()

let newDebounceTask = Task {
    do {
        try await debounceSleep(debounceSearchDelay)
        return true
    } catch {
        return false
    }
}
debounceTask = newDebounceTask

guard await newDebounceTask.value else {
    throw LocationSearchError.debounce
}
```

### 5. Sendable-Compliant Data Models

**Decision**: All public data types (`LocalSearchCompletion`, `Placemark`, `HighlightRange`) conform to `Sendable`.

**Rationale**:
- Enables safe passage between actor contexts
- Future-proofs the API for Swift's strict concurrency model
- Provides compile-time guarantees about thread safety
- Simplifies client code by eliminating manual synchronization needs

### 6. Platform-Specific Extensions for UI Highlighting

**Decision**: Separate platform-specific extensions for iOS (`UIColor`) and macOS (`NSColor`) highlighting functionality.

**Rationale**:
- **Single Responsibility**: Core data models remain platform-agnostic
- **Type Safety**: Uses appropriate platform color types without abstraction
- **Performance**: No runtime platform checks or unnecessary abstractions
- **Maintainability**: Platform-specific UI code is isolated and clearly marked

**File Structure**:
```
PlatformSpecific/
├── LocalSearchCompletion+iOS.swift     // UIColor-based highlighting
└── LocalSearchCompletion+macOS.swift   // NSColor-based highlighting
```

### 7. Private HighlightRange Properties

**Decision**: The `location` and `length` properties of `HighlightRange` are private.

**Rationale**:
- **Information Hiding**: Clients don't need to know about NSRange internals
- **API Stability**: Internal representation can change without breaking client code  
- **Focused Interface**: Only the essential `toAttributedStringRange` method is exposed
- **Error Prevention**: Prevents clients from manually manipulating range values incorrectly

### 8. Extracted Search Logic

**Decision**: The core search logic is extracted into a private `performSearch` method.

**Rationale**:
- **Separation of Concerns**: Validation, debouncing, and caching are separated from the actual search
- **Testability**: Core search logic can be tested independently
- **Readability**: The public `search` method clearly shows the flow without implementation details
- **Maintainability**: Changes to search logic don't affect validation and error handling code

## Error Handling Strategy

The package uses a comprehensive error handling approach:

`search(queryFragment:)` checks in this order:

```mermaid
graph TD
    A[search queryFragment] --> B{Debounce}
    B -->|Newer call arrived| E[LocationSearchError.debounce]
    B -->|Delay elapsed| C{Same as last query?}
    C -->|Yes| H[LocationSearchError.duplicateSearchCriteria]
    C -->|No| J{Empty?}
    J -->|Yes| K[Return empty array]
    J -->|No| L{Shorter than minimum?}
    L -->|Yes| D[LocationSearchError.invalidSearchCriteria]
    L -->|No| F[MapKit search]
    F -->|Results| G[Return results]
    F -->|Completer failure| I[LocationSearchError.searchCompletionFailed]
    F -->|Superseded by a newer call| M[CancellationError]

    style A fill:#e2e8f0,stroke:#2d3748,stroke-width:2px,color:#2d3748
    style G fill:#38a169,stroke:#2f855a,stroke-width:2px,color:#ffffff
    style K fill:#38a169,stroke:#2f855a,stroke-width:2px,color:#ffffff
    style D fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#ffffff
    style E fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#ffffff
    style H fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#ffffff
    style I fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#ffffff
    style M fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#ffffff
```

`placemark(for:)` throws `LocationSearchError.mapKitError` for an `MKError`, `LocationSearchError.searchCompletionFailed` when MapKit returns no response or no map items, and rethrows any other error unchanged.

### Error Categories

1. **User Input Errors**: Query shorter than the minimum
2. **Operational Errors**: Debounce, duplicate query, and superseded searches (`CancellationError`)
3. **System Errors**: MapKit failures and network issues
4. **Logic Errors**: Unexpected states in search completion

## Concurrency Model

The package leverages Swift's structured concurrency throughout:

```mermaid
sequenceDiagram
    participant Client
    participant LocationSearch
    participant DebounceTask
    participant SearchTask
    participant MKLocalSearchCompleter
    
    Client->>LocationSearch: search(queryFragment:)
    LocationSearch->>DebounceTask: Task.sleep(for: delay)
    
    alt Debounce Cancelled
        LocationSearch-->>Client: throw .debounce
    else Debounce Completes
        LocationSearch->>SearchTask: performSearch()
        SearchTask->>MKLocalSearchCompleter: queryFragment = text
        MKLocalSearchCompleter->>SearchTask: delegate callback
        SearchTask->>LocationSearch: return results
        LocationSearch->>Client: return results
    end

    Note over LocationSearch: @MainActor ensures thread safety
    Note over SearchTask: Task provides cancellation support
```

## Memory Management

The architecture carefully manages memory and resources:

1. **Automatic Cleanup**: Tasks are automatically cleaned up when cancelled or completed
2. **Weak References**: Delegate patterns use appropriate memory management
3. **Resource Disposal**: Search completers are discarded after each operation
4. **State Isolation**: Minimal shared state reduces memory retention issues

## Future Extensibility

The architecture supports future enhancements:

1. **Region-Based Search**: The `Placemark` structure can easily accommodate region filtering
2. **Custom Search Types**: The error handling system can be extended for new search categories
3. **Caching Layer**: The extracted search logic provides a clear insertion point for caching
4. **Analytics Integration**: The logging infrastructure can be extended for metrics collection

## Testing Architecture

The design facilitates comprehensive testing:

1. **Dependency Injection**: The internal initializer takes a completer factory, a local-search factory, and `debounceSleep`; `LocationSearchUnitTests` drives search with fakes through them
2. **Error Simulation**: The error handling system supports comprehensive error scenario testing
3. **Concurrency Testing**: Task-based operations can be tested for proper cancellation behavior
4. **Platform Testing**: Platform-specific code is isolated for targeted testing

This architecture provides a solid foundation for reliable, performant location search functionality while maintaining clean separation of concerns and excellent testability.