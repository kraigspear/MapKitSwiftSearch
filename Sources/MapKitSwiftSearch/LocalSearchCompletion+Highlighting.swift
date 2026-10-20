import SwiftUI

public extension LocalSearchCompletion {
    /// The title, with every part that matches the query fragment in the highlight color.
    ///
    /// The defaults read in both light and dark appearance. Matches can overlap, and a match that
    /// doesn't fit the title is left uncolored.
    ///
    /// - Parameters:
    ///   - foreground: The color for text that doesn't match.
    ///   - highlight: The color for text that matches.
    func highlightedTitle(foreground: Color = .secondary, highlight: Color = .primary) -> AttributedString {
        Self.highlightedText(title, highlights: titleHighlights, foreground: foreground, highlight: highlight)
    }

    /// The subtitle, with every part that matches the query fragment in the highlight color.
    ///
    /// The defaults read in both light and dark appearance. Matches can overlap, and a match that
    /// doesn't fit the subtitle is left uncolored.
    ///
    /// - Parameters:
    ///   - foreground: The color for text that doesn't match.
    ///   - highlight: The color for text that matches.
    func highlightedSubTitle(foreground: Color = .secondary, highlight: Color = .primary) -> AttributedString {
        Self.highlightedText(subTitle, highlights: subtitleHighlights, foreground: foreground, highlight: highlight)
    }
}

private extension LocalSearchCompletion {
    static func highlightedText(
        _ text: String,
        highlights: [Range<String.Index>],
        foreground: Color,
        highlight: Color,
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.swiftUI.foregroundColor = foreground
        for range in highlights {
            guard let attributedRange = attributedRange(of: range, in: text, attributed: attributed) else {
                continue
            }
            attributed[attributedRange].swiftUI.foregroundColor = highlight
        }
        return attributed
    }

    /// `range` in `attributed`, or `nil` when `range` doesn't fit `text`.
    ///
    /// A range built against other text can fall outside this text or split one of its Unicode
    /// scalars; either way it is dropped rather than trapping.
    static func attributedRange(
        of range: Range<String.Index>,
        in text: String,
        attributed: AttributedString,
    ) -> Range<AttributedString.Index>? {
        guard range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex,
              let lower = range.lowerBound.samePosition(in: text.unicodeScalars),
              let upper = range.upperBound.samePosition(in: text.unicodeScalars)
        else {
            return nil
        }
        return Range(lower ..< upper, in: attributed)
    }
}
