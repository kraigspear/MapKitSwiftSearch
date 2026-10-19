import Foundation
import MapKit
import Synchronization
import Testing
@testable import MapKitSwiftSearch

/// The time limit turns a continuation that is never resumed into a failure instead of a hang.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LocationSearchUnitTests {
    /// Answers a search with completions or an error when the test says so, and records cancellation.
    @MainActor
    final class FakeSearchCompleter: LocalSearchCompleterProtocol {
        private(set) var searchedFragments: [String] = []
        private(set) var cancellationCount = 0
        private var answer: AsyncThrowingStream<[LocalSearchCompletion], Error>.Continuation?

        func completions(for queryFragment: String) async throws -> [LocalSearchCompletion] {
            let (answers, answer) = AsyncThrowingStream<[LocalSearchCompletion], Error>.makeStream()
            self.answer = answer
            searchedFragments.append(queryFragment)
            // The stream ends without an answer when the task is cancelled
            for try await completions in answers {
                return completions
            }
            cancellationCount += 1
            throw CancellationError()
        }

        func sendResults(_ results: [LocalSearchCompletion]) {
            answer?.yield(results)
        }

        func sendError(_ error: Error) {
            answer?.finish(throwing: error)
        }
    }

    /// A debounce that ends only when the test releases it, or when its task is cancelled.
    @MainActor
    final class FakeDebounce {
        /// When false, a cancelled sleep returns instead of throwing, like a sleep that finished
        /// in the same turn its call was superseded.
        var honorsCancellation = true
        private(set) var sleepCount = 0
        private var releases: [AsyncStream<Void>.Continuation] = []

        func sleep(_: Duration) async throws {
            let (released, release) = AsyncStream<Void>.makeStream()
            releases.append(release)
            sleepCount += 1
            // The stream ends without a release when the task is cancelled
            for await _ in released {
                return
            }
            if honorsCancellation {
                throw CancellationError()
            }
        }

        func release() {
            releases.forEach { $0.yield() }
            releases.removeAll()
        }
    }

    final class FakeLocalSearch: LocalSearchProtocol {
        var onStart: ((@escaping @Sendable (MKLocalSearch.Response?, Error?) -> Void) -> Void)?

        func start(completionHandler: @escaping @Sendable (MKLocalSearch.Response?, Error?) -> Void) {
            onStart?(completionHandler)
        }
    }

    /// How MapKit answers a search that a newer call is superseding.
    enum MapKitAnswer: CaseIterable {
        case completions
        case failure

        @MainActor
        func deliver(to completer: FakeSearchCompleter) {
            switch self {
            case .completions:
                completer.sendResults([LocationSearchUnitTests.coffeeShopCompletion])
            case .failure:
                completer.sendError(MKError(.unknown))
            }
        }
    }

    /// What a caller shows after applying a search outcome, ignoring cancellation as callers should.
    enum DisplayedSearch: Equatable {
        case completions([LocalSearchCompletion])
        case failure
    }

    static let coffeeShopCompletion = LocalSearchCompletion(
        title: "Coffee shop",
        subTitle: "Grand Rapids, MI",
        titleHighlightRange: nil,
        subtitleHighlightRange: nil,
    )

    let fakeCompleter = FakeSearchCompleter()
    let fakeDebounce = FakeDebounce()

    /// A search over the fake completer whose debounce ends at once, or only when released.
    func makeLocationSearch(heldDebounce: Bool = false) -> LocationSearch {
        let fakeCompleter = fakeCompleter
        let fakeDebounce = fakeDebounce
        return LocationSearch(
            numberOfCharactersBeforeSearching: 5,
            debounceSearchDelay: .milliseconds(300),
            completerFactory: { fakeCompleter },
            localSearchFactory: { _ in FakeLocalSearch() },
            debounceSleep: heldDebounce ? { try await fakeDebounce.sleep($0) } : { _ in },
        )
    }

    /// Lets other main-actor work run until the condition holds.
    func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
        for _ in 0 ..< 1000 where !condition() {
            await Task.yield()
        }
        #expect(condition(), "Condition never held", sourceLocation: sourceLocation)
    }

    /// Starts a search for the query fragment and returns once MapKit is searching for it.
    func startInFlightSearch(
        _ queryFragment: String = "Coffee shop",
        on locationSearch: LocationSearch,
    ) async -> Task<[LocalSearchCompletion], Error> {
        let searchCount = fakeCompleter.searchedFragments.count
        let search = Task { try await locationSearch.search(queryFragment: queryFragment) }
        await waitUntil { fakeCompleter.searchedFragments.count > searchCount }
        return search
    }

    // MARK: - Supersession

    /// Verifies only the latest keystroke's suggestions appear.
    /// To replicate: type "Coffee shop" → type "Coffee shops" before suggestions appear → only the second list appears.
    @Test
    func `The latest call returns completions and the superseded call ends with CancellationError`() async throws {
        // Given: A search for "Coffee shop" waiting on MapKit
        let locationSearch = makeLocationSearch()
        let firstSearch = await startInFlightSearch(on: locationSearch)

        // When: A different query arrives and MapKit answers it
        let secondSearch = await startInFlightSearch("Coffee shops", on: locationSearch)
        fakeCompleter.sendResults([Self.coffeeShopCompletion])

        // Then: Only the newer call returns completions, and the older search was cancelled
        #expect(try await secondSearch.valueWithinTimeLimit == [Self.coffeeShopCompletion])
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        #expect(fakeCompleter.cancellationCount == 1)
    }

    @Test
    func `A call superseded during its debounce ends at once without waiting it out`() async throws {
        // Given: A search held in its debounce
        let locationSearch = makeLocationSearch(heldDebounce: true)
        let firstSearch = Task { try await locationSearch.search(queryFragment: "Coffee shop") }
        await waitUntil { fakeDebounce.sleepCount == 1 }

        // When: A newer call arrives while the first debounce is still held
        let secondSearch = Task { try await locationSearch.search(queryFragment: "Coffee shops") }

        // Then: The first call ends before any debounce is released, and never reaches MapKit
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        await waitUntil { fakeDebounce.sleepCount == 2 }
        fakeDebounce.release()
        await waitUntil { fakeCompleter.searchedFragments == ["Coffee shops"] }
        fakeCompleter.sendResults([Self.coffeeShopCompletion])
        #expect(try await secondSearch.valueWithinTimeLimit == [Self.coffeeShopCompletion])
    }

    @Test
    func `A call superseded as its debounce ends never starts a MapKit search`() async throws {
        // Given: A search held in a debounce that returns, rather than throws, when cancelled
        let locationSearch = makeLocationSearch(heldDebounce: true)
        fakeDebounce.honorsCancellation = false
        let firstSearch = Task { try await locationSearch.search(queryFragment: "Coffee shop") }
        await waitUntil { fakeDebounce.sleepCount == 1 }

        // When: A newer call supersedes it, then the newer debounce ends
        let secondSearch = Task { try await locationSearch.search(queryFragment: "Coffee shops") }
        await waitUntil { fakeDebounce.sleepCount == 2 }
        fakeDebounce.release()

        // Then: The superseded call ends with CancellationError and only the newer query reaches MapKit
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        await waitUntil { fakeCompleter.searchedFragments == ["Coffee shops"] }
        fakeCompleter.sendResults([Self.coffeeShopCompletion])
        #expect(try await secondSearch.valueWithinTimeLimit == [Self.coffeeShopCompletion])
    }

    /// Verifies a superseded search never shows results or an error, however close MapKit's answer
    /// comes to the newer call.
    /// To replicate: type "Coffee shop" → clear the field just as MapKit answers → list stays empty, no error.
    @Test(arguments: MapKitAnswer.allCases, 0 ..< 12)
    func `A superseded search that MapKit answers never overwrites newer results`(
        mapKitAnswer: MapKitAnswer,
        turnsBeforeNewerCall: Int,
    ) async {
        // Given: A search for "Coffee shop" waiting on MapKit
        let locationSearch = makeLocationSearch()
        var displayedSearch: DisplayedSearch?
        let firstSearch = Task {
            do {
                displayedSearch = try await .completions(locationSearch.search(queryFragment: "Coffee shop"))
            } catch is CancellationError {
            } catch {
                displayedSearch = .failure
            }
        }
        await waitUntil { !fakeCompleter.searchedFragments.isEmpty }

        // When: MapKit answers, and the field is cleared a few main-actor turns later
        mapKitAnswer.deliver(to: fakeCompleter)
        for _ in 0 ..< turnsBeforeNewerCall {
            await Task.yield()
        }
        let emptySearch = Task {
            displayedSearch = try await .completions(locationSearch.search(queryFragment: ""))
        }
        _ = await (firstSearch.resultWithinTimeLimit, emptySearch.resultWithinTimeLimit)

        // Then: The last outcome shown is the newer call's
        #expect(displayedSearch == .completions([]))
    }

    // MARK: - Caller Cancellation

    @Test
    func `Cancelling the caller's task cancels its MapKit search`() async {
        // Given: A search waiting on MapKit
        let locationSearch = makeLocationSearch()
        let search = await startInFlightSearch(on: locationSearch)

        // When: The caller's task is cancelled
        search.cancel()

        // Then: The call ends with CancellationError and MapKit's search is cancelled
        await #expect(throws: CancellationError.self) { try await search.valueWithinTimeLimit }
        await waitUntil { fakeCompleter.cancellationCount == 1 }
    }

    @Test
    func `Cancelling the caller's task during the debounce never reaches MapKit`() async {
        // Given: A search held in its debounce
        let locationSearch = makeLocationSearch(heldDebounce: true)
        let search = Task { try await locationSearch.search(queryFragment: "Coffee shop") }
        await waitUntil { fakeDebounce.sleepCount == 1 }

        // When: The caller's task is cancelled
        search.cancel()

        // Then: The call ends with CancellationError before MapKit is asked
        await #expect(throws: CancellationError.self) { try await search.valueWithinTimeLimit }
        #expect(fakeCompleter.searchedFragments.isEmpty)
    }

    @Test
    func `A call cancelled before it starts ends with CancellationError when taking over a search`() async {
        // Given: A search for "Coffee shop" waiting on MapKit
        let locationSearch = makeLocationSearch()
        let firstSearch = await startInFlightSearch(on: locationSearch)

        // When: A call for the same query fragment is cancelled before it runs
        let secondSearch = Task { try await locationSearch.search(queryFragment: "Coffee shop") }
        secondSearch.cancel()

        // Then: Both calls end with CancellationError, and the search nobody waits on is cancelled
        await #expect(throws: CancellationError.self) { try await secondSearch.valueWithinTimeLimit }
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        await waitUntil { fakeCompleter.cancellationCount == 1 }
        #expect(fakeCompleter.searchedFragments == ["Coffee shop"])
    }

    // MARK: - Empty and Short Queries

    @Test(arguments: ["", "Co"])
    func `An empty or short query returns no completions without a debounce`(queryFragment: String) async throws {
        let locationSearch = makeLocationSearch(heldDebounce: true)

        let completions = try await locationSearch.search(queryFragment: queryFragment)

        #expect(completions.isEmpty)
        #expect(fakeDebounce.sleepCount == 0)
        #expect(fakeCompleter.searchedFragments.isEmpty)
    }

    /// Verifies clearing the field, or deleting below the minimum length, while MapKit searches leaves no stale
    /// suggestions.
    /// To replicate: type "Coffee shop" → clear the field before suggestions appear → list stays empty.
    @Test(arguments: ["", "Co"])
    func `An empty or short query cancels the in-flight search`(queryFragment: String) async throws {
        // Given: A search for "Coffee shop" waiting on MapKit
        let locationSearch = makeLocationSearch()
        let firstSearch = await startInFlightSearch(on: locationSearch)

        // When: An empty or short query arrives, then MapKit answers the original search
        let completions = try await locationSearch.search(queryFragment: queryFragment)
        fakeCompleter.sendResults([Self.coffeeShopCompletion])

        // Then: The newer call returns nothing and the original search is cancelled
        #expect(completions.isEmpty)
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        #expect(fakeCompleter.cancellationCount == 1)
    }

    @Test(arguments: ["", "Co"])
    func `An empty or short query from a cancelled caller ends with CancellationError`(
        queryFragment: String,
    ) async throws {
        // Given: A search for "Coffee shop" waiting on MapKit
        let locationSearch = makeLocationSearch()
        let firstSearch = await startInFlightSearch(on: locationSearch)

        // When: An empty or short query arrives from a task cancelled before it runs
        let cancelledSearch = Task { try await locationSearch.search(queryFragment: queryFragment) }
        cancelledSearch.cancel()

        // Then: The cancelled call throws rather than returning no completions, and still ends the older search
        await #expect(throws: CancellationError.self) { try await cancelledSearch.valueWithinTimeLimit }
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        #expect(fakeCompleter.cancellationCount == 1)
    }

    // MARK: - Repeated Query Fragments

    /// Verifies retyping the query already in flight still delivers its results.
    /// To replicate: type "Coffee shop" → add and delete a character before suggestions appear → suggestions appear.
    @Test
    func `The same query fragment as the in-flight search takes that search over`() async throws {
        // Given: A search for "Coffee shop" waiting on MapKit
        let locationSearch = makeLocationSearch(heldDebounce: true)
        let firstSearch = Task { try await locationSearch.search(queryFragment: "Coffee shop") }
        await waitUntil { fakeDebounce.sleepCount == 1 }
        fakeDebounce.release()
        await waitUntil { fakeCompleter.searchedFragments.count == 1 }

        // When: The same query fragment arrives again, then MapKit answers
        let secondSearch = Task { try await locationSearch.search(queryFragment: "Coffee shop") }
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        fakeCompleter.sendResults([Self.coffeeShopCompletion])

        // Then: The newer call returns the original search's completions, without a debounce or a second search
        #expect(try await secondSearch.valueWithinTimeLimit == [Self.coffeeShopCompletion])
        #expect(fakeDebounce.sleepCount == 1)
        #expect(fakeCompleter.searchedFragments == ["Coffee shop"])
        #expect(fakeCompleter.cancellationCount == 0)
    }

    /// Verifies clearing the field just after retyping the in-flight query leaves no search running.
    /// To replicate: type "Coffee shop" → add and delete a character → clear the field before suggestions appear
    /// → no suggestions appear later.
    /// From one turn, the takeover's call has run `search` but its task hasn't started yet
    @Test(arguments: 1 ..< 4)
    func `A takeover superseded before it runs never restarts the search it gave up`(
        turnsBeforeNewerCall: Int,
    ) async throws {
        // Given: A search for "Coffee shop" waiting on MapKit, and a call for the same fragment taking it over
        let locationSearch = makeLocationSearch()
        let firstSearch = await startInFlightSearch(on: locationSearch)
        let takeover = Task { try await locationSearch.search(queryFragment: "Coffee shop") }
        for _ in 0 ..< turnsBeforeNewerCall {
            await Task.yield()
        }

        // When: The field is cleared
        let completions = try await locationSearch.search(queryFragment: "")

        // Then: Both older calls end with CancellationError, and no search for the cleared text is left running
        #expect(completions.isEmpty)
        await #expect(throws: CancellationError.self) { try await takeover.valueWithinTimeLimit }
        await #expect(throws: CancellationError.self) { try await firstSearch.valueWithinTimeLimit }
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        #expect(fakeCompleter.searchedFragments == ["Coffee shop"])
        #expect(fakeCompleter.cancellationCount == 1)
    }

    @Test
    func `The same query fragment as the last finished search searches again`() async throws {
        // Given: A finished search for "Coffee shop"
        let locationSearch = makeLocationSearch()
        let firstSearch = await startInFlightSearch(on: locationSearch)
        fakeCompleter.sendResults([Self.coffeeShopCompletion])
        _ = try await firstSearch.valueWithinTimeLimit

        // When: The same query fragment arrives again
        let secondSearch = await startInFlightSearch(on: locationSearch)
        fakeCompleter.sendResults([])

        // Then: MapKit searched again and the newer answer is returned
        #expect(try await secondSearch.valueWithinTimeLimit == [])
        #expect(fakeCompleter.searchedFragments == ["Coffee shop", "Coffee shop"])
    }

    // MARK: - Failures

    @Test
    func `A failure throws mapKitError with MapKit's error`() async {
        let locationSearch = makeLocationSearch()
        let search = await startInFlightSearch(on: locationSearch)

        fakeCompleter.sendError(MKError(.loadingThrottled))

        await #expect(throws: LocationSearchError.mapKitError(MKError(.loadingThrottled))) {
            try await search.valueWithinTimeLimit
        }
    }

    @Test
    func `A failure that isn't an MKError is thrown unchanged`() async {
        struct CompleterFailure: Error, Equatable {}
        let locationSearch = makeLocationSearch()
        let search = await startInFlightSearch(on: locationSearch)

        fakeCompleter.sendError(CompleterFailure())

        await #expect(throws: CompleterFailure()) { try await search.valueWithinTimeLimit }
    }

    /// Verifies a failed search can be retried with the same text.
    /// To replicate: type "Coffee shop" while offline → reconnect → retype the same text → suggestions appear.
    @Test
    func `A retry after a failure runs a new search`() async throws {
        // Given: A search for "Coffee shop" that failed
        let locationSearch = makeLocationSearch()
        let failedSearch = await startInFlightSearch(on: locationSearch)
        fakeCompleter.sendError(MKError(.serverFailure))
        _ = await failedSearch.resultWithinTimeLimit

        // When: The same query fragment is searched again
        let retry = await startInFlightSearch(on: locationSearch)
        fakeCompleter.sendResults([Self.coffeeShopCompletion])

        // Then: MapKit searched again and the retry returns its completions
        #expect(try await retry.valueWithinTimeLimit == [Self.coffeeShopCompletion])
        #expect(fakeCompleter.searchedFragments == ["Coffee shop", "Coffee shop"])
    }

    // MARK: - Placemark

    @Test
    func `Placemark maps MKError to mapKitError`() async throws {
        let fakeLocalSearch = FakeLocalSearch()
        fakeLocalSearch.onStart = { completion in
            completion(nil, MKError(.unknown))
        }

        let locationSearch = LocationSearch(
            numberOfCharactersBeforeSearching: 1,
            debounceSearchDelay: .milliseconds(1),
            completerFactory: { FakeSearchCompleter() },
            localSearchFactory: { _ in fakeLocalSearch },
        )

        let completion = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        do {
            _ = try await locationSearch.placemark(for: completion)
            #expect(Bool(false), "Expected mapKitError")
        } catch let error as LocationSearchError {
            guard case .mapKitError = error else {
                #expect(Bool(false), "Expected mapKitError")
                return
            }
        }
    }

    @Test
    func `Placemark maps missing response to searchCompletionFailed`() async throws {
        let fakeLocalSearch = FakeLocalSearch()
        fakeLocalSearch.onStart = { completion in
            completion(nil, nil)
        }

        let locationSearch = LocationSearch(
            numberOfCharactersBeforeSearching: 1,
            debounceSearchDelay: .milliseconds(1),
            completerFactory: { FakeSearchCompleter() },
            localSearchFactory: { _ in fakeLocalSearch },
        )

        let completion = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        do {
            _ = try await locationSearch.placemark(for: completion)
            #expect(Bool(false), "Expected searchCompletionFailed")
        } catch let error as LocationSearchError {
            guard case .searchCompletionFailed = error else {
                #expect(Bool(false), "Expected searchCompletionFailed")
                return
            }
        }
    }

    @Test
    func `Placemark maps empty map items to searchCompletionFailed`() async throws {
        let fakeLocalSearch = FakeLocalSearch()
        fakeLocalSearch.onStart = { completion in
            let response = MKLocalSearch.Response()
            completion(response, nil)
        }

        let locationSearch = LocationSearch(
            numberOfCharactersBeforeSearching: 1,
            debounceSearchDelay: .milliseconds(1),
            completerFactory: { FakeSearchCompleter() },
            localSearchFactory: { _ in fakeLocalSearch },
        )

        let completion = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        do {
            _ = try await locationSearch.placemark(for: completion)
            #expect(Bool(false), "Expected searchCompletionFailed")
        } catch let error as LocationSearchError {
            guard case .searchCompletionFailed = error else {
                #expect(Bool(false), "Expected searchCompletionFailed")
                return
            }
        }
    }
}

/// Thrown by a wait that the suite's time limit ended before its task finished.
struct TimeLimitExceeded: Error {}

private extension Task {
    /// The task's result, or `TimeLimitExceeded` once the waiting test is cancelled.
    ///
    /// The suite's time limit cancels only the test's own task, not the unstructured tasks it
    /// starts. A broken cancellation path may never end those tasks, so the wait ends on the
    /// test's cancellation alone rather than on the task finishing.
    var resultWithinTimeLimit: Result<Success, any Error> {
        get async {
            let outcome = Outcome<Success>()
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    outcome.store(continuation)
                    // A cancellation that came before the continuation was stored found nothing to resume
                    if Task<Never, Never>.isCancelled {
                        outcome.resume(with: .failure(TimeLimitExceeded()))
                    }
                    Task<Void, Never> {
                        await outcome.resume(with: self.result.mapError { $0 })
                    }
                }
            } onCancel: {
                cancel()
                outcome.resume(with: .failure(TimeLimitExceeded()))
            }
        }
    }

    /// The task's value, or `TimeLimitExceeded` once the waiting test is cancelled.
    var valueWithinTimeLimit: Success {
        get async throws {
            try await resultWithinTimeLimit.get()
        }
    }
}

/// Resumes a wait exactly once, with whichever comes first: the task's result or the time limit.
private final class Outcome<Value: Sendable>: Sendable {
    private let continuation = Mutex<CheckedContinuation<Result<Value, any Error>, Never>?>(nil)

    func store(_ continuation: CheckedContinuation<Result<Value, any Error>, Never>) {
        self.continuation.withLock { $0 = continuation }
    }

    func resume(with result: Result<Value, any Error>) {
        continuation.withLock { $0.take() }?.resume(returning: result)
    }
}
