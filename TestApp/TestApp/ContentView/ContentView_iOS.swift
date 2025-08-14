//
//  ContentView_iOS.swift
//  TestApp
//
//  Created by Kraig Spear on 1/1/25.
//

import MapKit
import SwiftUI

/// iOS-specific implementation of the location search interface.
///
/// This view provides a full-screen navigation-based interface optimized for iOS devices with:
/// - A searchable list of locations
/// - Navigation to detailed location views
/// - Integrated search functionality
struct ContentView_iOS: View {
    /// The shared view model
    @Bindable var model: ContentView.Model

    var body: some View {
        NavigationStack {
            List(selection: $model.selectedCompletion) {
                ForEach(model.searchResults, id: \.self) { result in
                    NavigationLink(destination: SelectedLocationView(model: model)) {
                        LocationRow(location: result)
                            .tag(result)
                            .environment(model)
                    }
                }
            }
            .navigationTitle("Location Search")
            .searchable(
                text: $model.searchText,
                prompt: "Cities and Places of Interest",
            )
        }
    }
}

#Preview {
    ContentView_iOS(model: ContentView.Model())
        .colorScheme(.dark)
}
