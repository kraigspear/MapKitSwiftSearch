//
//  ContentView+Model.swift
//  TestApp
//
//  Created by Kraig Spear on 12/28/24.
//

import _MapKit_SwiftUI
import MapKitSwiftSearch
import Observation
import os

// MARK: - Logger Setup

private let logger = os.Logger(subsystem: "MapKitSwiftSearch", category: "ContentView")

// MARK: - ContentView Extension

extension ContentView {
    /// The Observable model class that manages the state and business logic for ContentView
    @Observable
    @MainActor
    final class Model {
        // MARK: - Services

        /// Service to handle location search operations
        private let locationSearch = LocationSearch()

        // MARK: - State

        /// Current search results from location search
        private(set) var searchResults: [LocalSearchCompletion] = [] {
            didSet {
                if searchResults.isEmpty {
                    selectedPlacemark = nil
                }
            }
        }

        /// Currently selected placemark
        private(set) var selectedPlacemark: Placemark?

        // MARK: - Public Properties

        /// Current camera position for the map
        var mapCameraPosition: MapCameraPosition = .region(MKCoordinateRegion())

        /// Current search text input
        var searchText: String = "" {
            didSet {
                let searchText = searchText
                guard oldValue != searchText else {
                    logger.debug("Duplicate search text: \(searchText), not searching")
                    return
                }
                search(for: searchText)
            }
        }

        /// Currently selected search completion
        var selectedCompletion: LocalSearchCompletion? {
            didSet {
                guard let selectedCompletion else { return }
                fetchPlacemark(for: selectedCompletion)
            }
        }

        // MARK: - Private Methods

        /// Performs a location search based on the current search text
        private func search(for text: String) {
            logger.debug("search called: \(text)")

            Task {
                do {
                    searchResults = try await locationSearch.search(queryFragment: text)
                } catch {
                    logger.error("Error searching: \(error)")
                    searchResults = []
                }
            }
        }

        /// Fetches placemark details for a selected completion
        private func fetchPlacemark(for completion: LocalSearchCompletion) {
            Task {
                do {
                    selectedPlacemark = try await locationSearch.placemark(for: completion)
                    if let selectedPlacemark {
                        mapCameraPosition = selectedPlacemark.mapCameraPosition()
                    }
                } catch {
                    logger.error("Error fetching placemark: \(error)")
                    selectedPlacemark = nil
                }
            }
        }
    }
}

// MARK: - Placemark Extension

extension Placemark {
    /// Creates a MapCameraPosition centered on the placemark's coordinates
    /// with a default zoom level
    func mapCameraPosition() -> MapCameraPosition {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2),
        )
        return MapCameraPosition.region(region)
    }
}
