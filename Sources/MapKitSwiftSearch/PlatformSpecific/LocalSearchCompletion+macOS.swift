//
//  LocalSearchCompletion+macOS.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/27/24.
//

#if os(macOS)
    import AppKit

    // MARK: - macOS Text Highlighting Extensions

    /// macOS-specific extensions for LocalSearchCompletion that provide AppKit-based text highlighting.
    ///
    /// These methods create AttributedString instances with NSColor-based styling optimized
    /// for macOS interfaces. The highlighting uses AppKit's color system and is designed to
    /// work seamlessly with macOS UI frameworks like AppKit and SwiftUI on macOS.
    public extension LocalSearchCompletion {
        /// Creates an attributed version of the title with macOS-specific highlighting.
        ///
        /// This method applies AppKit colors to create visually distinct highlighting
        /// for the portions of the title that match the user's search query.
        /// The highlighting follows macOS design principles and integrates well with
        /// the platform's native appearance.
        ///
        /// - Parameters:
        ///   - foregroundColor: The color for non-highlighted text. Defaults to .lightGray
        ///                     which provides appropriate contrast for macOS interfaces.
        ///   - highlightColor: The color for highlighted text. Defaults to .white
        ///                    which creates clear emphasis against the subdued foreground.
        /// - Returns: An AttributedString with appropriate color styling applied.
        ///
        /// Example usage:
        /// ```swift
        /// let completion: LocalSearchCompletion = // ... from search results
        /// let styledTitle = completion.highlightedTitle(
        ///     foregroundColor: .secondaryLabelColor,
        ///     highlightColor: .controlAccentColor
        /// )
        /// // Use styledTitle in a Text view or NSTextField
        /// ```
        func highlightedTitle(
            foregroundColor: NSColor = .lightGray,
            highlightColor: NSColor = .white,
        ) -> AttributedString {
            highlightedText(from: title,
                            highlightRange: titleHighlightRange,
                            foregroundColor: foregroundColor,
                            highlightColor: highlightColor)
        }

        /// Creates an attributed version of the subtitle with macOS-specific highlighting.
        ///
        /// Similar to highlightedTitle, this method applies AppKit colors to emphasize
        /// the portions of the subtitle that match the search query. This method is
        /// particularly useful for highlighting address components or category information
        /// in macOS search interfaces.
        ///
        /// - Parameters:
        ///   - foregroundColor: The color for non-highlighted text. Defaults to .lightGray.
        ///   - highlightColor: The color for highlighted text. Defaults to .white.
        /// - Returns: An AttributedString with appropriate color styling applied.
        ///
        /// Example usage:
        /// ```swift
        /// let styledSubtitle = completion.highlightedSubTitle(
        ///     foregroundColor: .tertiaryLabelColor,
        ///     highlightColor: .labelColor
        /// )
        /// ```
        func highlightedSubTitle(
            foregroundColor: NSColor = .lightGray,
            highlightColor: NSColor = .white,
        ) -> AttributedString {
            highlightedText(from: subTitle,
                            highlightRange: subtitleHighlightRange,
                            foregroundColor: foregroundColor,
                            highlightColor: highlightColor)
        }

        /// Creates highlighted attributed text using AppKit colors.
        ///
        /// This private helper method performs the actual text styling by applying
        /// NSColors to create visual emphasis. It handles the conversion from HighlightRange
        /// to AttributedString ranges and applies the appropriate AppKit colors.
        ///
        /// The method follows the same two-step process as the iOS version but uses
        /// NSColor instead of UIColor, ensuring proper integration with macOS's
        /// color management and appearance system.
        ///
        /// - Parameters:
        ///   - text: The source text to be styled.
        ///   - highlightRange: The range to highlight, if any. When nil, only base styling is applied.
        ///   - foregroundColor: The NSColor for the base text.
        ///   - highlightColor: The NSColor for the highlighted portion.
        /// - Returns: An AttributedString with the specified color styling.
        private func highlightedText(
            from text: String,
            highlightRange: HighlightRange?,
            foregroundColor: NSColor,
            highlightColor: NSColor,
        ) -> AttributedString {
            // Create the base attributed string with the default foreground color
            // This ensures consistent styling across all text even without highlights
            var attributedString = AttributedString(text)
            attributedString.foregroundColor = foregroundColor

            // Apply highlighting to the specified range if available
            // The range conversion handles the bridge between NSRange and AttributedString indexing
            if let highlightRange {
                if let attributedStringRange = highlightRange.toAttributedStringRange(in: attributedString) {
                    attributedString[attributedStringRange].foregroundColor = highlightColor
                }
            }

            return attributedString
        }
    }
#endif
