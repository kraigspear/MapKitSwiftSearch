// The Swift Programming Language
// https://docs.swift.org/swift-book

@preconcurrency import MapKit
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

    /// Error thrown when a search request is debounced
    case debounce

    public var errorDescription: String? {
        switch self {
        case .searchCompletionFailed:
            "Unable to complete location search"
        case let .mapKitError(mkError):
            "MapKit error: \(mkError)"
        case .invalidSearchCriteria:
            "Search criteria must meet minimum character requirements"
        case .duplicateSearchCriteria:
            "Search criteria cannot be repeated"
        case .debounce:
            "Debounced"
        }
    }
}

// MARK: - Private Constants

/// Logger instance for location search operations.
///
/// Uses the location search context to provide categorized logging that helps
/// with debugging search performance, errors, and user interaction patterns.
private let logger = LogContext.locationSearch.logger()

/// A class that provides a modern Swift interface for location search operations using MapKit.
///
/// `LocationSearch` wraps MapKit's `MKLocalSearchCompleter` to provide a more Swift-idiomatic
/// search experience with the following benefits:
/// - Uses structured concurrency with async/await for cleaner call sites
/// - Provides type-safe error handling through Swift's throwing functions
/// - Ensures thread safety through `@MainActor` attribution
/// - Implements debouncing to prevent excessive API calls
/// - Returns `Sendable` compliant search results for safe concurrent operations
///
/// This class is particularly useful for applications that need to provide real-time
/// location search suggestions as users type, such as address lookup or point of interest search.
///
/// Example usage:
/// ```swift
/// let searcher = LocationSearch()
/// do {
///     // Search for locations
///     let results = try await searcher.search(queryFragment: "Coffee shops")
///
///     // Get detailed information for the first result
///     if let firstResult = results.first {
///         let placemark = try await searcher.placemark(for: firstResult)
///         if let place = placemark {
///             // Access detailed location information
///             print("Name: \(place.name ?? "Unknown")")
///             // Create a formatted address from available components
///             let address = [place.subThoroughfare, place.thoroughfare, place.locality, place.administrativeArea]
///                 .compactMap { $0 }
///                 .joined(separator: ", ")
///             print("Address: \(address)")
///             print("Coordinate: \(place.coordinate)")
///         }
///     }
/// } catch LocationSearchError.debounce {
///     // Handle debounced request
/// } catch LocationSearchError.mapKitError(let error) {
///     // Handle MapKit specific errors
/// } catch {
///     // Handle other errors
/// }
/// ```
@MainActor
public final class LocationSearch {
    // MARK: - Configuration

    /// The delay duration before executing a search after user input stops.
    ///
    /// This prevents excessive API calls during rapid typing by waiting for a pause
    /// in user input before performing the actual search operation.
    private let debounceSearchDelay: Duration

    /// The minimum number of characters required before initiating a search.
    ///
    /// Prevents searches with very short queries that are likely to produce
    /// too many generic results or cause unnecessary API load.
    private let numberOfCharactersBeforeSearching: Int

    // MARK: - State

    /// The most recent search query to prevent duplicate consecutive searches.
    ///
    /// Cached to avoid repeating identical searches when the user hasn't changed
    /// the input, improving performance and reducing unnecessary API calls.
    private var lastSearchQuery: String?

    /// The current search completion results.
    ///
    /// Maintained as instance state to support clearing results when appropriate
    /// (such as when the search query becomes empty).
    private var localSearchCompletions: [LocalSearchCompletion] = []

    // MARK: - Concurrent Tasks

    /// Type alias for search operation tasks to improve code readability.
    private typealias SearchTask = Task<[LocalSearchCompletion], Error>

    /// The currently active search task, if any.
    ///
    /// Maintained to enable cancellation of in-flight searches when new searches
    /// are initiated, preventing race conditions and outdated results.
    private var currentSearchTask: SearchTask?

    /// The active debounce delay task.
    ///
    /// Tracks the current debounce timer to enable cancellation when new input
    /// arrives before the delay period expires.
    private var debounceTask: Task<Bool, Never>?

    // MARK: - Initialization

    /// Creates a new location search instance with customizable search behavior.
    ///
    /// The initializer sets up the search parameters that control when and how often
    /// searches are performed. These parameters are designed to balance responsiveness
    /// with performance, preventing excessive API calls while maintaining a smooth user experience.
    ///
    /// - Parameters:
    ///   - numberOfCharactersBeforeSearching: The minimum number of characters required
    ///     before initiating a search operation. This helps optimize performance by preventing
    ///     searches with very short queries that tend to produce generic or excessive results.
    ///     Default value is 5 characters, which provides a good balance for most use cases.
    ///   - debounceSearchDelay: The delay before executing a search after user input stops.
    ///     This prevents rapid-fire searches during typing. Default is 300 milliseconds,
    ///     which feels responsive while avoiding excessive API calls.
    ///
    /// Example usage:
    /// ```swift
    /// // Create with default settings (5 chars minimum, 300ms debounce)
    /// let defaultSearcher = LocationSearch()
    ///
    /// // Create with custom settings for more responsive search
    /// let customSearcher = LocationSearch(
    ///     numberOfCharactersBeforeSearching: 3,
    ///     debounceSearchDelay: .milliseconds(200)
    /// )
    /// ```
    public init(numberOfCharactersBeforeSearching: Int = 5,
                debounceSearchDelay: Duration = .milliseconds(300))
    {
        self.numberOfCharactersBeforeSearching = numberOfCharactersBeforeSearching
        self.debounceSearchDelay = debounceSearchDelay
    }

    // MARK: - Public Search Methods

    /// Performs an asynchronous location search based on the provided query fragment.
    ///
    /// This method uses MapKit's local search completion to find matching locations
    /// based on the input text. The search is debounced to prevent excessive API calls.
    ///
    /// - Parameter queryFragment: The search text to use for finding locations.
    /// - Returns: An array of `LocalSearchCompletion` objects representing the search results.
    ///           Returns an empty array if the query is empty.
    /// - Throws:
    ///   - `LocationSearchError.debounce` if the request is debounced
    ///   - `LocationSearchError.duplicateSearchCriteria` if searching with the same text consecutively
    ///   - `LocationSearchError.invalidSearchCriteria` if the query length is less than required
    ///   - `LocationSearchError.searchCompletionFailed` if the search operation fails
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

        // Ensure the debounce period completed successfully
        // If the task was cancelled or failed, throw debounce error
        guard let debounceTask, await debounceTask.value else {
            throw LocationSearchError.debounce
        }

        logger.debug("Debounce completed successfully, proceeding with search")

        // Prevent duplicate searches for the same query to reduce API load
        // and avoid unnecessary processing of identical requests
        guard lastSearchQuery != queryFragment else {
            logger.debug("Query unchanged, skipping duplicate search: \(queryFragment)")
            throw LocationSearchError.duplicateSearchCriteria
        }

        // Update the last search query for future duplicate detection
        lastSearchQuery = queryFragment

        // Handle empty queries by clearing results rather than searching
        // This provides immediate feedback and avoids unnecessary API calls
        guard !queryFragment.isEmpty else {
            logger.debug("Empty query provided, clearing search results")
            localSearchCompletions.removeAll()
            return localSearchCompletions
        }

        // Enforce minimum character requirement to ensure meaningful search results
        // Short queries typically produce too many generic results
        guard queryFragment.count >= numberOfCharactersBeforeSearching else {
            // swiftformat:disable:next redundantSelf
            logger.debug("Query too short (\(queryFragment.count) chars, need \(self.numberOfCharactersBeforeSearching))")
            throw LocationSearchError.invalidSearchCriteria
        }

        // Cancel any in-flight search to prevent race conditions and outdated results
        currentSearchTask?.cancel()

        // Create and track the new search task
        let task = SearchTask {
            try await performSearch(queryFragment: queryFragment)
        }

        currentSearchTask = task

        // Execute the search and return results
        return try await task.value
    }

    /// Retrieves detailed placemark information for a given search completion result.
    ///
    /// This method performs a secondary search using MapKit's MKLocalSearch to obtain
    /// detailed location information including coordinates, address components, and
    /// other metadata. It converts the completion's title and subtitle into a natural
    /// language query for the detailed search.
    ///
    /// - Parameter searchCompletion: The search completion result to get detailed information for.
    /// - Returns: A `Placemark` object containing detailed location information if found,
    ///           nil if no detailed information is available.
    /// - Throws:
    ///   - `LocationSearchError.mapKitError` if MapKit encounters an error during the search
    ///   - `LocationSearchError.searchCompletionFailed` if the operation fails or returns invalid data
    ///
    /// Example usage:
    /// ```swift
    /// let completion: LocalSearchCompletion = // ... from search results
    /// do {
    ///     if let placemark = try await searcher.placemark(for: completion) {
    ///         print("Coordinates: \(placemark.coordinate)")
    ///         print("Address: \(placemark.thoroughfare ?? "Unknown")")
    ///     }
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    public func placemark(for searchCompletion: LocalSearchCompletion) async throws -> Placemark? {
        try await withCheckedThrowingContinuation { continuation in
            let localSearch = searchCompletion.localSearch()

            localSearch.start { response, error in
                // Handle any errors from the MapKit search operation
                if let error {
                    if let mkError = error as? MKError {
                        logger.error("MapKit error during placemark search: \(mkError)")
                        continuation.resume(throwing: LocationSearchError.mapKitError(mkError))
                    } else {
                        logger.error("Unexpected error during placemark search: \(error)")
                        continuation.resume(throwing: error)
                    }
                    return
                }
                // Validate that we received a response from MapKit
                // MapKit guarantees either error or response will be non-nil
                guard let response else {
                    logger.error("MapKit returned neither error nor response for: \(searchCompletion)")
                    continuation.resume(throwing: LocationSearchError.searchCompletionFailed)
                    return
                }

                // Extract the placemark from the first map item in the response
                // Some searches may not return detailed placemark information
                guard let placemark = response.mapItems.first?.placemark else {
                    logger.error("No placemark found in search response for: \(searchCompletion)")
                    continuation.resume(throwing: LocationSearchError.searchCompletionFailed)
                    return
                }
                // Convert the MKPlacemark to our Sendable Placemark type
                continuation.resume(
                    returning: Placemark(placemark: placemark),
                )
            }
        }
    }

    // MARK: - Private Search Implementation

    /// Performs the actual search operation using MapKit's search completer.
    ///
    /// This method creates a new search completer for each search operation to avoid
    /// continuation conflicts that could occur when reusing delegate-based objects
    /// across multiple concurrent operations. The approach ensures thread safety
    /// and proper cleanup of MapKit resources.
    ///
    /// The method uses withTaskCancellationHandler to properly cancel MapKit operations
    /// when the Swift concurrency task is cancelled, preventing resource leaks and
    /// ensuring responsive cancellation behavior.
    ///
    /// - Parameter queryFragment: The search query string to search for.
    /// - Returns: An array of search completion results matching the query.
    /// - Throws: LocationSearchError if the search fails or is cancelled.
    @MainActor
    private func performSearch(queryFragment: String) async throws -> [LocalSearchCompletion] {
        // Create fresh instances for each search to prevent delegate callback conflicts
        // This approach ensures that concurrent searches don't interfere with each other
        let searchCompleter = MKLocalSearchCompleter()
        let localSearchCompleterHandler = LocalSearchCompleterHandler()
        searchCompleter.delegate = localSearchCompleterHandler

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Use a flag to ensure continuation is only resumed once
                // This prevents race conditions if MapKit calls multiple delegate methods
                var hasResumed = false

                localSearchCompleterHandler.completionHandler = { result in
                    guard !hasResumed else { return }
                    hasResumed = true

                    switch result {
                    case let .success(completions):
                        logger.debug("Successfully searched \(queryFragment)")
                        continuation.resume(with: .success(completions))
                    case let .failure(error):
                        logger.error("failed to search \(queryFragment): \(error)")
                        continuation.resume(throwing: error)
                    }
                }

                // Initiate the MapKit search by setting the query fragment
                // This triggers the delegate callbacks asynchronously
                logger.debug("Starting MapKit search for: \(queryFragment)")
                searchCompleter.queryFragment = queryFragment
            }
        } onCancel: {
            // Ensure MapKit resources are properly cleaned up on cancellation
            // This prevents the completer from continuing to work in the background
            logger.debug("Cancelling MapKit search for: \(queryFragment)")
            searchCompleter.cancel()
        }
    }
}

// MARK: - Private Delegate Handler

/// A delegate handler class for managing `MKLocalSearchCompleter` callbacks.
///
/// This class bridges MapKit's delegate-based API with Swift's modern async/await
/// concurrency model. It converts the traditional delegate callbacks into a
/// completion handler pattern that can be easily integrated with Swift concurrency.
///
/// The handler is designed to be used once per search operation and then discarded,
/// which prevents issues with delegate callback conflicts when multiple searches
/// are performed concurrently.
private final class LocalSearchCompleterHandler: NSObject, MKLocalSearchCompleterDelegate {
    /// The completion handler to call when search results are available.
    ///
    /// This closure bridges the delegate callbacks to the async/await continuation,
    /// enabling the search operation to return results through Swift concurrency.
    var completionHandler: ((Result<[LocalSearchCompletion], Error>) -> Void)?

    /// Called when MapKit successfully completes a search with results.
    ///
    /// This delegate method converts the MKLocalSearchCompletion objects to our
    /// Sendable LocalSearchCompletion type and notifies the completion handler.
    ///
    /// - Parameter completer: The search completer that generated the results.
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mappedResults = completer.results.map { LocalSearchCompletion($0) }
        completionHandler?(.success(mappedResults))
    }

    /// Called when MapKit encounters an error during the search operation.
    ///
    /// This delegate method handles search failures by logging the error and
    /// converting it to our standardized LocationSearchError type.
    ///
    /// - Parameters:
    ///   - completer: The search completer that encountered the error.
    ///   - error: The error that occurred during the search operation.
    func completer(_: MKLocalSearchCompleter, didFailWithError error: Error) {
        logger.error("MapKit search completer failed with error: \(error)")
        completionHandler?(.failure(LocationSearchError.searchCompletionFailed))
    }
}

// MARK: - Private Extensions

/// Private extension to convert LocalSearchCompletion to MKLocalSearch.
private extension LocalSearchCompletion {
    /// Creates an MKLocalSearch configured with this completion's information.
    ///
    /// This method combines the title and subtitle of the search completion to create
    /// a natural language query for detailed location lookup. The combined text
    /// provides MapKit with enough context to return detailed placemark information.
    ///
    /// - Returns: A configured MKLocalSearch ready to perform a detailed location search.
    func localSearch() -> MKLocalSearch {
        let request = MKLocalSearch.Request()
        // Combine title and subtitle for the most comprehensive search query
        request.naturalLanguageQuery = "\(title) \(subTitle)".trimmingCharacters(in: .whitespaces)
        return .init(request: request)
    }
}
