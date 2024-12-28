//
//  ContentView.swift
//  TestApp
//
//  Created by Kraig Spear on 12/26/24.
//

import MapKitSwiftSearch
import os
import SwiftUI

private let logger = os.Logger(subsystem: "MapKitSwiftSearch", category: "ContentView")

struct ContentView: View {
    
    @State private var searchText: String = ""
    @State private var locationSearch = LocationSearch()
    @State private var searchResults: [LocalSearchCompletion] = []
    @State private var debounce: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            List(searchResults, id: \.self) { result in
                LocationRow(location: result)
            }.searchable(text: $searchText, prompt: "Cities and Places of Interest")
                .onChange(of: searchText) { _, searchText in
                    debounce?.cancel()
                    debounce = Task { @MainActor in
                        do {
                            logger.debug("Start debounce")
                            try await Task.sleep(for: .milliseconds(500))
                            logger.debug("debounce complete, start search")
                            searchResults = try await locationSearch.search(queryFragment: searchText)
                            logger.debug("finished search")
                        } catch {
                            logger.debug("Error: \(error)")
                        }
                    }
                }
        }
    }
}

private struct LocationRow: View {
    
    let location: LocalSearchCompletion
    
    var body: some View {
        VStack {
            Text(location.highlightedTitle())
                .font(.headline)
            Text(location.subTitle)
                .font(.caption)
        }
    }
}

#Preview {
    ContentView()
}
