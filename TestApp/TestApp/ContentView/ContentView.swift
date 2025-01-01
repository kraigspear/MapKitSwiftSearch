import MapKit
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
            ContentView_macOS(model: model)
                .colorScheme(.dark)
        #else
            ContentView_iOS(model: model)
                .colorScheme(.dark)
        #endif
    }
}

// MARK: - Preview Provider

#Preview {
    ContentView()
}
