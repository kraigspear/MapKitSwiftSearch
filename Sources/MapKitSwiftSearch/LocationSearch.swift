@preconcurrency import MapKit
import Observation
import os
import Synchronization

/// An error that ``LocationSearch`` throws.
///
/// A superseded search throws `CancellationError`, not a case of this enum.
public enum LocationSearchError: LocalizedError, Equatable {
    /// A placemark search returned no map item.
    case searchCompletionFailed

    /// MapKit failed with an `MKError`, such as `.loadingThrottled` when the search
    /// completer has had too many requests.
    case mapKitError(MKError)

    public var errorDescription: String? {
        switch self {
        case .searchCompletionFailed:
            "Unable to complete location search"
        case let .mapKitError(mkError):
            "MapKit error: \(mkError)"
        }
    }
}

/// One MapKit completer search: a query fragment in, its completions out.
@MainActor
protocol LocalSearchCompleterProtocol {
    /// Returns the completions for the query fragment.
    ///
    /// - Throws: `CancellationError` if the calling task is cancelled before the completer answers,
    ///   or the completer's own error if it fails.
    func completions(for queryFragment: String) async throws -> [LocalSearchCompletion]
}

/// One MapKit search that resolves a completion: the completion in, its map items out.
///
/// It returns map items rather than `MKLocalSearch.Response`, which tests can't build.
@MainActor
protocol LocalSearchProtocol: Sendable {
    /// Returns MapKit's map items for the completion this search was made for.
    ///
    /// - Throws: MapKit's error, including the one it reports after ``cancel()``.
    func start() async throws -> [MKMapItem]

    /// Stops the search, so ``start()`` ends early.
    func cancel()
}

/// Bridges one `MKLocalSearchCompleter` search to async.
///
/// Make one adapter per search: a completer reused for a newer fragment can still deliver
/// results for an older one.
@MainActor
final class MKLocalSearchCompleterAdapter: NSObject, LocalSearchCompleterProtocol {
    private let completer: MKLocalSearchCompleter

    /// Taken by whichever comes first, MapKit's answer or the task's cancellation, so the
    /// search resumes exactly once.
    private nonisolated let continuation = Mutex<CheckedContinuation<[LocalSearchCompletion], Error>?>(nil)

    /// Tests pass a completer subclass that never reaches MapKit.
    init(completer: MKLocalSearchCompleter = MKLocalSearchCompleter()) {
        self.completer = completer
        super.init()
    }

    func completions(for queryFragment: String) async throws -> [LocalSearchCompletion] {
        // The completer holds its delegate weakly, so the call keeps the adapter alive until it ends
        defer { withExtendedLifetime(self) {} }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation.withLock { $0 = continuation }
                // A cancellation that came before the continuation was stored found nothing to resume
                guard !Task.isCancelled else {
                    resume(with: .failure(CancellationError()))
                    return
                }
                completer.delegate = self
                // Setting the query fragment starts MapKit's search
                completer.queryFragment = queryFragment
            }
        } onCancel: {
            resume(with: .failure(CancellationError()))
            // onCancel can run on any thread, and the completer belongs to the main actor.
            // cancel() doesn't notify the delegate.
            Task { @MainActor in
                self.completer.cancel()
            }
        }
    }

    private nonisolated func resume(with result: Result<[LocalSearchCompletion], Error>) {
        continuation.withLock { $0.take() }?.resume(with: result)
    }
}

extension MKLocalSearchCompleterAdapter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        resume(with: .success(completer.results.map { LocalSearchCompletion($0) }))
    }

    nonisolated func completer(_: MKLocalSearchCompleter, didFailWithError error: Error) {
        resume(with: .failure(error))
    }
}

/// Resolves a completion through `MKLocalSearch`.
@MainActor
final class MKLocalSearchAdapter: LocalSearchProtocol {
    private let search: MKLocalSearch

    init(completion: MKLocalSearchCompletion) {
        search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
    }

    func start() async throws -> [MKMapItem] {
        try await search.start().mapItems
    }

    func cancel() {
        search.cancel()
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

    // MARK: - Concurrent Tasks

    private typealias SearchTask = Task<[LocalSearchCompletion], Error>

    /// The latest call's debounce and MapKit search, held so a newer call can cancel it.
    private var currentSearch: SearchTask?

    private let completerFactory: () -> any LocalSearchCompleterProtocol
    private let localSearchFactory: (MKLocalSearchCompletion) -> any LocalSearchProtocol

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
            localSearchFactory: { MKLocalSearchAdapter(completion: $0) },
        )
    }

    /// Creates a location search whose MapKit calls and debounce clock tests can replace.
    init(
        numberOfCharactersBeforeSearching: Int,
        debounceSearchDelay: Duration,
        completerFactory: @escaping () -> any LocalSearchCompleterProtocol,
        localSearchFactory: @escaping (MKLocalSearchCompletion) -> any LocalSearchProtocol,
        debounceSleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    ) {
        self.numberOfCharactersBeforeSearching = numberOfCharactersBeforeSearching
        self.debounceSearchDelay = debounceSearchDelay
        self.completerFactory = completerFactory
        self.localSearchFactory = localSearchFactory
        self.debounceSleep = debounceSleep
    }

    // MARK: - Public Search Methods

    /// Returns MapKit's completions for the query fragment, asking MapKit only after a debounce delay.
    ///
    /// Call it on every change to the search text. Only the latest call returns completions:
    ///
    /// - A newer call supersedes this one at once, during its debounce or while MapKit
    ///   searches, and this call throws `CancellationError`. Ignore it and keep the current
    ///   results.
    /// - Cancelling the calling task also throws `CancellationError` and cancels the MapKit search.
    /// - An empty query, or one shorter than `numberOfCharactersBeforeSearching`, returns an
    ///   empty array without waiting for the debounce.
    /// - A newer call with the same query fragment supersedes this one like any other and
    ///   starts its own MapKit search after its debounce; nothing is cached.
    ///
    /// MapKit throttles the search completer after about 100 requests in roughly 100 seconds,
    /// failing with `MKError.loadingThrottled` until the window passes. Treat that failure as
    /// "keep the current results" rather than alerting.
    ///
    /// - Parameter queryFragment: The text typed so far.
    /// - Returns: MapKit's completions, or an empty array for an empty or too-short query.
    /// - Throws:
    ///   - `CancellationError` if a newer call supersedes this one, or the calling task is cancelled.
    ///   - ``LocationSearchError/mapKitError(_:)`` if MapKit fails with an `MKError`,
    ///     including `.loadingThrottled`.
    ///   - Any other error MapKit reports, unchanged.
    public func search(queryFragment: String) async throws -> [LocalSearchCompletion] {
        currentSearch?.cancel()
        currentSearch = nil

        guard !queryFragment.isEmpty, queryFragment.count >= numberOfCharactersBeforeSearching else {
            // Checked after superseding, so a cancelled caller still ends the older search
            try Task.checkCancellation()
            let minimumCharacters = numberOfCharactersBeforeSearching
            logger.debug("Query shorter than \(minimumCharacters) characters, returning no completions")
            return []
        }

        let search = SearchTask {
            try await debounceSleep(debounceSearchDelay)
            try Task.checkCancellation()
            return try await performSearch(queryFragment: queryFragment)
        }
        currentSearch = search

        let result = await withTaskCancellationHandler {
            await search.result
        } onCancel: {
            search.cancel()
        }

        // MapKit can answer in the same turn a newer call arrives, so the search can finish
        // with completions or a failure after it was superseded
        guard currentSearch == search, !Task.isCancelled else {
            throw CancellationError()
        }
        return try result.get()
    }

    /// Resolves a search completion to a placemark.
    ///
    /// Hands MapKit the completion it suggested, so the placemark is the place the user tapped,
    /// including a "Search Nearby" category completion, which resolves to a nearby branch.
    /// Calls don't supersede each other: each resolves its own completion, so a caller that
    /// wants only the latest tap cancels the earlier call's task.
    ///
    /// - Parameter searchCompletion: A completion from ``search(queryFragment:)``.
    /// - Returns: The placemark for MapKit's first map item. Currently never `nil`: when MapKit
    ///   finds none, this throws ``LocationSearchError/searchCompletionFailed``.
    /// - Throws:
    ///   - `CancellationError` if the calling task is cancelled, which also cancels the MapKit search.
    ///   - ``LocationSearchError/mapKitError(_:)`` if MapKit fails with an `MKError`, or with
    ///     `.placemarkNotFound` for a completion that didn't come from ``search(queryFragment:)``.
    ///   - ``LocationSearchError/searchCompletionFailed`` if MapKit returns no map item.
    ///   - Any other error MapKit reports, unchanged.
    public func placemark(for searchCompletion: LocalSearchCompletion) async throws -> Placemark? {
        try Task.checkCancellation()
        guard let mapKitCompletion = searchCompletion.mapKitCompletion else {
            logger.error("No MapKit completion to resolve for: \(searchCompletion)")
            throw LocationSearchError.mapKitError(MKError(.placemarkNotFound))
        }

        let localSearch = localSearchFactory(mapKitCompletion)
        let result = await withTaskCancellationHandler {
            await Result { try await localSearch.start() }
        } onCancel: {
            // onCancel can run on any thread, and the search belongs to the main actor
            Task { @MainActor in
                localSearch.cancel()
            }
        }

        // MapKit can answer before the cancel reaches it, so a cancelled call can still have map items
        try Task.checkCancellation()
        do {
            guard let mapItem = try result.get().first else {
                logger.error("No map item found for: \(searchCompletion)")
                throw LocationSearchError.searchCompletionFailed
            }
            return Placemark(mapItem: mapItem)
        } catch let mkError as MKError {
            logger.error("MapKit error during placemark search: \(mkError)")
            throw LocationSearchError.mapKitError(mkError)
        }
    }

    // MARK: - Private Search Implementation

    /// Runs one MapKit completer search for the query fragment.
    ///
    /// Each search gets a fresh completer, so a late answer for an older query can't reach it.
    ///
    /// - Throws: `CancellationError` if the task is cancelled before MapKit answers,
    ///   ``LocationSearchError/mapKitError(_:)`` for an `MKError`, or the completer's other errors unchanged.
    private func performSearch(queryFragment: String) async throws -> [LocalSearchCompletion] {
        logger.debug("Starting MapKit search for: \(queryFragment)")
        do {
            let completions = try await completerFactory().completions(for: queryFragment)
            logger.debug("Successfully searched \(queryFragment)")
            return completions
        } catch let error as CancellationError {
            logger.debug("Cancelled MapKit search for: \(queryFragment)")
            throw error
        } catch let mkError as MKError {
            logger.error("MapKit search completer failed for \(queryFragment): \(mkError)")
            throw LocationSearchError.mapKitError(mkError)
        } catch {
            logger.error("MapKit search completer failed for \(queryFragment): \(error)")
            throw error
        }
    }
}
