# Getting Started with MapKitSwiftSearch

Learn how to quickly integrate and use MapKitSwiftSearch in your Swift applications.

## Overview

MapKitSwiftSearch provides a modern Swift interface for location search operations using MapKit. It wraps MapKit's `MKLocalSearchCompleter` with async/await support, structured concurrency, and type-safe error handling.

### Key Features

- **Modern Swift**: Uses async/await and structured concurrency
- **Type Safety**: Swift-native error types and Sendable-compliant results
- **Performance**: Built-in debouncing and intelligent search management
- **Cross-Platform**: Works on both iOS and macOS with platform-specific UI helpers

## Installation

### Swift Package Manager

Add MapKitSwiftSearch to your project using Swift Package Manager:

1. In Xcode, select File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/yourusername/MapKitSwiftSearch`
3. Choose the version requirements that fit your project
4. Add the package to your target

### Package.swift

For command-line projects, add MapKitSwiftSearch to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/MapKitSwiftSearch", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["MapKitSwiftSearch"]
    )
]
```

## First Search

Here's the simplest way to perform a location search:

```swift
import MapKitSwiftSearch

// Create a search instance
let locationSearch = LocationSearch()

do {
    // Perform a search
    let results = try await locationSearch.search(queryFragment: "Coffee shops")
    
    // Display results
    for result in results {
        print("\(result.title) - \(result.subTitle)")
    }
} catch {
    print("Search failed: \(error)")
}
```

## Basic Integration in SwiftUI

Here's how to integrate location search into a SwiftUI view:

```swift
import SwiftUI
import MapKitSwiftSearch

struct LocationSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [LocalSearchCompletion] = []
    @State private var locationSearch = LocationSearch()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search field
                TextField("Search for locations...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        Task {
                            await performSearch(query: newValue)
                        }
                    }
                
                // Results list
                List(searchResults) { result in
                    VStack(alignment: .leading) {
                        Text(result.title)
                            .font(.headline)
                        Text(result.subTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        Task {
                            await selectLocation(result)
                        }
                    }
                }
            }
            .navigationTitle("Location Search")
        }
    }
    
    private func performSearch(query: String) async {
        do {
            let results = try await locationSearch.search(queryFragment: query)
            await MainActor.run {
                searchResults = results
            }
        } catch LocationSearchError.debounce {
            // Search was debounced, ignore
        } catch LocationSearchError.invalidSearchCriteria {
            // Not enough characters yet, clear results
            await MainActor.run {
                searchResults = []
            }
        } catch {
            print("Search error: \(error)")
        }
    }
    
    private func selectLocation(_ completion: LocalSearchCompletion) async {
        do {
            if let placemark = try await locationSearch.placemark(for: completion) {
                print("Selected: \(placemark.name ?? "Unknown location")")
                print("Coordinates: \(placemark.coordinate)")
            }
        } catch {
            print("Failed to get placemark: \(error)")
        }
    }
}
```

## Basic Integration in UIKit

For UIKit applications, here's a simple table view implementation:

```swift
import UIKit
import MapKitSwiftSearch

class LocationSearchViewController: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    private let locationSearch = LocationSearch()
    private var searchResults: [LocalSearchCompletion] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
    }
}

// MARK: - UISearchBarDelegate
extension LocationSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        Task {
            await performSearch(query: searchText)
        }
    }
    
    private func performSearch(query: String) async {
        do {
            let results = try await locationSearch.search(queryFragment: query)
            await MainActor.run {
                self.searchResults = results
                self.tableView.reloadData()
            }
        } catch LocationSearchError.debounce {
            // Search was debounced, ignore
        } catch LocationSearchError.invalidSearchCriteria {
            // Not enough characters, clear results
            await MainActor.run {
                self.searchResults = []
                self.tableView.reloadData()
            }
        } catch {
            print("Search error: \(error)")
        }
    }
}

// MARK: - UITableViewDataSource
extension LocationSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
        let result = searchResults[indexPath.row]
        
        cell.textLabel?.text = result.title
        cell.detailTextLabel?.text = result.subTitle
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LocationSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let completion = searchResults[indexPath.row]
        Task {
            do {
                if let placemark = try await locationSearch.placemark(for: completion) {
                    print("Selected: \(placemark.name ?? "Unknown location")")
                    // Handle the selected location
                }
            } catch {
                print("Failed to get placemark: \(error)")
            }
        }
    }
}
```

## Next Steps

Now that you have basic search functionality working, explore these additional capabilities:

- **<doc:BasicSearchFunctionality>** - Learn about different search patterns and options
- **<doc:WorkingWithSearchResults>** - Discover how to highlight search terms and handle selections
- **<doc:ErrorHandling>** - Understand the different error scenarios and how to handle them
- **<doc:AdvancedUsage>** - Explore customization options, debouncing, and performance optimization
- **<doc:PlatformDifferences>** - Learn about iOS and macOS specific features

## Requirements

- iOS 18.0+ or macOS 15.0+
- Swift 6.2+
- Xcode 16.0+

The package uses strict concurrency checking and requires the latest Swift concurrency features for optimal performance and safety.