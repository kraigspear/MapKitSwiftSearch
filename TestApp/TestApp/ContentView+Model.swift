//
//  ContentView+Model.swift
//  TestApp
//
//  Created by Kraig Spear on 12/28/24.
//

import Observation
import os
import MapKitSwiftSearch
import _MapKit_SwiftUI

// MARK: - Logger Setup
private let logger = os.Logger(subsystem: "MapKitSwiftSearch", category: "ContentView")

// MARK: - ContentView Extension
extension ContentView {
    /// The Observable model class that manages the state and business logic for ContentView
    @Observable
    @MainActor
    final class Model {
        
        // MARK: - Properties
        
        /// Service to handle location search operations
        private let locationSearch = LocationSearch()
        
        /// Task for debouncing search requests
        private var debounce: Task<Void, Never>?
        
        // MARK: - Public Properties
        
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
        
        /// Current camera position for the map
        var mapCameraPosition: MapCameraPosition = .region(MKCoordinateRegion())
        
        /// Current search text input
        var searchText: String = "" {
            didSet {
                guard oldValue != searchText else {
                    logger.debug("Duplicate search text: \(self.searchText), not searching")
                    return
                }
                search(for: searchText)
            }
        }
        
        /// Currently selected search completion
        var selectedCompletion: LocalSearchCompletion? {
            didSet {
                guard let selectedCompletion else { return }
                Task { @MainActor in
                    do {
                        selectedPlacemark = try await locationSearch.placemark(for: selectedCompletion)
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
        
        // MARK: - Private Methods
        
        /// Performs a location search based on the current search text
        private func search(for text: String) {
            logger.debug("search called: \(text)")
            
            Task { @MainActor in
                do {
                    searchResults = try await locationSearch.search(queryFragment: text)
                } catch {
                    logger.debug("Error searching: \(error)")
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
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        return MapCameraPosition.region(region)
    }
}
