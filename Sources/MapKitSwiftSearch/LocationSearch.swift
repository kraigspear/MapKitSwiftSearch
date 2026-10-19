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

protocol LocalSearchProtocol: AnyObject {
    func start(completionHandler: @escaping @Sendable (MKLocalSearch.Response?, Error?) -> Void)
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

    // MARK: - Concurrent Tasks

    private typealias SearchTask = Task<[LocalSearchCompletion], Error>

    /// The MapKit search a call is waiting on, kept apart from the call so a newer call
    /// with the same query fragment can take it over (Docs/adr/0006).
    private struct InFlightSearch {
        let queryFragment: String
        let task: SearchTask
    }

    /// Bumped by every call, so a call can tell whether a newer one has superseded it.
    private var generation = 0

    /// The latest call's debounce and wait, held so a newer call can cancel it.
    private var currentCall: SearchTask?
    private var inFlightSearch: InFlightSearch?

    private let completerFactory: () -> any LocalSearchCompleterProtocol
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
        completerFactory: @escaping () -> any LocalSearchCompleterProtocol,
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
    /// - A newer call with the same query fragment as a MapKit search still running takes
    ///   that search over instead of starting another. Once a search has finished, the same
    ///   query fragment searches again; nothing is cached.
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
        generation += 1
        let callGeneration = generation
        currentCall?.cancel()
        currentCall = nil

        let takesOverInFlightSearch = inFlightSearch?.queryFragment == queryFragment
        if !takesOverInFlightSearch {
            inFlightSearch?.task.cancel()
            inFlightSearch = nil
        }

        guard !queryFragment.isEmpty, queryFragment.count >= numberOfCharactersBeforeSearching else {
            // Checked after superseding, so a cancelled caller still ends the older search
            try Task.checkCancellation()
            let minimumCharacters = numberOfCharactersBeforeSearching
            logger.debug("Query shorter than \(minimumCharacters) characters, returning no completions")
            return []
        }

        let call = SearchTask {
            if !takesOverInFlightSearch {
                try await debounceSleep(debounceSearchDelay)
                try Task.checkCancellation()
            }
            // A takeover superseded before this task ran must not restart the search the newer call gave up.
            // A takeover whose own caller was cancelled goes on, so it can cancel the search nobody wants.
            guard generation == callGeneration else {
                throw CancellationError()
            }
            return try await completions(for: queryFragment, generation: callGeneration)
        }
        currentCall = call

        let result = await withTaskCancellationHandler {
            await call.result
        } onCancel: {
            call.cancel()
        }

        // MapKit can answer in the same turn a newer call arrives, so the call's task can
        // finish with completions or a failure after it was superseded
        guard generation == callGeneration, !Task.isCancelled else {
            throw CancellationError()
        }
        return try result.get()
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

    /// Waits for the in-flight MapKit search for the query fragment, starting one if none is running.
    ///
    /// The wait ends as soon as this call is cancelled, but only a call that is still the
    /// latest cancels the MapKit search: a superseding call with the same query fragment
    /// is waiting on it too.
    private func completions(
        for queryFragment: String,
        generation callGeneration: Int,
    ) async throws -> [LocalSearchCompletion] {
        let search: SearchTask
        if let inFlightSearch, inFlightSearch.queryFragment == queryFragment {
            search = inFlightSearch.task
        } else {
            search = SearchTask { try await performSearch(queryFragment: queryFragment) }
            inFlightSearch = InFlightSearch(queryFragment: queryFragment, task: search)
        }

        do {
            let completions = try await search.valueUntilCancelled()
            finishInFlightSearch(search)
            return completions
        } catch is CancellationError where generation == callGeneration {
            // The caller's task was cancelled, not superseded, so nobody else wants the search
            search.cancel()
            finishInFlightSearch(search)
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            finishInFlightSearch(search)
            throw error
        }
    }

    /// Forgets a finished search, so the next call with its query fragment searches again.
    private func finishInFlightSearch(_ search: SearchTask) {
        if inFlightSearch?.task == search {
            inFlightSearch = nil
        }
    }

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

// MARK: - Waiting Without Cancelling

private extension Task where Success: Sendable, Failure == any Error {
    /// The task's value, or `CancellationError` as soon as the waiting task is cancelled.
    ///
    /// Unlike `value`, the wait answers the waiter's cancellation without cancelling this task,
    /// which another waiter may still need.
    func valueUntilCancelled() async throws -> Success {
        let waiter = Waiter<Success>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiter.store(continuation)
                // A cancellation that came before the continuation was stored found nothing to resume
                guard !Task<Never, Never>.isCancelled else {
                    waiter.resume(with: .failure(Swift.CancellationError()))
                    return
                }
                Task<Void, Never> {
                    await waiter.resume(with: self.result)
                }
            }
        } onCancel: {
            waiter.resume(with: .failure(Swift.CancellationError()))
        }
    }
}

/// Resumes a continuation exactly once, from whichever comes first.
private final class Waiter<Value: Sendable>: Sendable {
    private let continuation = Mutex<CheckedContinuation<Value, any Error>?>(nil)

    func store(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation.withLock { $0 = continuation }
    }

    func resume(with result: Result<Value, any Error>) {
        continuation.withLock { $0.take() }?.resume(with: result)
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
