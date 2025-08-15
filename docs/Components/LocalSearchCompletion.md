# LocalSearchCompletion API Documentation

## Overview

`LocalSearchCompletion` is a `Sendable` wrapper around MapKit's `MKLocalSearchCompletion` that provides enhanced functionality for concurrent Swift applications. It includes highlight range information for UI text highlighting and platform-specific methods for creating attributed strings.

## Structure Declaration

```swift
public struct LocalSearchCompletion: Identifiable, Equatable, Sendable, Hashable, CustomStringConvertible
```

### Protocol Conformances

#### Identifiable
- **Requirement**: Provides stable identity for SwiftUI lists and collections
- **Implementation**: Uses combination of title and subtitle for unique identification

#### Sendable
- **Purpose**: Safe to pass between actor contexts and concurrent operations  
- **Benefit**: Enables use in async/await contexts without data races

#### Equatable & Hashable
- **Use Case**: Enables efficient collection operations and duplicate detection
- **Implementation**: Based on all stored properties for complete equality semantics

## Properties

### Core Properties

```swift
public let id: String
public let title: String  
public let subTitle: String
```

#### id: String
- **Format**: `"\(title)-\(subTitle)"`
- **Purpose**: Stable identifier for SwiftUI list management
- **Uniqueness**: Combination ensures reasonable uniqueness for most use cases
- **Note**: Not globally unique; duplicates possible with identical title/subtitle combinations

#### title: String
- **Source**: `MKLocalSearchCompletion.title`
- **Content**: Primary location name (e.g., "Starbucks", "Central Park")
- **Typical Use**: Main display text in search results

#### subTitle: String  
- **Source**: `MKLocalSearchCompletion.subtitle`
- **Content**: Additional location details (e.g., "123 Main St, New York, NY")
- **Typical Use**: Secondary display text providing context

### Highlight Range Properties

```swift
public let titleHighlightRange: HighlightRange?
public let subtitleHighlightRange: HighlightRange?
```

#### titleHighlightRange: HighlightRange?
- **Purpose**: Indicates which portion of the title matches the search query
- **Source**: First element of `MKLocalSearchCompletion.titleHighlightRanges`
- **Nil Case**: No highlighting available for the title
- **Usage**: UI highlighting of matching text portions

#### subtitleHighlightRange: HighlightRange?
- **Purpose**: Indicates which portion of the subtitle matches the search query
- **Source**: First element of `MKLocalSearchCompletion.subtitleHighlightRanges`
- **Nil Case**: No highlighting available for the subtitle
- **Usage**: UI highlighting of matching text portions

## Initialization

### Internal Initializer

```swift
init(_ searchCompletion: MKLocalSearchCompletion)
```

This initializer is internal to the package because:
- **Encapsulation**: Clients should only receive instances from `LocationSearch.search()`
- **Data Integrity**: Ensures proper conversion from MapKit types
- **API Stability**: Internal construction prevents invalid state creation

#### Conversion Process

```swift
// String properties - direct assignment
title = searchCompletion.title
subTitle = searchCompletion.subtitle

// ID generation - combines title and subtitle
id = "\(title)-\(subTitle)"

// Highlight range conversion - takes first available range
titleHighlightRange = searchCompletion.titleHighlightRanges.first.map {
    HighlightRange(nsValue: $0)
}

subtitleHighlightRange = searchCompletion.subtitleHighlightRanges.first.map {
    HighlightRange(nsValue: $0)
}
```

#### Why Only First Highlight Range?

MapKit can provide multiple highlight ranges, but we only use the first because:
- **Simplicity**: Most use cases only need primary highlighting
- **UI Consistency**: Multiple highlights can create visual confusion
- **Performance**: Reduces memory overhead for typical applications
- **Extensibility**: Can be enhanced later if multiple ranges are needed

## Platform-Specific Extensions

The package provides platform-specific highlighting methods that return `AttributedString` instances with appropriate color formatting.

### iOS Extension (UIKit)

```swift
#if os(iOS)
public extension LocalSearchCompletion {
    func highlightedTitle(
        foregroundColor: UIColor = .lightGray,
        highlightColor: UIColor = .white
    ) -> AttributedString
    
    func highlightedSubTitle(
        foregroundColor: UIColor = .lightGray,
        highlightColor: UIColor = .white
    ) -> AttributedString
}
#endif
```

### macOS Extension (AppKit)

```swift
#if os(macOS)
public extension LocalSearchCompletion {
    func highlightedTitle(
        foregroundColor: NSColor = .lightGray,
        highlightColor: NSColor = .white
    ) -> AttributedString
    
    func highlightedSubTitle(
        foregroundColor: NSColor = .lightGray,
        highlightColor: NSColor = .white
    ) -> AttributedString
}
#endif
```

### Why Platform-Specific Extensions?

This design was chosen because:

1. **Type Safety**: Uses platform-appropriate color types (`UIColor` vs `NSColor`)
2. **No Runtime Checks**: Compile-time platform selection is more efficient
3. **Clean Separation**: Core model remains platform-agnostic
4. **Maintainability**: Platform-specific code is clearly isolated
5. **Performance**: No abstraction layer overhead for color handling

### Usage Examples

#### iOS Implementation
```swift
import UIKit

// Basic usage with default colors
let highlightedTitle = completion.highlightedTitle()

// Custom colors for dark mode
let darkModeTitle = completion.highlightedTitle(
    foregroundColor: .white,
    highlightColor: .systemBlue
)

// Usage in SwiftUI
Text(AttributedString(highlightedTitle))
```

#### macOS Implementation
```swift
import AppKit

// Basic usage with default colors
let highlightedTitle = completion.highlightedTitle()

// Custom colors for dark mode
let darkModeTitle = completion.highlightedTitle(
    foregroundColor: .white,
    highlightColor: .systemBlue
)

// Usage in SwiftUI
Text(AttributedString(highlightedTitle))
```

## Implementation Details

### Color Application Logic

The highlighting methods follow this pattern:

```swift
private func highlightedText(
    from text: String,
    highlightRange: HighlightRange?,
    foregroundColor: PlatformColor,
    highlightColor: PlatformColor
) -> AttributedString {
    // 1. Create attributed string with base foreground color
    var attributedString = AttributedString(text)
    attributedString.foregroundColor = foregroundColor
    
    // 2. Apply highlight color to matching range if available
    if let highlightRange {
        if let attributedStringRange = highlightRange.toAttributedStringRange(in: attributedString) {
            attributedString[attributedStringRange].foregroundColor = highlightColor
        }
    }
    
    return attributedString
}
```

#### Why This Implementation?

1. **Safety First**: Applies base color to entire string before highlighting
2. **Graceful Degradation**: Works even if highlight range is nil or invalid
3. **Range Validation**: Uses `HighlightRange.toAttributedStringRange` for safe conversion
4. **Color Isolation**: Keeps highlight colors separate from base formatting

### Error Handling in Highlighting

The highlighting methods are designed to never fail:

- **Invalid Ranges**: Silently ignored, base color remains
- **Nil Ranges**: Entire text uses foreground color
- **Empty Strings**: Return empty attributed string with no errors
- **Unicode Handling**: `AttributedString` handles Unicode correctly

## Usage Patterns

### Basic Display in Lists

```swift
struct SearchResultRow: View {
    let completion: LocalSearchCompletion
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(completion.highlightedTitle())
                .font(.headline)
            Text(completion.highlightedSubTitle())
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

### Custom Color Schemes

```swift
extension LocalSearchCompletion {
    func highlightedTitleForDarkMode() -> AttributedString {
        #if os(iOS)
        return highlightedTitle(
            foregroundColor: .secondaryLabel,
            highlightColor: .label
        )
        #else
        return highlightedTitle(
            foregroundColor: .secondaryLabelColor,
            highlightColor: .labelColor
        )
        #endif
    }
}
```

### Search Result Processing

```swift
func processSearchResults(_ completions: [LocalSearchCompletion]) {
    // Group by title prefix
    let grouped = Dictionary(grouping: completions) { completion in
        String(completion.title.prefix(1))
    }
    
    // Filter unique locations
    let unique = completions.reduce(into: []) { result, completion in
        if !result.contains(where: { $0.id == completion.id }) {
            result.append(completion)
        }
    }
    
    // Sort by title length (shorter titles first)
    let sorted = completions.sorted { $0.title.count < $1.title.count }
}
```

## Performance Considerations

### Memory Efficiency
- **Value Type**: Struct semantics provide automatic memory management
- **String Storage**: Uses Swift's efficient string storage
- **Minimal Overhead**: No reference counting or dynamic allocation for properties

### Highlighting Performance
- **Lazy Evaluation**: Attributed strings created only when highlighting methods called
- **Range Caching**: `HighlightRange` caches converted ranges for efficiency
- **Color Reuse**: Default colors are static and reused across instances

### Collection Performance
- **Hashable**: Efficient `Set` and `Dictionary` operations
- **Identifiable**: Optimized SwiftUI list updates
- **Comparable Operations**: Fast sorting and searching in collections

## Best Practices

### UI Integration
- Use highlighting methods for search result displays
- Provide consistent color schemes across your application
- Test highlighting with various query lengths and content types
- Consider accessibility when choosing highlight colors

### Data Management
- Use the `id` property for stable SwiftUI list identification
- Implement custom comparison logic if you need different equality semantics
- Cache highlighted attributed strings if the same completion is displayed repeatedly
- Consider the lifecycle of completion objects in your data models

### Error Prevention
- Always handle the case where highlighting methods return unhighlighted text
- Don't assume highlight ranges will always be present
- Test with edge cases like empty strings, very long strings, and Unicode content
- Validate that your color choices provide adequate contrast for accessibility

## Debugging and Troubleshooting

### Common Issues

#### No Highlighting Visible
- **Cause**: Highlight color too similar to background
- **Solution**: Increase color contrast or use accessibility-aware colors

#### Incorrect Highlight Positioning  
- **Cause**: String encoding mismatches between search query and result
- **Solution**: Verify that `HighlightRange.toAttributedStringRange` returns valid ranges

#### Missing Highlights
- **Cause**: `titleHighlightRange` or `subtitleHighlightRange` is nil
- **Solution**: Check if MapKit provided highlight ranges in original `MKLocalSearchCompletion`

### Logging and Inspection

```swift
extension LocalSearchCompletion {
    var debugDescription: String {
        """
        LocalSearchCompletion(
            id: \(id)
            title: "\(title)"
            subTitle: "\(subTitle)"
            titleHighlightRange: \(titleHighlightRange?.debugDescription ?? "nil")
            subtitleHighlightRange: \(subtitleHighlightRange?.debugDescription ?? "nil")
        )
        """
    }
}
```

This detailed documentation provides developers with comprehensive understanding of how to effectively use `LocalSearchCompletion` in their applications while understanding the architectural decisions behind its design.