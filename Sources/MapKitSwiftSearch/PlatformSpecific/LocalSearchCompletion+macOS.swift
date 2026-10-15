#if os(macOS)
import AppKit

// MARK: - macOS Text Highlighting Extensions

public extension LocalSearchCompletion {
    /// The title as an attributed string, with ``titleHighlightRange`` in the highlight color.
    ///
    /// The default colors suit a dark background.
    ///
    /// - Parameters:
    ///   - foregroundColor: The color for unmatched text.
    ///   - highlightColor: The color for the matched range.
    func highlightedTitle(
        foregroundColor: NSColor = .lightGray,
        highlightColor: NSColor = .white,
    ) -> AttributedString {
        highlightedText(
            from: title,
            highlightRange: titleHighlightRange,
            foregroundColor: foregroundColor,
            highlightColor: highlightColor,
        )
    }

    /// The subtitle as an attributed string, with ``subtitleHighlightRange`` in the highlight color.
    ///
    /// The default colors suit a dark background.
    ///
    /// - Parameters:
    ///   - foregroundColor: The color for unmatched text.
    ///   - highlightColor: The color for the matched range.
    func highlightedSubTitle(
        foregroundColor: NSColor = .lightGray,
        highlightColor: NSColor = .white,
    ) -> AttributedString {
        highlightedText(
            from: subTitle,
            highlightRange: subtitleHighlightRange,
            foregroundColor: foregroundColor,
            highlightColor: highlightColor,
        )
    }

    private func highlightedText(
        from text: String,
        highlightRange: HighlightRange?,
        foregroundColor: NSColor,
        highlightColor: NSColor,
    ) -> AttributedString {
        var attributedString = AttributedString(text)
        attributedString.foregroundColor = foregroundColor

        if let highlightRange {
            if let attributedStringRange = highlightRange.toAttributedStringRange(in: attributedString) {
                attributedString[attributedStringRange].foregroundColor = highlightColor
            }
        }

        return attributedString
    }
}
#endif
