# Getting Started with MapKitSwiftSearch

## Overview

MapKitSwiftSearch provides a modern Swift interface for location search operations using MapKit. This guide will walk you through the basic setup and common usage patterns to get you started quickly.

## Installation

### Swift Package Manager

Add MapKitSwiftSearch to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/MapKitSwiftSearch.git", from: "1.0.0")
]
```

### Requirements

- iOS 26.0+ / macOS 26.0+
- Swift 6.2+
- Xcode 16.0+

## Basic Usage

### 1. Import the Framework

```swift
import MapKitSwiftSearch
```

### 2. Create a LocationSearch Instance

```swift
// Using default configuration
let locationSearch = LocationSearch()

// Or with custom settings
let customLocationSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 3,
    debounceSearchDelay: .milliseconds(200)
)
```

### 3. Perform a Search

```swift
@MainActor
func searchForLocation() async {
    do {
        let results = try await locationSearch.search(queryFragment: "Coffee shops near me")
        
        for completion in results {
            print("Found: \(completion.title) - \(completion.subTitle)")
        }
    } catch {
        print("Search failed: \(error)")
    }
}
```

### 4. Get Detailed Location Information

```swift
@MainActor
func getLocationDetails(for completion: LocalSearchCompletion) async {
    do {
        if let placemark = try await locationSearch.placemark(for: completion) {
            print("Name: \(placemark.name ?? "Unknown")")
            print("Coordinate: \(placemark.coordinate)")
            
            // Create formatted address
            let addressComponents = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode
            ].compactMap { $0 }
            
            let address = addressComponents.joined(separator: ", ")
            print("Address: \(address)")
        }
    } catch {
        print("Failed to get location details: \(error)")
    }
}
```

## SwiftUI Integration

### Basic Search View

```swift
import SwiftUI
import MapKitSwiftSearch

struct LocationSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [LocalSearchCompletion] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    private let locationSearch = LocationSearch()
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SearchResultsList(results: searchResults)
                }
            }
            .navigationTitle("Location Search")
            .alert("Search Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    @MainActor
    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        do {
            searchResults = try await locationSearch.search(queryFragment: searchText)
        } catch LocationSearchError.debounce {
            // Ignore debounce errors - user is still typing
        } catch LocationSearchError.invalidSearchCriteria {
            errorMessage = "Please enter at least 5 characters"
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
        
        isSearching = false
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () async -> Void
    
    var body: some View {
        HStack {
            TextField("Search for locations...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    Task {
                        await onSearchButtonClicked()
                    }
                }
            
            Button("Search") {
                Task {
                    await onSearchButtonClicked()
                }
            }
            .disabled(text.isEmpty)
        }
        .padding()
    }
}

struct SearchResultsList: View {
    let results: [LocalSearchCompletion]
    
    var body: some View {
        List(results) { completion in
            VStack(alignment: .leading, spacing: 4) {
                Text(completion.highlightedTitle())
                    .font(.headline)
                Text(completion.highlightedSubTitle())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
```

### Search-as-You-Type Implementation

```swift
import SwiftUI
import Combine
import MapKitSwiftSearch

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [LocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private let locationSearch = LocationSearch()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce user input and trigger searches
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { @MainActor in
                    await self?.searchLocations(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    private func searchLocations(query: String) async {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            results = try await locationSearch.search(queryFragment: query)
        } catch LocationSearchError.debounce {
            // Expected during rapid typing - ignore
        } catch LocationSearchError.invalidSearchCriteria {
            errorMessage = "Enter at least 5 characters"
            results = []
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
        
        isSearching = false
    }
}

struct LiveSearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        VStack {
            TextField("Search locations...", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            if viewModel.isSearching {
                ProgressView()
                    .padding()
            }
            
            List(viewModel.results) { completion in
                LocationRowView(completion: completion)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct LocationRowView: View {
    let completion: LocalSearchCompletion
    @State private var placemark: Placemark?
    
    private let locationSearch = LocationSearch()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(completion.highlightedTitle())
                .font(.headline)
            Text(completion.highlightedSubTitle())
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let placemark = placemark {
                Text("Lat: \(placemark.coordinate.latitude, specifier: "%.4f"), Lon: \(placemark.coordinate.longitude, specifier: "%.4f")")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .onTapGesture {
            Task {
                await loadPlacemarkDetails()
            }
        }
    }
    
    @MainActor
    private func loadPlacemarkDetails() async {
        do {
            placemark = try await locationSearch.placemark(for: completion)
        } catch {
            print("Failed to load placemark: \(error)")
        }
    }
}
```

## UIKit Integration

### Basic Table View Implementation

```swift
import UIKit
import MapKitSwiftSearch

class LocationSearchViewController: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    private let locationSearch = LocationSearch()
    private var searchResults: [LocalSearchCompletion] = []
    private var searchTask: Task<Void, Never>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LocationCell")
    }
    
    @MainActor
    private func performSearch(query: String) async {
        do {
            let results = try await locationSearch.search(queryFragment: query)
            searchResults = results
            tableView.reloadData()
        } catch LocationSearchError.debounce {
            // Ignore debounce errors
        } catch {
            showError(error)
        }
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Search Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension LocationSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        // Start new search
        searchTask = Task { @MainActor in
            await performSearch(query: searchText)
        }
    }
}

extension LocationSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
        let completion = searchResults[indexPath.row]
        
        cell.textLabel?.attributedText = NSAttributedString(completion.highlightedTitle())
        cell.detailTextLabel?.attributedText = NSAttributedString(completion.highlightedSubTitle())
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let completion = searchResults[indexPath.row]
        
        Task { @MainActor in
            do {
                if let placemark = try await locationSearch.placemark(for: completion) {
                    showLocationDetails(placemark: placemark)
                }
            } catch {
                showError(error)
            }
        }
    }
    
    private func showLocationDetails(placemark: Placemark) {
        let alert = UIAlertController(
            title: placemark.name ?? "Location",
            message: "Lat: \(placemark.coordinate.latitude)\nLon: \(placemark.coordinate.longitude)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

## Error Handling Best Practices

### Comprehensive Error Handling

```swift
@MainActor
func robustLocationSearch(query: String) async -> [LocalSearchCompletion] {
    do {
        return try await locationSearch.search(queryFragment: query)
    } catch LocationSearchError.debounce {
        // User is typing quickly - this is expected behavior
        print("Search debounced")
        return []
    } catch LocationSearchError.invalidSearchCriteria {
        // Query is too short - inform user
        showUserMessage("Please enter at least 5 characters")
        return []
    } catch LocationSearchError.duplicateSearchCriteria {
        // Same query as before - use cached results if available
        print("Duplicate search detected")
        return []
    } catch LocationSearchError.mapKitError(let mkError) {
        // Handle specific MapKit errors
        switch mkError.code {
        case .networkFailure:
            showUserMessage("Network error - please check your connection")
        case .placemarkNotFound:
            showUserMessage("No locations found for your search")
        default:
            showUserMessage("Search service temporarily unavailable")
        }
        return []
    } catch LocationSearchError.searchCompletionFailed {
        // Generic failure - possibly temporary
        showUserMessage("Search failed - please try again")
        return []
    } catch {
        // Unexpected error
        print("Unexpected error: \(error)")
        showUserMessage("An unexpected error occurred")
        return []
    }
}

private func showUserMessage(_ message: String) {
    // Implementation depends on your UI framework
    print("User message: \(message)")
}
```

### Retry Logic for Network Errors

```swift
@MainActor
func searchWithRetry(query: String, maxRetries: Int = 3) async -> [LocalSearchCompletion] {
    var attemptCount = 0
    
    while attemptCount < maxRetries {
        do {
            return try await locationSearch.search(queryFragment: query)
        } catch LocationSearchError.mapKitError(let mkError) where mkError.code == .networkFailure {
            attemptCount += 1
            if attemptCount < maxRetries {
                // Exponential backoff
                let delay = TimeInterval(pow(2.0, Double(attemptCount)))
                try? await Task.sleep(for: .seconds(delay))
            }
        } catch {
            // Non-network errors shouldn't be retried
            print("Non-retryable error: \(error)")
            return []
        }
    }
    
    print("Max retry attempts reached")
    return []
}
```

## Performance Tips

### 1. Debouncing Configuration

```swift
// For responsive UI (fast typing users)
let responsiveSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 3,
    debounceSearchDelay: .milliseconds(200)
)

// For conservative API usage (limited quota)
let conservativeSearch = LocationSearch(
    numberOfCharactersBeforeSearching: 7,
    debounceSearchDelay: .milliseconds(500)
)
```

### 2. Cancellation Best Practices

```swift
class SearchController {
    private var currentSearchTask: Task<Void, Never>?
    private let locationSearch = LocationSearch()
    
    @MainActor
    func search(query: String) {
        // Cancel previous search
        currentSearchTask?.cancel()
        
        // Start new search
        currentSearchTask = Task {
            do {
                let results = try await locationSearch.search(queryFragment: query)
                await handleResults(results)
            } catch {
                await handleError(error)
            }
        }
    }
    
    func cancelCurrentSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
    }
}
```

### 3. Memory Management

```swift
// ✅ Good: Scope LocationSearch to where it's needed
func searchSpecificLocation() async {
    let locationSearch = LocationSearch()
    // Use locationSearch
    // Automatically deallocated when function ends
}

// ✅ Also good: Single instance for app lifecycle
class AppLocationService {
    static let shared = AppLocationService()
    private let locationSearch = LocationSearch()
    
    func search(query: String) async throws -> [LocalSearchCompletion] {
        return try await locationSearch.search(queryFragment: query)
    }
}
```

## Next Steps

- Read the [Advanced Usage Guide](AdvancedUsage.md) for more complex scenarios
- Check out [Common Patterns](CommonPatterns.md) for proven implementation approaches
- Review [Platform Differences](PlatformDifferences.md) for iOS vs macOS specific features
- See [Error Handling Guide](ErrorHandling.md) for comprehensive error management strategies

This getting started guide provides the foundation for using MapKitSwiftSearch effectively in your applications. The examples shown here demonstrate the core patterns that work well across different UI frameworks and use cases.