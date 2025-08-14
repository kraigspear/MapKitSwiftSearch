//
//  ContentView_macOS.swift
//  TestApp
//
//  Created by Kraig Spear on 1/1/25.
//

import MapKit
import SwiftUI

/// macOS-specific implementation of the location search interface.
///
/// This view provides a split-view interface optimized for macOS with:
/// - A searchable sidebar of locations
/// - A main content area showing the selected location
/// - Minimum size constraints for proper display
struct ContentView_macOS: View {
    /// The shared view model
    @Bindable var model: ContentView.Model

    var body: some View {
        NavigationView {
            List(selection: $model.selectedCompletion) {
                ForEach(model.searchResults, id: \.self) { result in
                    LocationRow(location: result)
                        .tag(result)
                }
            }
            .frame(minWidth: 150)
            .navigationTitle("Locations")
            .searchable(
                text: $model.searchText,
                prompt: "Cities and Places of Interest",
            )

            if model.selectedPlacemark != nil {
                SelectedLocationView(model: model)
            } else {
                Text("Select a location")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView_macOS(model: ContentView.Model())
        .colorScheme(.dark)
}
