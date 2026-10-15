@preconcurrency import MapKit
import Observation
import os

/// An error that ``LocationSearch`` throws.
public enum LocationSearchError: LocalizedError, Equatable {
    /// MapKit's search completer failed, or a placemark search returned no map item.
    case searchCompletionFailed

    /// MapKit failed while resolving a placemark.
    case mapKitError(MKError)

    /// The query is not empty but is shorter than the minimum length.
    case invalidSearchCriteria

    /// The query repeats the last query that finished its debounce.
    case duplicateSearchCriteria

    /// A newer search started during this one's debounce delay.
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

protocol LocalSearchCompleterProtocol: AnyObject {
    var delegate: LocalSearchCompleterDelegate? { get set }
    var queryFragment: String { get set }
    func cancel()
}

protocol LocalSearchCompleterDelegate: AnyObject {
    func completerDidUpdateResults(_ results: [LocalSearchCompletion])
    func completerDidFail(with error: Error)
}

protocol LocalSearchProtocol: AnyObject {
    func start(completionHandler: @escaping @Sendable (MKLocalSearch.Response?, Error?) -> Void)
}

private final class MKLocalSearchCompleterAdapter: NSObject, LocalSearchCompleterProtocol,
MKLocalSearchCompleterDelegate {
    weak var delegate: LocalSearchCompleterDelegate?

    private let completer = MKLocalSearchCompleter()

    var queryFragment: String {
        get { completer.queryFragment }
        set { completer.queryFragment = newValue }
    }

    override init() {
        super.init()
        completer.delegate = self
    }

    func cancel() {
        completer.cancel()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mappedResults = completer.results.map { LocalSearchCompletion($0) }
        delegate?.completerDidUpdateResults(mappedResults)
    }

    func completer(_: MKLocalSearchCompleter, didFailWithError error: Error) {
        delegate?.completerDidFail(with: error)
    }
}

private final class MKLocalSearchAdapter: LocalSearchProtocol {
    private let search: MKLocalSearch

    init(search: MKLocalSearch) {
        self.search = search
    }

    func start(completionHandler: @escaping @Sendable (MKLocalSearch.Response?, Error?) -> Void) {
        search.start(completionHandler: completionHandler)
    }
}

// MARK: - Private Constants

private let logger = LogContext.locationSearch.logger()

/// Debounced, async location search over MapKit's search completer.
///
/// Call ``search(queryFragment:)`` as the user types, then ``placemark(for:)`` to resolve
/// the completion they pick. A newer search supersedes an older one on the same instance,
/// so give each search field its own `LocationSearch`.
///
/// ```swift
/// let locationSearch = LocationSearch()
/// let completions = try await locationSearch.search(queryFragment: "Apple Park")
/// if let first = completions.first,
///    let placemark = try await locationSearch.placemark(for: first) {
///     print(placemark.name ?? "", placemark.coordinate)
/// }
/// ```
@MainActor
public final class LocationSearch {
    // MARK: - Configuration

    private let debounceSearchDelay: Duration
    private let numberOfCharactersBeforeSearching: Int

    // MARK: - State

    /// The last query that finished its debounce, for duplicate detection.
    private var lastSearchQuery: String?

    // MARK: - Concurrent Tasks

    private typealias SearchTask = Task<[LocalSearchCompletion], Error>

    // Unstructured tasks, held so a newer call can cancel them (Docs/adr/0001).
    private var currentSearchTask: SearchTask?
    private var debounceTask: Task<Bool, Never>?

    private let completerFactory: () -> LocalSearchCompleterProtocol
    private let localSearchFactory: (LocalSearchCompletion) -> LocalSearchProtocol

    /// Injected so tests control when a debounce ends relative to MapKit's results.
    private let debounceSleep: (Duration) async throws -> Void

    // MARK: - Initialization

    /// Creates a location search.
    ///
    /// - Parameters:
    ///   - numberOfCharactersBeforeSearching: The minimum query length that reaches MapKit.
    ///   - debounceSearchDelay: How long each search waits for a newer one before it runs.
    public convenience init(
        numberOfCharactersBeforeSearching: Int = 5,
        debounceSearchDelay: Duration = .milliseconds(300),
    ) {
        self.init(
            numberOfCharactersBeforeSearching: numberOfCharactersBeforeSearching,
            debounceSearchDelay: debounceSearchDelay,
            completerFactory: { MKLocalSearchCompleterAdapter() },
            localSearchFactory: { completion in
                MKLocalSearchAdapter(search: completion.localSearch())
            },
        )
    }

    /// Creates a location search whose MapKit calls and debounce clock tests can replace.
    init(
        numberOfCharactersBeforeSearching: Int,
        debounceSearchDelay: Duration,
        completerFactory: @escaping () -> LocalSearchCompleterProtocol,
        localSearchFactory: @escaping (LocalSearchCompletion) -> LocalSearchProtocol,
        debounceSleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    ) {
        self.numberOfCharactersBeforeSearching = numberOfCharactersBeforeSearching
        self.debounceSearchDelay = debounceSearchDelay
        self.completerFactory = completerFactory
        self.localSearchFactory = localSearchFactory
        self.debounceSleep = debounceSleep
    }

    // MARK: - Public Search Methods

    /// Returns MapKit's completions for partial search text, after a debounce delay.
    ///
    /// Call it on every change to the search text. A newer call supersedes this one; treat
    /// ``LocationSearchError/debounce``, ``LocationSearchError/duplicateSearchCriteria``, and
    /// `CancellationError` as "keep the current results", not as failures. Cancelling the
    /// calling task stops neither the debounce nor the MapKit search.
    ///
    /// - Parameter queryFragment: The text typed so far.
    /// - Returns: MapKit's completions, or an empty array for an empty query.
    /// - Throws:
    ///   - ``LocationSearchError/debounce`` if a newer call starts during the debounce delay.
    ///   - ``LocationSearchError/duplicateSearchCriteria`` if the query repeats the last one to
    ///     finish its debounce, even when empty. A search already running for it continues.
    ///   - ``LocationSearchError/invalidSearchCriteria`` if the query is shorter than the minimum length.
    ///   - ``LocationSearchError/searchCompletionFailed`` if MapKit's completer fails.
    ///   - `CancellationError` if a newer call with a different query, even an empty or too-short
    ///     one, finishes its debounce while this call's MapKit search is running.
    public func search(queryFragment: String) async throws -> [LocalSearchCompletion] {
        debounceTask?.cancel()

        let newDebounceTask = Task {
            do {
                logger.debug("Starting debounce")
                try await debounceSleep(debounceSearchDelay)
                logger.debug("Completed debounce")
                return true
            } catch {
                logger.debug("debounce cancelled")
                return false
            }
        }
        debounceTask = newDebounceTask

        guard await newDebounceTask.value else {
            throw LocationSearchError.debounce
        }

        logger.debug("Debounce completed successfully, proceeding with search")

        // Checked before the cancel below, so repeating the in-flight query leaves that search running
        guard lastSearchQuery != queryFragment else {
            logger.debug("Query unchanged, skipping duplicate search: \(queryFragment)")
            throw LocationSearchError.duplicateSearchCriteria
        }

        lastSearchQuery = queryFragment

        // Cancel before the early exits below, or the older search would deliver
        // its results after this call returns
        currentSearchTask?.cancel()

        guard !queryFragment.isEmpty else {
            logger.debug("Empty query provided, returning empty results")
            return []
        }

        guard queryFragment.count >= numberOfCharactersBeforeSearching else {
            let minimumCharacters = numberOfCharactersBeforeSearching
            logger.debug("Query too short (\(queryFragment.count) chars, need \(minimumCharacters))")
            throw LocationSearchError.invalidSearchCriteria
        }

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
    }

    /// Resolves a search completion to a placemark.
    ///
    /// Runs a new MapKit search for the completion's title and subtitle, so the result is
    /// MapKit's first match for that text. Cancelling the calling task doesn't cancel the search.
    ///
    /// - Parameter searchCompletion: A completion from ``search(queryFragment:)``.
    /// - Returns: The placemark for MapKit's first match. Currently never `nil`: when MapKit
    ///   finds no match, this throws ``LocationSearchError/searchCompletionFailed``.
    /// - Throws:
    ///   - ``LocationSearchError/mapKitError(_:)`` if MapKit fails with an `MKError`.
    ///   - ``LocationSearchError/searchCompletionFailed`` if MapKit returns no map item.
    ///   - Any other error MapKit reports, unchanged.
    public func placemark(for searchCompletion: LocalSearchCompletion) async throws -> Placemark? {
        try await withCheckedThrowingContinuation { continuation in
            let localSearch = localSearchFactory(searchCompletion)

            localSearch.start { response, error in
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
                // MapKit guarantees either error or response will be non-nil
                guard let response else {
                    logger.error("MapKit returned neither error nor response for: \(searchCompletion)")
                    continuation.resume(throwing: LocationSearchError.searchCompletionFailed)
                    return
                }

                guard let mapItem = response.mapItems.first else {
                    logger.error("No map item found in search response for: \(searchCompletion)")
                    continuation.resume(throwing: LocationSearchError.searchCompletionFailed)
                    return
                }

                continuation.resume(returning: Placemark(mapItem: mapItem))
            }
        }
    }

    // MARK: - Private Search Implementation

    /// Runs one MapKit completer search for the query.
    ///
    /// Each call gets its own completer, handler, and cancellation state, so a late delegate
    /// callback can only resume its own search's continuation.
    ///
    /// - Throws: `LocationSearchError.searchCompletionFailed` if the completer fails, or
    ///   `CancellationError` if the task is cancelled before MapKit answers.
    @MainActor
    private func performSearch(queryFragment: String) async throws -> [LocalSearchCompletion] {
        let searchCompleter = completerFactory()
        let localSearchCompleterHandler = LocalSearchCompleterHandler()
        searchCompleter.delegate = localSearchCompleterHandler

        let cancellationState = SearchCancellationState(searchCompleter: searchCompleter)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                cancellationState.setContinuation(continuation)

                localSearchCompleterHandler.completionHandler = { result in
                    Task { @MainActor in
                        switch result {
                        case let .success(completions):
                            logger.debug("Successfully searched \(queryFragment)")
                            cancellationState.resume(with: .success(completions))
                        case let .failure(error):
                            logger.error("failed to search \(queryFragment): \(error)")
                            cancellationState.resume(with: .failure(error))
                        }
                    }
                }

                // Setting the query fragment starts MapKit's search
                logger.debug("Starting MapKit search for: \(queryFragment)")
                searchCompleter.queryFragment = queryFragment
            }
        } onCancel: {
            // onCancel isn't main-actor isolated, so hop to reach the cancellation state
            logger.debug("Cancelling MapKit search for: \(queryFragment)")
            Task { @MainActor in
                cancellationState.cancel()
            }
        }
    }
}

// MARK: - Private Delegate Handler

/// Forwards one search's completer callbacks to its continuation, mapping every failure
/// to `LocationSearchError.searchCompletionFailed`.
private final class LocalSearchCompleterHandler: LocalSearchCompleterDelegate {
    var completionHandler: ((Result<[LocalSearchCompletion], Error>) -> Void)?

    func completerDidUpdateResults(_ results: [LocalSearchCompletion]) {
        completionHandler?(.success(results))
    }

    func completerDidFail(with error: Error) {
        logger.error("MapKit search completer failed with error: \(error)")
        completionHandler?(.failure(LocationSearchError.searchCompletionFailed))
    }
}

/// Resumes a search's continuation exactly once, whether MapKit answers or the task is cancelled first.
@MainActor
private final class SearchCancellationState: @unchecked Sendable {
    private var hasResumed = false
    private var continuation: CheckedContinuation<[LocalSearchCompletion], Error>?
    private let searchCompleter: LocalSearchCompleterProtocol

    init(searchCompleter: LocalSearchCompleterProtocol) {
        self.searchCompleter = searchCompleter
    }

    func setContinuation(_ continuation: CheckedContinuation<[LocalSearchCompletion], Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<[LocalSearchCompletion], Error>) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(with: result)
    }

    func cancel() {
        guard !hasResumed else {
            searchCompleter.cancel()
            return
        }
        hasResumed = true
        continuation?.resume(throwing: CancellationError())
        searchCompleter.cancel()
    }
}

// MARK: - Private Extensions

private extension LocalSearchCompletion {
    /// A text search for this completion's title and subtitle.
    ///
    /// The snapshot no longer holds MapKit's completion to search with (Docs/adr/0002).
    func localSearch() -> MKLocalSearch {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(title) \(subTitle)".trimmingCharacters(in: .whitespaces)
        return .init(request: request)
    }
}
