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

        var queryFragment: String = "" {
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
