//
//  LocalSearchCompletion+iOS.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/27/24.
//

#if os(iOS)
import UIKit
public extension LocalSearchCompletion {
    func highlightedTitle(
        foregroundColor: UIColor = .lightGray,
        highlightColor: UIColor = .white
    ) -> AttributedString {
        highlightedText(from: title,
                        highlightRange: titleHighlightRange,
                        foregroundColor: foregroundColor,
                        highlightColor: highlightColor
        )
    }
    
    private func highlightedText(
        from text: String,
        highlightRange: HighlightRange?,
        foregroundColor: UIColor,
        highlightColor: UIColor
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
