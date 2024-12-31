//
//  ContentView.swift
//  TestApp
//
//  Created by Kraig Spear on 12/30/24.
//

import MapKit
import MapKitSwiftSearch
import os
import SwiftUI

struct ContentView: View {
    
    @State private var model = Model()
    
    var body: some View {
        #if os(macOS)
        searchView_macOS
            .colorScheme(.dark)
        #else
        searchView_iOS
            .colorScheme(.dark)
        #endif
    }
    
    var searchView_iOS: some View {
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
    
    var searchView_macOS: some View {
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
    
    private struct LocationRow: View {
        
        let location: LocalSearchCompletion
        
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

#Preview {
    ContentView()
}
