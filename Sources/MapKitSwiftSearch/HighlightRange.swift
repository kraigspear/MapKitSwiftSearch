//
//  HighlightRange.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/26/24.
//

import Foundation

/// Represents a text highlight range for search completion results.
///
/// `HighlightRange` provides a thread-safe, platform-independent way to store and manipulate
/// text ranges that should be highlighted in search results. It wraps NSRange functionality
/// while maintaining Sendable compliance for use across concurrent contexts.
///
/// This struct is designed to bridge between MapKit's NSRange-based highlighting system
/// and Swift's modern AttributedString APIs, enabling consistent text highlighting
/// across iOS and macOS platforms.
///
/// Example usage:
/// ```swift
/// let nsRange = NSRange(location: 5, length: 3)
/// let highlightRange = HighlightRange(nsRange: nsRange)
///
/// // Convert to AttributedString range for text styling
/// let attributedString = AttributedString("Coffee shops near me")
/// if let range = highlightRange.toAttributedStringRange(in: attributedString) {
///     // Apply highlighting to the range
/// }
/// ```
public struct HighlightRange: Equatable, Sendable, Hashable {
    /// The starting position of the highlight range within the text.
    ///
    /// Corresponds to NSRange.location and represents the zero-based character index
    /// where the highlight should begin.
    private let location: Int

    /// The number of characters to highlight starting from the location.
    ///
    /// Corresponds to NSRange.length and determines how many consecutive characters
    /// should be included in the highlight.
    private let length: Int

    // MARK: - Initialization

    /// Creates a highlight range from an NSRange.
    ///
    /// This initializer converts MapKit's NSRange-based highlight information into
    /// a Sendable-compliant format for safe use across concurrent contexts.
    ///
    /// - Parameter nsRange: The NSRange containing location and length information
    ///                     from MapKit's search completion highlighting.
    init(nsRange: NSRange) {
        location = nsRange.location
        length = nsRange.length
    }

    /// Creates a highlight range from an NSValue containing an NSRange.
    ///
    /// MapKit provides highlight ranges as NSValue objects wrapping NSRange structures.
    /// This initializer extracts the NSRange and converts it to a HighlightRange.
    ///
    /// - Parameter nsValue: An NSValue object containing an NSRange structure
    ///                     from MapKit's highlight range arrays.
    init(nsValue: NSValue) {
        var nsRange = NSRange()
        nsValue.getValue(&nsRange)
        self.init(nsRange: nsRange)
    }

    // MARK: - Private Helpers

    /// Converts this highlight range back to an NSRange.
    ///
    /// Provides internal access to the underlying NSRange representation for
    /// compatibility with Foundation APIs that require NSRange parameters.
    ///
    /// - Returns: An NSRange with the same location and length values.
    private var asNSRange: NSRange {
        NSRange(location: location, length: length)
    }

    // MARK: - Public Methods

    /// Converts this highlight range to an AttributedString range for text styling.
    ///
    /// This method bridges between the NSRange-based highlight information from MapKit
    /// and Swift's AttributedString range system, enabling proper text styling in modern
    /// Swift UI frameworks.
    ///
    /// The conversion accounts for potential differences between NSString-based character
    /// counting (used by MapKit) and Swift String's Unicode-correct indexing.
    ///
    /// - Parameter attributedString: The attributed string to create a range within.
    /// - Returns: A range within the attributed string if the conversion is valid,
    ///           nil if the range extends beyond the string's bounds or is invalid.
    ///
    /// Example:
    /// ```swift
    /// let text = AttributedString("Coffee shops")
    /// let highlightRange = HighlightRange(nsRange: NSRange(location: 0, length: 6))
    ///
    /// if let range = highlightRange.toAttributedStringRange(in: text) {
    ///     // Apply styling to the range
    ///     var styledText = text
    ///     styledText[range].foregroundColor = .blue
    /// }
    /// ```
    func toAttributedStringRange(in attributedString: AttributedString) -> Range<AttributedString.Index>? {
        guard let stringRange = Range(asNSRange, in: attributedString) else {
            return nil
        }
        return stringRange
    }
}
