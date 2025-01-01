@testable import MapKitSwiftSearch
import Testing

@MainActor
struct LocationSearchTest {
    @MainActor
    struct Search {
        @Test("Successful search")
        func successfulSearch() async throws {
            let locationSearch = LocationSearch()
            let localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan, In")

            #expect(!localSearchCompletions.isEmpty, "Expected results")
            let foundLocation = localSearchCompletions.first { $0.title == "Sheridan, IN" }
            print("found location: \(String(describing: foundLocation))")
            #expect(foundLocation != nil, "Didn't find Sheridan")
        }

        @Test("If a search is in progress, cancel if we get another search request")
        func multipleSearches() async throws {
            var cancelCount = 0
            let locationSearch = LocationSearch()

            async let search1: Void = {
                do {
                    _ = try await locationSearch.search(queryFragment: "Sheridan, In")
                } catch {
                    cancelCount += 1
                    print("task1 cancelled")
                }
            }()

            async let search2: Void = {
                do {
                    _ = try await locationSearch.search(queryFragment: "Caledonia, Mi")
                } catch {
                    print("task2 cancelled")
                }
            }()

            _ = await (search1, search2)
            #expect(cancelCount == 1, "Expected task1 to cancel")
        }

        @Test("Results cleared when searching empty query")
        func resultsClearedWhenSearchingEmptyQuery() async throws {
            let locationSearch = LocationSearch()
            var localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan, In")
            #expect(!localSearchCompletions.isEmpty, "Expected results")

            localSearchCompletions = try await locationSearch.search(queryFragment: "")
            #expect(localSearchCompletions.isEmpty, "Results should be cleared")
        }

        @Test("Not searching with less than 5 characters")
        func notEnoughCharactersToSearch() async throws {
            let locationSearch = LocationSearch(numberOfCharactersBeforeSearching: 5)

            await #expect(throws: LocationSearchError.invalidSearchCriteria) {
                _ = try await locationSearch.search(queryFragment: "S")
            }
        }
    }

    @MainActor
    struct Select {
        @Test("Fetch a placemark for a location")
        func selectLocation() async throws {
            let locationSearch = LocationSearch()
            let localSearchCompletions = try await locationSearch.search(queryFragment: "Caledonia, Mi")
            #expect(!localSearchCompletions.isEmpty, "Expected results")

            let foundLocation = try #require(localSearchCompletions.first { $0.title == "Caledonia, MI" }, "Didn't find search location")

            let placemark = try await locationSearch.placemark(for: foundLocation)
            #expect(placemark != nil, "Expected selection")

            #expect(placemark?.name == "Caledonia", "Expected selection title")
        }
    }
}
