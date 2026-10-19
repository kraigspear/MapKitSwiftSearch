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
