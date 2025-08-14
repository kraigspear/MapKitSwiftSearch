# HighlightRange API Documentation

## Overview

`HighlightRange` is a `Sendable` wrapper around Foundation's `NSRange` that provides safe conversion to `AttributedString` ranges for text highlighting in modern Swift applications. It encapsulates range information from MapKit's search completion highlighting while providing thread-safe access patterns.

## Structure Declaration

```swift
public struct HighlightRange: Equatable, Sendable, Hashable
```

### Protocol Conformances

#### Sendable
- **Purpose**: Safe to pass between concurrent contexts
- **Implementation**: All properties are value types (Int)
- **Benefit**: Enables use in async/await operations without data races

#### Equatable
- **Use Case**: Comparison of highlight ranges for UI state management
- **Implementation**: Compares underlying location and length values
- **Precision**: Exact equality matching for range boundaries

#### Hashable
- **Use Case**: Efficient storage in collections and sets
- **Implementation**: Combines location and length for hash value
- **Performance**: Fast hash computation for typical range sizes

## Properties

### Private Storage

```swift
private let location: Int
private let length: Int
```

#### Why Private Properties?

The location and length properties are deliberately private to implement the **Information Hiding** principle:

1. **API Stability**: Internal representation can change without breaking client code
2. **Type Safety**: Prevents clients from manually manipulating range values incorrectly
3. **Focused Interface**: Only essential functionality is exposed through public methods
4. **Error Prevention**: Eliminates possibility of creating invalid ranges through direct manipulation

#### Property Details

##### location: Int
- **Content**: Starting position of the highlight range (0-based index)
- **Source**: `NSRange.location` from MapKit's highlight ranges
- **Validation**: MapKit ensures valid location values
- **Range**: 0 to string length

##### length: Int
- **Content**: Number of characters in the highlight range
- **Source**: `NSRange.length` from MapKit's highlight ranges  
- **Validation**: MapKit ensures non-negative length values
- **Range**: 0 to remaining string length from location

## Initialization

### NSRange Initializer

```swift
init(nsRange: NSRange)
```

#### Purpose
Creates a `HighlightRange` from a Foundation `NSRange` structure.

#### Implementation
```swift
init(nsRange: NSRange) {
    location = nsRange.location
    length = nsRange.length
}
```

#### Usage Context
- **Internal Use**: Called by other initializers within the package
- **Direct Creation**: Available for test code and internal utilities
- **Validation**: Assumes input `NSRange` is valid (from trusted sources)

### NSValue Initializer

```swift
init(nsValue: NSValue)
```

#### Purpose
Creates a `HighlightRange` from an `NSValue` that contains an `NSRange`. This is the primary initializer used when converting from MapKit's highlight range arrays.

#### Implementation
```swift
init(nsValue: NSValue) {
    var nsRange = NSRange()
    nsValue.getValue(&nsRange)
    self.init(nsRange: nsRange)
}
```

#### Why This Pattern?

MapKit provides highlight ranges as `[NSValue]` arrays where each `NSValue` contains an `NSRange`:
- **MapKit Convention**: `MKLocalSearchCompletion.titleHighlightRanges` returns `[NSValue]`
- **Objective-C Bridge**: NSValue is used to box C structures in Objective-C collections
- **Type Safety**: Extraction with `getValue(_:)` ensures correct type interpretation
- **Error Handling**: Foundation's `getValue(_:)` method handles type mismatches gracefully

#### Usage Example
```swift
// From LocalSearchCompletion initialization
titleHighlightRange = searchCompletion.titleHighlightRanges.first.map {
    HighlightRange(nsValue: $0)
}
```

## Public Methods

### toAttributedStringRange(in:)

```swift
func toAttributedStringRange(in attributedString: AttributedString) -> Range<AttributedString.Index>?
```

This is the primary public interface for `HighlightRange`, providing safe conversion to Swift's modern `AttributedString` range types.

#### Parameters

- **attributedString**: The target `AttributedString` where the range will be applied
- **Purpose**: Provides context for range validation and conversion
- **Requirement**: Must contain the text that the range was originally calculated for

#### Return Value

- **Type**: `Range<AttributedString.Index>?`
- **Success**: Valid range that can be used for AttributedString subscripting
- **Nil Return**: Range is invalid for the given attributed string

#### Implementation

```swift
func toAttributedStringRange(in attributedString: AttributedString) -> Range<AttributedString.Index>? {
    guard let stringRange = Range(asNSRange, in: attributedString) else {
        return nil
    }
    return stringRange
}
```

#### Internal Helper Property

```swift
private var asNSRange: NSRange {
    NSRange(location: location, length: length)
}
```

### Why This Design?

The conversion method is designed with safety and correctness as primary concerns:

1. **Bounds Checking**: Foundation's `Range(NSRange, in: String)` performs automatic bounds validation
2. **Unicode Safety**: Handles multi-byte Unicode characters correctly
3. **Nil Return**: Graceful failure for invalid ranges rather than crashes
4. **Type Bridge**: Safely converts between Foundation and Swift string types

#### Error Cases

The method returns `nil` in these situations:

##### Range Exceeds String Bounds
```swift
let text = AttributedString("Hello")  // Length: 5
let range = HighlightRange(nsRange: NSRange(location: 3, length: 5))  // Goes beyond end
let result = range.toAttributedStringRange(in: text)  // Returns nil
```

##### Invalid Starting Position
```swift
let text = AttributedString("Hello")
let range = HighlightRange(nsRange: NSRange(location: 10, length: 2))  // Starts beyond end
let result = range.toAttributedStringRange(in: text)  // Returns nil
```

##### Unicode Boundary Issues
```swift
let text = AttributedString("Café")  // Contains multi-byte character
let range = HighlightRange(nsRange: NSRange(location: 2, length: 1))  // Might split Unicode
let result = range.toAttributedStringRange(in: text)  // Returns nil if invalid
```

## Usage Patterns

### Safe Highlighting

```swift
func applyHighlighting(
    to attributedString: inout AttributedString,
    range: HighlightRange?,
    color: Color
) {
    guard let range = range,
          let stringRange = range.toAttributedStringRange(in: attributedString) else {
        // No highlighting available or range invalid
        return
    }
    
    attributedString[stringRange].foregroundColor = color
}
```

### Multiple Range Handling

```swift
func applyMultipleHighlights(
    to attributedString: inout AttributedString,
    ranges: [HighlightRange],
    color: Color
) {
    for highlightRange in ranges {
        if let stringRange = highlightRange.toAttributedStringRange(in: attributedString) {
            attributedString[stringRange].foregroundColor = color
        }
        // Silently skip invalid ranges
    }
}
```

### Validation and Debugging

```swift
extension HighlightRange {
    func isValid(for text: String) -> Bool {
        let attributedString = AttributedString(text)
        return toAttributedStringRange(in: attributedString) != nil
    }
    
    var debugDescription: String {
        "HighlightRange(location: \(location), length: \(length))"
    }
}
```

## Platform Integration

### iOS/UIKit Usage

```swift
// In LocalSearchCompletion+iOS.swift
private func highlightedText(
    from text: String,
    highlightRange: HighlightRange?,
    foregroundColor: UIColor,
    highlightColor: UIColor
) -> AttributedString {
    var attributedString = AttributedString(text)
    attributedString.foregroundColor = foregroundColor
    
    // Safe highlighting with HighlightRange
    if let highlightRange,
       let range = highlightRange.toAttributedStringRange(in: attributedString) {
        attributedString[range].foregroundColor = highlightColor
    }
    
    return attributedString
}
```

### macOS/AppKit Usage

```swift
// In LocalSearchCompletion+macOS.swift
private func highlightedText(
    from text: String,
    highlightRange: HighlightRange?,
    foregroundColor: NSColor,
    highlightColor: NSColor
) -> AttributedString {
    var attributedString = AttributedString(text)
    attributedString.foregroundColor = foregroundColor
    
    // Same safe highlighting pattern
    if let highlightRange,
       let range = highlightRange.toAttributedStringRange(in: attributedString) {
        attributedString[range].foregroundColor = highlightColor
    }
    
    return attributedString
}
```

## Design Rationale

### Why Not Expose NSRange Directly?

Several alternatives were considered:

#### Alternative 1: Public NSRange Property
```swift
// Rejected approach
public let nsRange: NSRange
```
**Problems**:
- Exposes Foundation implementation details
- Requires clients to understand NSRange conversion
- No automatic bounds checking
- Breaks abstraction layer

#### Alternative 2: Direct Range<String.Index> Storage
```swift
// Rejected approach  
public let stringRange: Range<String.Index>
```
**Problems**:
- String.Index is tied to specific string content
- Cannot be stored independently of source string
- Complex initialization from MapKit data
- Not Sendable across different strings

#### Chosen Approach: Conversion Method
```swift
// Actual implementation
func toAttributedStringRange(in attributedString: AttributedString) -> Range<AttributedString.Index>?
```
**Benefits**:
- Encapsulates complexity of range conversion
- Provides bounds checking and validation
- Works with any AttributedString content
- Safe failure mode with nil return
- Maintains abstraction boundaries

### Thread Safety Considerations

The design ensures thread safety through:

1. **Immutable State**: All properties are `let` constants
2. **Value Semantics**: Struct provides automatic copying
3. **No Shared References**: No reference types in the implementation
4. **Stateless Methods**: `toAttributedStringRange` has no side effects

### Memory Efficiency

- **Minimal Storage**: Only two Int values stored
- **No Caching**: Ranges are computed on-demand to avoid stale data
- **Value Type**: Automatic memory management with no retain cycles
- **Small Footprint**: Suitable for storage in large collections

## Best Practices

### Error Handling
```swift
// Always handle nil return from conversion
func safeHighlight(text: AttributedString, range: HighlightRange?) -> AttributedString {
    guard let range = range else { return text }
    
    var highlighted = text
    if let stringRange = range.toAttributedStringRange(in: highlighted) {
        highlighted[stringRange].foregroundColor = .blue
    } else {
        // Log for debugging but don't crash
        print("Warning: Invalid highlight range for text: \(text)")
    }
    return highlighted
}
```

### Performance Optimization
```swift
// Cache attributed strings if applying multiple highlights
func multipleHighlights(
    text: String,
    ranges: [HighlightRange],
    colors: [Color]
) -> AttributedString {
    var attributed = AttributedString(text)
    
    // Apply all highlights in single pass
    for (range, color) in zip(ranges, colors) {
        if let stringRange = range.toAttributedStringRange(in: attributed) {
            attributed[stringRange].foregroundColor = color
        }
    }
    
    return attributed
}
```

### Testing Strategies
```swift
// Test edge cases for range validation
func testHighlightRange() {
    let text = AttributedString("Test string")
    
    // Valid range
    let validRange = HighlightRange(nsRange: NSRange(location: 0, length: 4))
    XCTAssertNotNil(validRange.toAttributedStringRange(in: text))
    
    // Invalid range - exceeds bounds
    let invalidRange = HighlightRange(nsRange: NSRange(location: 5, length: 10))
    XCTAssertNil(invalidRange.toAttributedStringRange(in: text))
    
    // Empty range - should be valid
    let emptyRange = HighlightRange(nsRange: NSRange(location: 0, length: 0))
    XCTAssertNotNil(emptyRange.toAttributedStringRange(in: text))
}
```

This comprehensive documentation ensures developers understand both the practical usage and underlying design principles of `HighlightRange`, enabling them to use it effectively while maintaining code safety and performance.