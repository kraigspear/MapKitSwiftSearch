//
//  LocalSearchCompletion+iOS.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/27/24.
//

#if os(iOS)
    import UIKit

    // MARK: - iOS Text Highlighting Extensions

    /// iOS-specific extensions for LocalSearchCompletion that provide UIKit-based text highlighting.
    ///
    /// These methods create AttributedString instances with UIColor-based styling optimized
    /// for iOS interfaces. The highlighting uses UIKit's color system and is designed to
    /// work seamlessly with iOS UI frameworks.
    public extension LocalSearchCompletion {
        /// Creates an attributed version of the title with iOS-specific highlighting.
        ///
        /// This method applies UIKit colors to create visually distinct highlighting
        /// for the portions of the title that match the user's search query.
        /// The highlighting helps users quickly identify why this result matched their search.
        ///
        /// - Parameters:
        ///   - foregroundColor: The color for non-highlighted text. Defaults to .lightGray
        ///                     which provides good contrast on dark backgrounds common in iOS search interfaces.
        ///   - highlightColor: The color for highlighted text. Defaults to .white
        ///                    which creates strong emphasis against the subdued foreground color.
        /// - Returns: An AttributedString with appropriate color styling applied.
        ///
        /// Example usage:
        /// ```swift
        /// let completion: LocalSearchCompletion = // ... from search results
        /// let styledTitle = completion.highlightedTitle(
        ///     foregroundColor: .systemGray,
        ///     highlightColor: .systemBlue
        /// )
        /// // Use styledTitle in a Text view or UILabel
        /// ```
        func highlightedTitle(
            foregroundColor: UIColor = .lightGray,
            highlightColor: UIColor = .white,
        ) -> AttributedString {
            highlightedText(from: title,
                            highlightRange: titleHighlightRange,
                            foregroundColor: foregroundColor,
                            highlightColor: highlightColor)
        }

        /// Creates an attributed version of the subtitle with iOS-specific highlighting.
        ///
        /// Similar to highlightedTitle, this method applies UIKit colors to emphasize
        /// the portions of the subtitle that match the search query. This is particularly
        /// useful for address components or category information that matches the search.
        ///
        /// - Parameters:
        ///   - foregroundColor: The color for non-highlighted text. Defaults to .lightGray.
        ///   - highlightColor: The color for highlighted text. Defaults to .white.
        /// - Returns: An AttributedString with appropriate color styling applied.
        ///
        /// Example usage:
        /// ```swift
        /// let styledSubtitle = completion.highlightedSubTitle(
        ///     foregroundColor: .secondaryLabel,
        ///     highlightColor: .label
        /// )
        /// ```
        func highlightedSubTitle(
            foregroundColor: UIColor = .lightGray,
            highlightColor: UIColor = .white,
        ) -> AttributedString {
            highlightedText(from: subTitle,
                            highlightRange: subtitleHighlightRange,
                            foregroundColor: foregroundColor,
                            highlightColor: highlightColor)
        }

        /// Creates highlighted attributed text using UIKit colors.
        ///
        /// This private helper method performs the actual text styling by applying
        /// colors to create visual emphasis. It handles the conversion from HighlightRange
        /// to AttributedString ranges and applies the appropriate UIColors.
        ///
        /// The method uses a two-step process: first applying the base foreground color
        /// to the entire string, then overlaying the highlight color on the specified range.
        /// This ensures consistent styling even when highlight ranges are not available.
        ///
        /// - Parameters:
        ///   - text: The source text to be styled.
        ///   - highlightRange: The range to highlight, if any. When nil, only base styling is applied.
        ///   - foregroundColor: The UIColor for the base text.
        ///   - highlightColor: The UIColor for the highlighted portion.
        /// - Returns: An AttributedString with the specified color styling.
        private func highlightedText(
            from text: String,
            highlightRange: HighlightRange?,
            foregroundColor: UIColor,
            highlightColor: UIColor,
        ) -> AttributedString {
            // Create the base attributed string with the default foreground color
            // This ensures all text has consistent styling even without highlights
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
