//
//  LocalSearchCompletion+macOS.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/27/24.
//

#if os(macOS)
    import AppKit

    public extension LocalSearchCompletion {
        func highlightedTitle(
            foregroundColor: NSColor = .lightGray,
            highlightColor: NSColor = .white
        ) -> AttributedString {
            highlightedText(from: title,
                            highlightRange: titleHighlightRange,
                            foregroundColor: foregroundColor,
                            highlightColor: highlightColor)
        }

        func highlightedSubTitle(
            foregroundColor: NSColor = .lightGray,
            highlightColor: NSColor = .white
        ) -> AttributedString {
            highlightedText(from: subTitle,
                            highlightRange: titleHighlightRange,
                            foregroundColor: foregroundColor,
                            highlightColor: highlightColor)
        }

        private func highlightedText(
            from text: String,
            highlightRange: HighlightRange?,
            foregroundColor: NSColor,
            highlightColor: NSColor
        ) -> AttributedString {
            // Set initial foreground color
            var attributedString = AttributedString(text)
            attributedString.foregroundColor = foregroundColor

            // Set highlight
            if let highlightRange {
                if let attributedStringRange = highlightRange.toAttributedStringRange(in: attributedString) {
                    attributedString[attributedStringRange].foregroundColor = highlightColor
                }
            }

            return attributedString
        }
    }
#endif
