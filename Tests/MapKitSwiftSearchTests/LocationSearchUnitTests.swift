import Foundation
import MapKit
import Testing
@testable import MapKitSwiftSearch

@MainActor
struct LocationSearchUnitTests {
    final class FakeSearchCompleter: LocalSearchCompleterProtocol {
        weak var delegate: LocalSearchCompleterDelegate?
        var onQueryFragmentSet: ((String) -> Void)?
        var onCancel: (() -> Void)?

        var queryFragment = "" {
            didSet {
                onQueryFragmentSet?(queryFragment)
            }
        }

        func cancel() {
            onCancel?()
        }

        func sendResults(_ results: [LocalSearchCompletion]) {
            delegate?.completerDidUpdateResults(results)
        }

        func sendError(_ error: Error) {
            delegate?.completerDidFail(with: error)
        }
    }

    final class FakeLocalSearch: LocalSearchProtocol {
        var onStart: ((@escaping @Sendable (MKLocalSearch.Response?, Error?) -> Void) -> Void)?

        func start(completionHandler: @escaping @Sendable (MKLocalSearch.Response?, Error?) -> Void) {
            onStart?(completionHandler)
        }
    }

    actor Signal {
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            await withCheckedContinuation { continuation = $0 }
        }

        func fire() {
            continuation?.resume()
            continuation = nil
        }
    }

    static let coffeeShopCompletion = LocalSearchCompletion(
        title: "Coffee shop",
        subTitle: "Grand Rapids, MI",
        titleHighlightRange: nil,
        subtitleHighlightRange: nil,
    )

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

        do {
            _ = try await locationSearch.search(queryFragment: "Cafe")
            #expect(Bool(false), "Expected searchCompletionFailed")
        } catch let error as LocationSearchError {
            guard case .searchCompletionFailed = error else {
                #expect(Bool(false), "Expected searchCompletionFailed")
                return
            }
        }
    }

    @Test("In-flight search cancels after debounce")
    func inFlightSearchCancelsAfterDebounce() async throws {
        let firstCompleter = FakeSearchCompleter()
        let secondCompleter = FakeSearchCompleter()
        var factoryCallCount = 0
        let signal = Signal()

        let locationSearch = LocationSearch(
            numberOfCharactersBeforeSearching: 1,
            debounceSearchDelay: .milliseconds(10),
            completerFactory: {
                defer { factoryCallCount += 1 }
                return factoryCallCount == 0 ? firstCompleter : secondCompleter
            },
            localSearchFactory: { _ in FakeLocalSearch() },
        )

        firstCompleter.onQueryFragmentSet = { _ in
            Task { await signal.fire() }
        }

        let firstSearch = Task {
            try await locationSearch.search(queryFragment: "Sheridan, In")
        }

        await signal.wait()

        secondCompleter.onQueryFragmentSet = { _ in
            let completion = LocalSearchCompletion(
                title: "Caledonia",
                subTitle: "MI",
                titleHighlightRange: nil,
                subtitleHighlightRange: nil,
            )
            secondCompleter.sendResults([completion])
        }

        let secondResults = try await locationSearch.search(queryFragment: "Caledonia, Mi")
        #expect(secondResults.count == 1)

        await #expect(throws: CancellationError.self) {
            _ = try await firstSearch.value
        }
    }

    /// Verifies clearing the query while MapKit is still searching leaves no stale suggestions.
    /// To replicate: type "Coffee shop" → clear the field before suggestions appear → list stays empty.
    @Test("Empty query cancels the in-flight search")
    func search_whenSupersededByEmptyQuery_cancelsInFlightSearch() async throws {
        // Given: A search for "Coffee shop" waiting on MapKit
        let fakeCompleter = FakeSearchCompleter()
        let signal = Signal()
        let locationSearch = LocationSearch(
            numberOfCharactersBeforeSearching: 5,
            debounceSearchDelay: .milliseconds(10),
            completerFactory: { fakeCompleter },
            localSearchFactory: { _ in FakeLocalSearch() },
        )
        fakeCompleter.onQueryFragmentSet = { _ in
            Task { await signal.fire() }
        }
        let firstSearch = Task {
            try await locationSearch.search(queryFragment: "Coffee shop")
        }
        await signal.wait()

        // When: The query is cleared, then MapKit answers the original search
        let emptyResults = try await locationSearch.search(queryFragment: "")
        fakeCompleter.sendResults([Self.coffeeShopCompletion])

        // Then: The original search is cancelled instead of delivering stale results
        #expect(emptyResults.isEmpty)
        await #expect(throws: CancellationError.self) {
            _ = try await firstSearch.value
        }
    }

    /// Verifies deleting back below the minimum length while MapKit is searching leaves no stale suggestions.
    /// To replicate: type "Coffee shop" → delete back to "Co" before suggestions appear → list stays empty.
    @Test("Too-short query cancels the in-flight search")
    func search_whenSupersededByTooShortQuery_cancelsInFlightSearch() async throws {
        // Given: A search for "Coffee shop" waiting on MapKit
        let fakeCompleter = FakeSearchCompleter()
        let signal = Signal()
        let locationSearch = LocationSearch(
            numberOfCharactersBeforeSearching: 5,
            debounceSearchDelay: .milliseconds(10),
            completerFactory: { fakeCompleter },
            localSearchFactory: { _ in FakeLocalSearch() },
        )
        fakeCompleter.onQueryFragmentSet = { _ in
            Task { await signal.fire() }
        }
        let firstSearch = Task {
            try await locationSearch.search(queryFragment: "Coffee shop")
        }
        await signal.wait()

        // When: A too-short query arrives, then MapKit answers the original search
        await #expect(throws: LocationSearchError.invalidSearchCriteria) {
            _ = try await locationSearch.search(queryFragment: "Co")
        }
        fakeCompleter.sendResults([Self.coffeeShopCompletion])

        // Then: The original search is cancelled instead of delivering stale results
        await #expect(throws: CancellationError.self) {
            _ = try await firstSearch.value
        }
    }

    /// Verifies resubmitting the query already in flight still delivers its results.
    /// To replicate: type "Coffee shop" → add and delete a character before suggestions appear → suggestions appear.
    @Test("Duplicate query leaves the in-flight search running")
    func search_whenDuplicateOfInFlightQuery_deliversInFlightResults() async throws {
        // Given: A search for "Coffee shop" waiting on MapKit
        let fakeCompleter = FakeSearchCompleter()
        let signal = Signal()
        let locationSearch = LocationSearch(
            numberOfCharactersBeforeSearching: 5,
            debounceSearchDelay: .milliseconds(10),
            completerFactory: { fakeCompleter },
            localSearchFactory: { _ in FakeLocalSearch() },
        )
        fakeCompleter.onQueryFragmentSet = { _ in
            Task { await signal.fire() }
        }
        let firstSearch = Task {
            try await locationSearch.search(queryFragment: "Coffee shop")
        }
        await signal.wait()

        // When: The same query arrives again, then MapKit answers the original search
        await #expect(throws: LocationSearchError.duplicateSearchCriteria) {
            _ = try await locationSearch.search(queryFragment: "Coffee shop")
        }
        fakeCompleter.sendResults([Self.coffeeShopCompletion])

        // Then: The original search delivers its results
        let results = try await firstSearch.value
        #expect(results == [Self.coffeeShopCompletion])
    }

    @Test("Placemark maps MKError to mapKitError")
    func placemarkMapsMapKitError() async throws {
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

    @Test("Placemark maps missing response to searchCompletionFailed")
    func placemarkMapsMissingResponseToSearchCompletionFailed() async throws {
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

    @Test("Placemark maps empty map items to searchCompletionFailed")
    func placemarkMapsEmptyMapItemsToSearchCompletionFailed() async throws {
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
