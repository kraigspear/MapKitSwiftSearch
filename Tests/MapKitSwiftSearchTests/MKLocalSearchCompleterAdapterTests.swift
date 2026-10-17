import Foundation
import MapKit
import Testing
@testable import MapKitSwiftSearch

@MainActor
struct MKLocalSearchCompleterAdapterTests {
    /// A completer that records what the adapter asks of it and never reaches MapKit.
    final class FakeMKCompleter: MKLocalSearchCompleter {
        private(set) var startedFragment: String?
        private(set) var cancelCount = 0
        /// Yields when the adapter hands over a fragment, which starts MapKit's search.
        let starts = AsyncStream.makeStream(of: Void.self)
        /// Yields each time the adapter cancels MapKit's search.
        let cancels = AsyncStream.makeStream(of: Void.self)
        private var fragment = ""

        override var queryFragment: String {
            get { fragment }
            set {
                fragment = newValue
                startedFragment = newValue
                starts.continuation.yield()
            }
        }

        override var results: [MKLocalSearchCompletion] {
            []
        }

        override func cancel() {
            cancelCount += 1
            cancels.continuation.yield()
        }
    }

    struct MapKitFailure: Error, Equatable {}

    /// Starts a search and returns once the adapter has handed the fragment to the completer.
    private func startSearch(
        _ adapter: MKLocalSearchCompleterAdapter,
        on completer: FakeMKCompleter,
    ) async -> Task<[LocalSearchCompletion], Error> {
        let task = Task { try await adapter.completions(for: "Coffee shop") }
        await waitFor(completer.starts.stream)
        return task
    }

    /// The search's result, or `nil` if the time limit cancels the test before the search ends.
    ///
    /// Awaiting `task.result` directly ignores the test's cancellation, so a dropped resume
    /// would hang the run instead of failing the test.
    private func result(
        of task: Task<[LocalSearchCompletion], Error>,
    ) async -> Result<[LocalSearchCompletion], Error>? {
        let (results, continuation) = AsyncStream.makeStream(of: Result<[LocalSearchCompletion], Error>.self)
        Task {
            await continuation.yield(task.result)
            continuation.finish()
        }
        for await result in results {
            return result
        }
        return nil
    }

    /// Waits for the fake's signal, recording an issue if the time limit cancels the test first.
    private func waitFor(_ signal: AsyncStream<Void>, sourceLocation: SourceLocation = #_sourceLocation) async {
        for await _ in signal {
            return
        }
        Issue.record("The signal never came", sourceLocation: sourceLocation)
    }

    /// Verifies a superseded MapKit search ends instead of hanging its caller.
    /// To replicate: type "Coffee shop" → change the query while MapKit is searching → the old search ends.
    @Test(.timeLimit(.minutes(1)))
    func `Cancelling a running search resumes it with CancellationError and cancels the completer`() async throws {
        // Given: A search waiting on MapKit
        let completer = FakeMKCompleter()
        let adapter = MKLocalSearchCompleterAdapter(completer: completer)
        let task = await startSearch(adapter, on: completer)

        // When: The search's task is cancelled
        task.cancel()

        // Then: The search ends with CancellationError, and MapKit's search is cancelled
        let result = try #require(await result(of: task))
        #expect(throws: CancellationError.self) {
            _ = try result.get()
        }
        await waitFor(completer.cancels.stream)
        #expect(completer.cancelCount == 1)
    }

    /// Verifies MapKit answering after cancellation doesn't resume the search a second time.
    /// To replicate: change the query just as MapKit answers the old one → no crash.
    @Test(.timeLimit(.minutes(1)))
    func `MapKit answering after cancellation is ignored`() async throws {
        // Given: A search that was cancelled while waiting on MapKit
        let completer = FakeMKCompleter()
        let adapter = MKLocalSearchCompleterAdapter(completer: completer)
        let task = await startSearch(adapter, on: completer)
        task.cancel()
        let result = try #require(await result(of: task))
        #expect(throws: CancellationError.self) {
            _ = try result.get()
        }

        // When: MapKit answers anyway, with results and then with a failure
        adapter.completerDidUpdateResults(completer)
        adapter.completer(completer, didFailWithError: MapKitFailure())

        // Then: Nothing resumes the finished search again, which would trap
        #expect(completer.startedFragment == "Coffee shop")
    }

    /// Verifies a search cancelled before it starts never reaches MapKit.
    /// To replicate: change the query before the old search starts → MapKit sees no search for it.
    @Test(.timeLimit(.minutes(1)))
    func `Search already cancelled never starts the completer`() async throws {
        // Given: A search whose task is cancelled before it runs
        let completer = FakeMKCompleter()
        let adapter = MKLocalSearchCompleterAdapter(completer: completer)
        let task = Task { try await adapter.completions(for: "Coffee shop") }
        task.cancel()

        // When: The task runs
        let result = try #require(await result(of: task))

        // Then: It ends with CancellationError without giving the completer a fragment
        #expect(throws: CancellationError.self) {
            _ = try result.get()
        }
        #expect(completer.startedFragment == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `MapKit's results complete the search`() async throws {
        // Given: A search waiting on MapKit
        let completer = FakeMKCompleter()
        let adapter = MKLocalSearchCompleterAdapter(completer: completer)
        let task = await startSearch(adapter, on: completer)

        // When: MapKit answers
        adapter.completerDidUpdateResults(completer)

        // Then: The search returns MapKit's results
        let result = try #require(await result(of: task))
        #expect(try result.get().isEmpty)
        #expect(completer.cancelCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func `MapKit's failure fails the search with MapKit's error`() async throws {
        // Given: A search waiting on MapKit
        let completer = FakeMKCompleter()
        let adapter = MKLocalSearchCompleterAdapter(completer: completer)
        let task = await startSearch(adapter, on: completer)

        // When: MapKit fails
        adapter.completer(completer, didFailWithError: MapKitFailure())

        // Then: The search throws MapKit's error unchanged
        let result = try #require(await result(of: task))
        #expect(throws: MapKitFailure()) {
            _ = try result.get()
        }
    }
}
