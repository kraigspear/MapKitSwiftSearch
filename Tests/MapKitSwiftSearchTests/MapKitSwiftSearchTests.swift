import Testing
@testable import MapKitSwiftSearch

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
            #expect(foundLocation != nil, "Didn't find Sheridan")
        }

        @Test("Results cleared when searching empty query")
        func resultsClearedWhenSearchingEmptyQuery() async throws {
            let locationSearch = LocationSearch()
            var localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan, In")
            #expect(!localSearchCompletions.isEmpty, "Expected results")
            
            localSearchCompletions = try await locationSearch.search(queryFragment: "")
            #expect(localSearchCompletions.isEmpty, "Results should be cleared")
        }
        
        @Test("Debouce")
        func debounce() async throws {
            let locationSearch = LocationSearch()
            var localSearchCompletions = try await locationSearch.search(queryFragment: "Sheri")
            localSearchCompletions = try await locationSearch.search(queryFragment: "Sheridan")
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

