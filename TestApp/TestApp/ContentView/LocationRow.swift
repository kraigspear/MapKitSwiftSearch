//
//  LocationRow.swift
//  TestApp
//
//  Created by Kraig Spear on 1/1/25.
//

import MapKitSwiftSearch
import SwiftUI

/// A view that displays a single location search result.
///
/// LocationRow provides a consistent format for displaying location search results,
/// showing both the main title and subtitle with appropriate styling.
struct LocationRow: View {
    // MARK: Properties

    /// The location completion data to display
    let location: LocalSearchCompletion

    // MARK: Body

    var body: some View {
        VStack {
            Text(location.highlightedTitle())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(location.subTitle)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
