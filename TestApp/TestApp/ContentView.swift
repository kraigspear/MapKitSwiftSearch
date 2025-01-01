import MapKit
import MapKitSwiftSearch
import os
import SwiftUI

/// A view that provides location search functionality and displays results
/// with different layouts optimized for iOS and macOS platforms.
///
/// ContentView serves as the main interface for the location search application,
/// providing platform-specific implementations for both iOS and macOS.
/// It manages:
/// - Location searching
/// - Results display
/// - Location selection
/// - Map visualization
struct ContentView: View {
    
    // MARK: - Properties
    
    /// The view model that manages the state and business logic
    @State private var model = Model()
    
    // MARK: - Body
    
    var body: some View {
        #if os(macOS)
        searchView_macOS
            .colorScheme(.dark)
        #else
        searchView_iOS
            .colorScheme(.dark)
        #endif
    }
    
    // MARK: - Platform-Specific Views
    
    /// The iOS-specific implementation of the search interface.
    ///
    /// This view provides a full-screen navigation-based interface with:
    /// - A searchable list of locations
    /// - Navigation to detailed location views
    /// - Integrated search functionality
    private var searchView_iOS: some View {
        NavigationStack {
            List(selection: $model.selectedCompletion) {
                ForEach(model.searchResults, id: \.self) { result in
                    NavigationLink(destination: SelectedLocationView(model: model))  {
                        LocationRow(location: result)
                            .tag(result)
                            .environment(model)
                    }
                }
            }.navigationTitle("Location Search")
        }.searchable(text: $model.searchText, prompt: "Cities and Places of Interest")
    }
    
    /// The macOS-specific implementation of the search interface.
    ///
    /// This view provides a split-view interface with:
    /// - A searchable sidebar of locations
    /// - A main content area showing the selected location
    /// - Minimum size constraints for proper display
    private var searchView_macOS: some View {
        NavigationView {
            List(selection: $model.selectedCompletion) {
                ForEach(model.searchResults, id: \.self) { result in
                    LocationRow(location: result)
                        .tag(result)
                }
            }.frame(minWidth: 150)
                .navigationTitle("Locations")
                .searchable(text: $model.searchText, prompt: "Cities and Places of Interest")
            
            if model.selectedPlacemark != nil {
                SelectedLocationView(model: model)
            } else {
                Text("Select a location")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
        }.frame(minWidth: 400, minHeight: 300)
    }
    
    // MARK: - LocationRow
    
    /// A view that displays a single location search result.
    ///
    /// LocationRow provides a consistent format for displaying location search results,
    /// showing both the main title and subtitle with appropriate styling.
    private struct LocationRow: View {
        // MARK: Properties
        
        /// The location completion data to display
        let location: LocalSearchCompletion
        
        // MARK: Body
        
        var body: some View {
            VStack {
                Text(location.highlightedTitle())
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(location.highlightedSubTitle())
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Preview Provider

#Preview {
    ContentView()
}
