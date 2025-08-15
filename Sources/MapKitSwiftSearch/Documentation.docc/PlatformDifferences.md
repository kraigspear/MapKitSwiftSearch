# Platform Differences

Understand the differences and platform-specific features when using MapKitSwiftSearch on iOS and macOS.

## Overview

While MapKitSwiftSearch provides a unified API across platforms, there are important differences in UI frameworks, design patterns, and user expectations between iOS and macOS. This guide covers platform-specific considerations and implementations.

## Core API Consistency

The core `LocationSearch` API is identical across platforms:

```swift
// This code works exactly the same on both iOS and macOS
let locationSearch = LocationSearch()

do {
    let results = try await locationSearch.search(queryFragment: "Coffee shops")
    // Handle results
} catch {
    // Handle errors
}
```

## Platform-Specific UI Extensions

### Text Highlighting

The highlighting functionality uses platform-appropriate color types:

#### iOS Implementation
```swift
#if os(iOS)
import UIKit

// iOS uses UIColor
let highlightedTitle = result.highlightedTitle(
    foregroundColor: .label,           // UIColor.label
    highlightColor: .systemBlue        // UIColor.systemBlue
)

let highlightedSubtitle = result.highlightedSubTitle(
    foregroundColor: .secondaryLabel,   // UIColor.secondaryLabel
    highlightColor: .systemBlue
)
#endif
```

#### macOS Implementation
```swift
#if os(macOS)
import AppKit

// macOS uses NSColor
let highlightedTitle = result.highlightedTitle(
    foregroundColor: .labelColor,           // NSColor.labelColor
    highlightColor: .controlAccentColor     // NSColor.controlAccentColor
)

let highlightedSubtitle = result.highlightedSubTitle(
    foregroundColor: .secondaryLabelColor,  // NSColor.secondaryLabelColor
    highlightColor: .controlAccentColor
)
#endif
```

## SwiftUI Cross-Platform Implementation

### Universal SwiftUI View
```swift
import SwiftUI
import MapKitSwiftSearch

struct LocationRow: View {
    let result: LocalSearchCompletion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(highlightedTitle)
                .font(.headline)
            
            Text(highlightedSubtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private var highlightedTitle: AttributedString {
        #if os(iOS)
        return result.highlightedTitle(
            foregroundColor: .label,
            highlightColor: .blue
        )
        #else
        return result.highlightedTitle(
            foregroundColor: .labelColor,
            highlightColor: .controlAccentColor
        )
        #endif
    }
    
    private var highlightedSubtitle: AttributedString {
        #if os(iOS)
        return result.highlightedSubTitle(
            foregroundColor: .secondaryLabel,
            highlightColor: .blue
        )
        #else
        return result.highlightedSubTitle(
            foregroundColor: .secondaryLabelColor,
            highlightColor: .controlAccentColor
        )
        #endif
    }
}
```

### Platform-Adaptive Layout
```swift
struct LocationSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [LocalSearchCompletion] = []
    @StateObject private var searchController = LocationSearchController()
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            searchContentView
        }
        .navigationViewStyle(StackNavigationViewStyle())
        #else
        HSplitView {
            searchContentView
                .frame(minWidth: 300)
            
            // Detail view for macOS
            if let selectedResult = searchController.selectedResult {
                LocationDetailView(result: selectedResult)
                    .frame(minWidth: 400)
            } else {
                EmptySelectionView()
                    .frame(minWidth: 400)
            }
        }
        #endif
    }
    
    private var searchContentView: some View {
        VStack {
            SearchField(text: $searchText) { query in
                Task {
                    await searchController.performSearch(query)
                }
            }
            
            List(searchController.searchResults, selection: $searchController.selectedResult) { result in
                LocationRow(result: result)
                    #if os(iOS)
                    .onTapGesture {
                        searchController.selectedResult = result
                    }
                    #endif
            }
        }
        .navigationTitle("Location Search")
    }
}
```

## UIKit Platform Differences

### iOS Table View Implementation
```swift
#if os(iOS)
import UIKit

class LocationSearchViewController: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    private let locationSearch = LocationSearch()
    private var searchResults: [LocalSearchCompletion] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupiOSSpecificUI()
    }
    
    private func setupiOSSpecificUI() {
        // iOS-specific search bar configuration
        searchBar.delegate = self
        searchBar.placeholder = "Search for locations..."
        searchBar.searchBarStyle = .minimal
        
        // iOS table view configuration
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        
        // iOS navigation
        navigationItem.title = "Search"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
}

extension LocationSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
        let result = searchResults[indexPath.row]
        
        // Configure cell with iOS-specific highlighting
        let highlightedTitle = result.highlightedTitle(
            foregroundColor: .label,
            highlightColor: .systemBlue
        )
        
        let highlightedSubtitle = result.highlightedSubTitle(
            foregroundColor: .secondaryLabel,
            highlightColor: .systemBlue
        )
        
        cell.textLabel?.attributedText = NSAttributedString(highlightedTitle)
        cell.detailTextLabel?.attributedText = NSAttributedString(highlightedSubtitle)
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}
#endif
```

### macOS Table View Implementation
```swift
#if os(macOS)
import AppKit

class LocationSearchViewController: NSViewController {
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var scrollView: NSScrollView!
    
    private let locationSearch = LocationSearch()
    private var searchResults: [LocalSearchCompletion] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupmacOSSpecificUI()
    }
    
    private func setupmacOSSpecificUI() {
        // macOS-specific search field configuration
        searchField.delegate = self
        searchField.placeholderString = "Search for locations..."
        
        // macOS table view configuration
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Configure columns
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Location"
        titleColumn.width = 200
        tableView.addTableColumn(titleColumn)
        
        let subtitleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("subtitle"))
        subtitleColumn.title = "Address"
        subtitleColumn.width = 300
        tableView.addTableColumn(subtitleColumn)
    }
}

extension LocationSearchViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < searchResults.count else { return nil }
        
        let result = searchResults[row]
        
        if tableColumn?.identifier.rawValue == "title" {
            let highlightedTitle = result.highlightedTitle(
                foregroundColor: .labelColor,
                highlightColor: .controlAccentColor
            )
            return NSAttributedString(highlightedTitle)
        } else if tableColumn?.identifier.rawValue == "subtitle" {
            let highlightedSubtitle = result.highlightedSubTitle(
                foregroundColor: .secondaryLabelColor,
                highlightColor: .controlAccentColor
            )
            return NSAttributedString(highlightedSubtitle)
        }
        
        return nil
    }
}
#endif
```

## User Experience Differences

### iOS Patterns
- **Touch-first interaction**: Larger touch targets, gesture-based navigation
- **Modal presentations**: Full-screen search interfaces
- **Bottom-up flows**: Search results appear from bottom, detail views push
- **Single-tasking**: Focus on one task at a time

```swift
#if os(iOS)
struct iOSLocationSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [LocalSearchCompletion] = []
    @State private var selectedResult: LocalSearchCompletion?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearchTextChanged: performSearch)
                
                List(searchResults) { result in
                    LocationRow(result: result)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResult = result
                            showingDetail = true
                        }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDetail) {
                if let result = selectedResult {
                    LocationDetailView(result: result)
                }
            }
        }
    }
}
#endif
```

### macOS Patterns
- **Mouse/trackpad interaction**: Precise pointing, right-click menus
- **Multi-window support**: Side-by-side layouts
- **Master-detail layouts**: Split views with persistent selections
- **Multi-tasking**: Multiple windows and views simultaneously

```swift
#if os(macOS)
struct macOSLocationSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [LocalSearchCompletion] = []
    @State private var selectedResult: LocalSearchCompletion?
    
    var body: some View {
        HSplitView {
            // Master list
            VStack {
                SearchField(text: $searchText, onTextChanged: performSearch)
                    .padding()
                
                List(searchResults, selection: $selectedResult) { result in
                    LocationRow(result: result)
                        .tag(result)
                }
            }
            .frame(minWidth: 300, maxWidth: 500)
            
            // Detail view
            if let selectedResult = selectedResult {
                LocationDetailView(result: selectedResult)
                    .frame(minWidth: 400)
            } else {
                VStack {
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Select a location to view details")
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 400)
            }
        }
        .navigationTitle("Location Search")
    }
}
#endif
```

## Performance Considerations

### iOS Considerations
- **Memory constraints**: More aggressive memory management needed
- **Battery life**: Optimize for power efficiency
- **Network conditions**: Handle variable connectivity gracefully

```swift
#if os(iOS)
class iOSOptimizedSearchController: ObservableObject {
    private let locationSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 5,    // Higher threshold for mobile
        debounceSearchDelay: .milliseconds(400)  // Longer delay to save battery
    )
    
    func performSearch(_ query: String) async {
        // iOS-specific optimizations
        guard UIApplication.shared.applicationState == .active else {
            return // Don't search when app is backgrounded
        }
        
        // Check network conditions
        guard NetworkMonitor.shared.isConnected else {
            // Handle offline state
            return
        }
        
        // Perform search with error handling for mobile-specific issues
        do {
            let results = try await locationSearch.search(queryFragment: query)
            await MainActor.run {
                self.searchResults = results
            }
        } catch {
            // Handle mobile-specific errors (low connectivity, background limits)
        }
    }
}
#endif
```

### macOS Considerations
- **More resources available**: Can handle more aggressive caching
- **Persistent sessions**: Longer-running search sessions
- **Multi-window support**: Coordinate between multiple search instances

```swift
#if os(macOS)
class macOSOptimizedSearchController: ObservableObject {
    private let locationSearch = LocationSearch(
        numberOfCharactersBeforeSearching: 3,    // Lower threshold for desktop
        debounceSearchDelay: .milliseconds(200)  // Faster response for desktop
    )
    
    private let cache = NSCache<NSString, NSArray>()
    
    init() {
        // macOS can handle larger caches
        cache.countLimit = 500
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func performSearch(_ query: String) async {
        // Check cache first (more aggressive caching on macOS)
        if let cachedResults = cache.object(forKey: query as NSString) as? [LocalSearchCompletion] {
            await MainActor.run {
                self.searchResults = cachedResults
            }
            return
        }
        
        // Perform search
        do {
            let results = try await locationSearch.search(queryFragment: query)
            
            // Cache aggressively on macOS
            cache.setObject(results as NSArray, forKey: query as NSString)
            
            await MainActor.run {
                self.searchResults = results
            }
        } catch {
            // Handle desktop-specific errors
        }
    }
}
#endif
```

## Testing Platform-Specific Code

### Conditional Compilation Testing
```swift
import XCTest
@testable import MapKitSwiftSearch

class PlatformSpecificTests: XCTestCase {
    
    func testHighlightingColorTypes() {
        let completion = LocalSearchCompletion(/* mock data */)
        
        #if os(iOS)
        let highlightedTitle = completion.highlightedTitle(
            foregroundColor: .label,
            highlightColor: .systemBlue
        )
        XCTAssertNotNil(highlightedTitle)
        #endif
        
        #if os(macOS)
        let highlightedTitle = completion.highlightedTitle(
            foregroundColor: .labelColor,
            highlightColor: .controlAccentColor
        )
        XCTAssertNotNil(highlightedTitle)
        #endif
    }
    
    func testPlatformSpecificConfiguration() {
        #if os(iOS)
        // Test iOS-optimized configuration
        let search = LocationSearch(
            numberOfCharactersBeforeSearching: 5,
            debounceSearchDelay: .milliseconds(400)
        )
        #endif
        
        #if os(macOS)
        // Test macOS-optimized configuration
        let search = LocationSearch(
            numberOfCharactersBeforeSearching: 3,
            debounceSearchDelay: .milliseconds(200)
        )
        #endif
        
        XCTAssertNotNil(search)
    }
}
```

## Best Practices Summary

### Universal Principles
- Use the same core `LocationSearch` API across platforms
- Implement platform-specific UI appropriately
- Handle platform-specific performance characteristics
- Test on both platforms with platform-appropriate patterns

### iOS Best Practices
- Optimize for touch interaction and mobile constraints
- Use navigation stacks and modal presentations
- Implement appropriate memory and battery optimizations
- Follow iOS Human Interface Guidelines

### macOS Best Practices
- Leverage mouse precision and keyboard shortcuts
- Use split views and multi-window layouts appropriately
- Take advantage of larger screens and more resources
- Follow macOS Human Interface Guidelines

## Next Steps

- **<doc:GettingStarted>** - Review the basic integration steps
- **<doc:AdvancedUsage>** - Explore advanced customization options
- **<doc:ErrorHandling>** - Implement robust error handling for both platforms