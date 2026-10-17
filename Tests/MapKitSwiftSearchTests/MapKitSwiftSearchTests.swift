import Testing
@testable import MapKitSwiftSearch

@MainActor
struct LocationSearchTest {
    @MainActor
    struct Search {
        @Test
        func `Successful search`() async throws {
            let locationSearch = LocationSearch()
            let localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan, In")

            #expect(!localSearchCompletions.isEmpty, "Expected results")
            let foundLocation = localSearchCompletions.first { $0.title == "Sheridan, IN" }
            print("found location: \(String(describing: foundLocation))")
            #expect(foundLocation != nil, "Didn't find Sheridan")
        }

        @Test
        func `If a search is in progress, cancel if we get another search request`() async throws {
            let locationSearch = LocationSearch(debounceSearchDelay: .milliseconds(200))

            let search1 = Task {
                await #expect(throws: LocationSearchError.debounce) {
                    _ = try await locationSearch.search(queryFragment: "Sheridan, In")
                }
            }

            try await Task.sleep(for: .milliseconds(50))

            do {
                _ = try await locationSearch.search(queryFragment: "Caledonia, Mi")
            } catch {
                print("task2 cancelled")
            }

            _ = await search1.value
        }

        @Test
        func `Results cleared when searching empty query`() async throws {
            let locationSearch = LocationSearch()
            var localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan, In")
            #expect(!localSearchCompletions.isEmpty, "Expected results")

            localSearchCompletions = try await locationSearch.search(queryFragment: "")
            #expect(localSearchCompletions.isEmpty, "Results should be cleared")
        }

        @Test
        func `Not searching with less than 5 characters`() async throws {
            let locationSearch = LocationSearch(numberOfCharactersBeforeSearching: 5)

            await #expect(throws: LocationSearchError.invalidSearchCriteria) {
                _ = try await locationSearch.search(queryFragment: "S")
            }
        }

        @Test
        func `Sending the same query twice, throws error`() async throws {
            let locationSearch = LocationSearch()
            _ = try await locationSearch.search(queryFragment: "Pensacola, FL")

            await #expect(throws: LocationSearchError.duplicateSearchCriteria) {
                _ = try await locationSearch.search(queryFragment: "Pensacola, FL")
            }
        }

        @Test
        func `Two searches previous gets debounce error`() async throws {
            let locationSearch = LocationSearch()

            let task1 = Task {
                await #expect(throws: LocationSearchError.debounce) {
                    _ = try await locationSearch.search(queryFragment: "Pensacola, FL")
                }
            }

            let task2 = Task {
                _ = try await locationSearch.search(queryFragment: "Sheridan, In")
            }

            _ = await task1.value
            try await task2.value
        }
    }

    @MainActor
    struct Select {
        @Test
        func `Fetch a placemark for a location`() async throws {
            let locationSearch = LocationSearch()
            let localSearchCompletions = try await locationSearch.search(queryFragment: "Caledonia, Mi")
            #expect(!localSearchCompletions.isEmpty, "Expected results")

            let foundLocation = try #require(
                localSearchCompletions.first { $0.title == "Caledonia, MI" },
                "Didn't find search location",
            )

            let placemark = try await locationSearch.placemark(for: foundLocation)
            #expect(placemark != nil, "Expected selection")

            #expect(placemark?.name == "Caledonia", "Expected selection title")
        }
    }
}
