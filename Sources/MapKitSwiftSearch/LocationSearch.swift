// The Swift Programming Language
// https://docs.swift.org/swift-book

import MapKit
import Observation
import os

/// An error that occurs during location search operations.
public enum LocationSearchError: LocalizedError, Equatable {
    /// Indicates that the search completion operation failed.
    case searchCompletionFailed
    
    /// MapKit thrown error
    case mapKitError(MKError)
    
    /// Empty, not enough characters
    case invalidSearchCriteria
    
    /// Searching the same text twice in a row
    case duplicateSearchCriteria

    case debounce

    public var errorDescription: String? {
        switch self {
        case .searchCompletionFailed:
            return "Unable to complete location search"
        case let .mapKitError(mkError):
            return "MapKit error: \(mkError)"
        case .invalidSearchCriteria:
            return "Search criteria must meet minimum character requirements"
        case .duplicateSearchCriteria:
            return "Search criteria cannot be repeated"
        case .debounce:
            return "Debounced"
        }
    }
}

private let logger = LogContext.locationSearch.logger()

/// A class that provides a modern Swift interface for location search operations using MapKit.
///
/// `LocationSearch` wraps MapKit's `MKLocalSearchCompleter` to provide a more Swift-idiomatic
/// search experience with the following benefits:
/// - Uses structured concurrency with async/await for cleaner call sites
/// - Provides type-safe error handling through Swift's throwing functions
/// - Ensures thread safety through `@MainActor` attribution
/// - Returns `Sendable` compliant search results for safe concurrent operations
///
/// This class is particularly useful for applications that need to provide real-time
/// location search suggestions as users type, such as address lookup or point of interest search.
///
/// Example usage:
/// ```swift
/// let searcher = LocationSearch()
/// do {
///     let results = try await searcher.search(queryFragment: "Coffee shops")
///     // Work with the results
/// } catch {
///     // Handle errors
/// }
@MainActor
public final class LocationSearch {
    
    private var localSearchCompletions: [LocalSearchCompletion] = []
    
    private let searchCompleter = MKLocalSearchCompleter()
    private let localSearchCompleterHandler = LocalSearchCompleterHandler()
    
    private let numberOfCharactersBeforeSearching: Int
    private let debounceSearchDelay: Duration
    
    /// Creates a new location search instance with customizable search behavior.
    ///
    /// - Parameter numberOfCharactersBeforeSearching: The minimum number of characters required
    ///   before initiating a search operation. This helps optimize performance by preventing
    ///   too-frequent searches with very short queries.
    ///   Default value is 5 characters.
    ///
    /// Example usage:
    /// ```swift
    /// // Create with default minimum character count (5)
    /// let defaultSearcher = LocationSearch()
    ///
    /// // Create with custom minimum character count
    /// let customSearcher = LocationSearch(numberOfCharactersBeforeSearching: 3)
    /// ```
    public init(numberOfCharactersBeforeSearching: Int = 5,
                debounceSearchDelay: Duration = .milliseconds(300)) {
        self.numberOfCharactersBeforeSearching = numberOfCharactersBeforeSearching
        self.debounceSearchDelay = debounceSearchDelay
        self.searchCompleter.delegate = localSearchCompleterHandler
    }
    
    private typealias SearchTask = Task<[LocalSearchCompletion], Error>
    private var currentSearchTask: SearchTask?
    private var debounceTask: Task<Bool, Never>?
    
    private var lastSearchQuery: String?
    
    /// Performs an asynchronous location search based on the provided query fragment.
    ///
    /// This method uses MapKit's local search completion to find matching locations
    /// based on the input text.
    ///
    ///  It's possible to get an error if this is called too often by MapKit. Debouncing is left to the caller
    ///  in the same it is if you're calling MapKit directly
    ///
    /// - Parameter queryFragment: The search text to use for finding locations.
    /// - Returns: An array of `LocalSearchCompletion` objects representing the search results.
    /// - Throws: `LocationSearchError.searchCompletionFailed` if the search operation fails.
    ///
    /// - Note: The search will only be performed if the query fragment length is greater than
    ///         or equal to `numberOfCharactersBeforeSearching`.
    public func search(queryFragment: String) async throws -> [LocalSearchCompletion] {
        
        debounceTask?.cancel()
        
        debounceTask = Task {
            do {
                logger.debug("Starting debounce")
                try await Task.sleep(for: debounceSearchDelay)
                logger.debug("Completed debounce")
                return true
            } catch {
                logger.debug("debounce cancelled")
                return false
            }
        }
        
        guard let debounceTask, await debounceTask.value else {
            throw LocationSearchError.debounce
        }
        
        logger.debug("Pass debounce, starting search")
        
        guard lastSearchQuery != queryFragment else {
            logger.debug("Query hasn't changed not searching")
            throw LocationSearchError.duplicateSearchCriteria
        }
        
        lastSearchQuery = queryFragment
        
        guard !queryFragment.isEmpty else {
            logger.debug("Query is empty not searching")
            localSearchCompletions.removeAll()
            return localSearchCompletions
        }
        
        guard queryFragment.count >= numberOfCharactersBeforeSearching else {
            logger.debug("Not enough characters to search")
            throw LocationSearchError.invalidSearchCriteria
        }
        
        currentSearchTask?.cancel()
        
        let task = SearchTask { [searchCompleter] in
            
            let completions = try await thenSearch()
            return completions
            
            @MainActor
            func thenSearch() async throws -> [LocalSearchCompletion]  {
                logger.debug("Searching: \(queryFragment)")
                return try await withCheckedThrowingContinuation { continuation in
                    localSearchCompleterHandler.completionHandler = {result in
                        switch result {
                        case .success(let completions):
                            logger.debug("Successfully searched \(queryFragment)")
                            continuation.resume(with: .success(completions))
                        case .failure(let error):
                            logger.error("failed to search \(queryFragment): \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    searchCompleter.queryFragment = queryFragment
                }
            }
        }
        
        currentSearchTask = task
        
        return try await task.value
    }
    
    public func placemark(for searchCompletion: LocalSearchCompletion) async throws -> Placemark? {
        try await withCheckedThrowingContinuation { continuation in
            
            let localSearch = searchCompletion.localSearch()
            
            localSearch.start { response, error in
                if let error {
                    if let mkError = error as? MKError {
                        logger.error("MapKit error: \(mkError)")
                        continuation.resume(throwing: LocationSearchError.mapKitError(mkError))
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let response else {
                    // It's assumed that both can't be nil, so we consider this an error
                    logger.error("Error was nil, and response is nil: \(searchCompletion)")
                    continuation.resume(throwing: LocationSearchError.searchCompletionFailed)
                    return
                }
                
                guard let placemark = response.mapItems.first?.placemark else {
                    // Another invalid state, success but nothing returned
                    logger.error("Placemark was expected \(searchCompletion)")
                    continuation.resume(throwing: LocationSearchError.searchCompletionFailed)
                    return
                }
                continuation.resume(
                    returning: Placemark(placemark: placemark)
                )
            }
        }
    }
}

/// A delegate handler class for managing `MKLocalSearchCompleter` callbacks.
///
/// This class implements the `MKLocalSearchCompleterDelegate` protocol and converts
/// the delegate callbacks into a more Swift-friendly completion handler pattern.
private final class LocalSearchCompleterHandler: NSObject, MKLocalSearchCompleterDelegate {
    var completionHandler: ((Result<[LocalSearchCompletion], Error>) -> Void)?
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter)  {
        let mappedResults = completer.results.map { LocalSearchCompletion($0) }
        completionHandler?(.success(mappedResults))
    }
    
    func completer(_: MKLocalSearchCompleter, didFailWithError error: Error) {
        logger.error("didFailWithError: \(error)")
        completionHandler?(.failure(LocationSearchError.searchCompletionFailed))
    }
}


private extension LocalSearchCompletion {
    func localSearch() -> MKLocalSearch {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery =  "\(title) \(subTitle)".trimmingCharacters(in: .whitespaces)
        return .init(request: request)
    }
}
