//
//  SelectedLocationView.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/30/24.
//

import MapKit
import SwiftUI

/// A view that displays a map with a marker for a selected location.
///
/// `SelectedLocationView` presents a full-screen map interface that shows
/// the user's selected location with a marker. The view automatically
/// updates when the selected location changes through the provided model.
///
/// Example usage:
/// ```swift
/// let model = ContentView.Model()
/// SelectedLocationView(model: model)
/// ```
///
/// - Important: The view requires a valid `ContentView.Model` instance with
///   a selected placemark to display the marker.
struct SelectedLocationView: View {
    // MARK: - Properties

    /// The view model containing the selected location and map state
    let model: ContentView.Model

    // MARK: - Body

    var body: some View {
        @Bindable var model = model

        Map(position: $model.mapCameraPosition) {
            // Only show marker if we have a valid placemark with a name
            if let placemark = model.selectedPlacemark,
               let name = placemark.name
            {
                Marker(
                    name,
                    coordinate: placemark.coordinate,
                )
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Preview Provider

#Preview {
    // Create a preview with a mock model
    SelectedLocationView(model: ContentView.Model())
}
