import MapKit
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

            #expect(placemark.name == "Caledonia", "Expected selection title")
        }

        /// A "Search Nearby" completion is the case a text search for its title and subtitle got
        /// wrong: it failed, or found a place on another continent.
        ///
        /// The completer returns only query completions, the "Search Nearby" kind, so the test never
        /// matches localized text. The reference is MapKit resolving the same completion directly,
        /// so the test holds wherever MapKit places the machine running it.
        @Test
        func `Fetch the place MapKit suggested for a Search Nearby completion`() async throws {
            let locationSearch = LocationSearch(
                numberOfCharactersBeforeSearching: 5,
                debounceSearchDelay: .zero,
                completerFactory: {
                    let completer = MKLocalSearchCompleter()
                    completer.resultTypes = .query
                    return MKLocalSearchCompleterAdapter(completer: completer)
                },
                localSearchFactory: { MKLocalSearchAdapter(completion: $0) },
            )
            let localSearchCompletions = try await locationSearch.search(queryFragment: "Pizza Restaurants")
            let searchNearby = try #require(localSearchCompletions.first, "Expected a query completion")
            let mapKitCompletion = try #require(searchNearby.mapKitCompletion)
            let suggestedSearch = MKLocalSearch(request: MKLocalSearch.Request(completion: mapKitCompletion))
            let suggested = try #require(try await suggestedSearch.start().mapItems.first)

            let placemark = try await locationSearch.placemark(for: searchNearby)

            let distance = CLLocation(
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude,
            )
            .distance(from: suggested.location)
            #expect(distance < 1000, "\(placemark) is \(Int(distance)) m from MapKit's suggestion \(suggested)")
        }
    }
}
