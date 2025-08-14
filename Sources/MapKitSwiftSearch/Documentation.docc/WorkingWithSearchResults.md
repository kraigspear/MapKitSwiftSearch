# Working with Search Results

Learn how to effectively display, highlight, and interact with location search results.

## Overview

MapKitSwiftSearch provides rich data structures for working with search results, including highlighting capabilities and detailed location information. This guide covers how to display results effectively and handle user interactions.

## Understanding Search Results

### LocalSearchCompletion Structure

Each search result is represented by a `LocalSearchCompletion`:

```swift
let results = try await locationSearch.search(queryFragment: "Coffee")

for result in results {
    // Basic information
    print("Title: \(result.title)")           // "Starbucks"
    print("Subtitle: \(result.subTitle)")     // "123 Main St, Anytown, CA"
    print("Unique ID: \(result.id)")          // "Starbucks-123 Main St, Anytown, CA"
    
    // Highlighting information
    if let titleHighlight = result.titleHighlightRange {
        print("Title has search term highlighting")
    }
    
    if let subtitleHighlight = result.subtitleHighlightRange {
        print("Subtitle has search term highlighting")
    }
}
```

## Text Highlighting

MapKitSwiftSearch provides platform-specific extensions for highlighting matching text in search results.

### iOS Highlighting

```swift
#if os(iOS)
import UIKit

// In your table view cell or list row
func configureCell(with result: LocalSearchCompletion) {
    // Create highlighted attributed strings
    let highlightedTitle = result.highlightedTitle(
        foregroundColor: .label,        // Default text color
        highlightColor: .systemBlue     // Highlighted text color
    )
    
    let highlightedSubtitle = result.highlightedSubTitle(
        foregroundColor: .secondaryLabel,
        highlightColor: .systemBlue
    )
    
    // Apply to UI elements
    titleLabel.attributedText = NSAttributedString(highlightedTitle)
    subtitleLabel.attributedText = NSAttributedString(highlightedSubtitle)
}
#endif
```

### macOS Highlighting

```swift
#if os(macOS)
import AppKit

// In your table view cell or collection view item
func configureCell(with result: LocalSearchCompletion) {
    // Create highlighted attributed strings
    let highlightedTitle = result.highlightedTitle(
        foregroundColor: .labelColor,
        highlightColor: .controlAccentColor
    )
    
    let highlightedSubtitle = result.highlightedSubTitle(
        foregroundColor: .secondaryLabelColor,
        highlightColor: .controlAccentColor
    )
    
    // Apply to UI elements
    titleTextField.attributedStringValue = NSAttributedString(highlightedTitle)
    subtitleTextField.attributedStringValue = NSAttributedString(highlightedSubtitle)
}
#endif
```

### SwiftUI Highlighting

For SwiftUI, use the `Text` view with AttributedString:

```swift
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

## Getting Detailed Location Information

Convert search results to detailed placemarks:

```swift
func selectLocation(_ completion: LocalSearchCompletion) async {
    do {
        // Get detailed placemark information
        guard let placemark = try await locationSearch.placemark(for: completion) else {
            print("No detailed information available")
            return
        }
        
        // Access detailed location data
        print("Name: \(placemark.name ?? "Unknown")")
        print("Coordinates: \(placemark.coordinate)")
        
        // Build formatted address
        let addressComponents = [
            placemark.subThoroughfare,    // House number
            placemark.thoroughfare,       // Street name
            placemark.locality,           // City
            placemark.administrativeArea, // State
            placemark.postalCode         // ZIP code
        ].compactMap { $0 }
        
        let formattedAddress = addressComponents.joined(separator: ", ")
        print("Address: \(formattedAddress)")
        
        // Access additional information
        if let countryName = placemark.countryName {
            print("Country: \(countryName)")
        }
        
        if let countryCode = placemark.countryCode {
            print("Country Code: \(countryCode)")
        }
        
    } catch {
        print("Failed to get placemark details: \(error)")
    }
}
```

## Complete SwiftUI Example

Here's a complete SwiftUI implementation with highlighting and selection:

```swift
import SwiftUI
import MapKitSwiftSearch
import MapKit

struct LocationSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [LocalSearchCompletion] = []
    @State private var selectedPlacemark: Placemark?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let locationSearch = LocationSearch()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search field
                SearchField(
                    text: $searchText,
                    isLoading: isLoading,
                    onSearchTextChanged: performSearch
                )
                
                // Error message
                if let errorMessage = errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                
                // Results list
                List(searchResults) { result in
                    LocationResultRow(result: result) {
                        Task {
                            await selectLocation(result)
                        }
                    }
                }
                
                // Selected location details
                if let selectedPlacemark = selectedPlacemark {
                    SelectedLocationView(placemark: selectedPlacemark)
                }
            }
            .navigationTitle("Location Search")
        }
    }
    
    private func performSearch(_ query: String) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let results = try await locationSearch.search(queryFragment: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch LocationSearchError.debounce {
                // Ignore debounced searches
                await MainActor.run {
                    self.isLoading = false
                }
            } catch LocationSearchError.invalidSearchCriteria {
                await MainActor.run {
                    self.searchResults = []
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.searchResults = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectLocation(_ completion: LocalSearchCompletion) async {
        do {
            let placemark = try await locationSearch.placemark(for: completion)
            await MainActor.run {
                self.selectedPlacemark = placemark
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to get location details: \(error.localizedDescription)"
            }
        }
    }
}

struct LocationResultRow: View {
    let result: LocalSearchCompletion
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(highlightedTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(highlightedSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
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

struct SelectedLocationView: View {
    let placemark: Placemark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Location")
                .font(.headline)
            
            if let name = placemark.name {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(formattedAddress)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Coordinates: \(placemark.coordinate.latitude), \(placemark.coordinate.longitude)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var formattedAddress: String {
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ].compactMap { $0 }
        
        return components.joined(separator: ", ")
    }
}
```

## Working with Map Integration

Integrate search results with MapKit views:

```swift
import MapKit

struct MapSearchView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var annotations: [PlacemarkAnnotation] = []
    
    private let locationSearch = LocationSearch()
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
            MapPin(coordinate: annotation.coordinate, tint: .red)
        }
        .searchable(text: $searchText) {
            // Search suggestions
        }
        .onSubmit(of: .search) {
            Task {
                await searchAndShowOnMap(searchText)
            }
        }
    }
    
    private func searchAndShowOnMap(_ query: String) async {
        do {
            let results = try await locationSearch.search(queryFragment: query)
            var newAnnotations: [PlacemarkAnnotation] = []
            
            for result in results {
                if let placemark = try await locationSearch.placemark(for: result) {
                    newAnnotations.append(PlacemarkAnnotation(placemark: placemark))
                }
            }
            
            await MainActor.run {
                self.annotations = newAnnotations
                
                // Center map on first result
                if let firstAnnotation = newAnnotations.first {
                    self.region = MKCoordinateRegion(
                        center: firstAnnotation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        } catch {
            print("Map search failed: \(error)")
        }
    }
}

struct PlacemarkAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    
    init(placemark: Placemark) {
        self.coordinate = placemark.coordinate
        self.title = placemark.name ?? "Location"
    }
}
```

## Best Practices

### Result Display

1. **Always show highlighting** - Users expect to see why results match their search
2. **Limit result count** - Display 10-15 results maximum for better UX
3. **Provide clear hierarchy** - Make title prominent, subtitle secondary
4. **Handle empty states** - Show appropriate messages when no results found

### Performance

1. **Debounce search calls** - Let MapKitSwiftSearch handle this automatically
2. **Cache placemark details** - Avoid repeated API calls for the same location
3. **Cancel previous searches** - When starting new searches
4. **Load details on demand** - Only get placemark details when user selects a result

### Accessibility

1. **Provide accessible labels** - Include both title and subtitle in accessibility descriptions
2. **Support keyboard navigation** - Ensure results are navigable via keyboard
3. **Use semantic markup** - Apply appropriate heading and content roles

## Next Steps

- **<doc:ErrorHandling>** - Learn how to handle different error scenarios
- **<doc:AdvancedUsage>** - Explore performance optimization and customization
- **<doc:PlatformDifferences>** - Understand iOS vs macOS specific features