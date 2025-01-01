//
//  HighlightRange.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/26/24.
//

import Foundation

public struct HighlightRange: Equatable, Sendable, Hashable {
    let location: Int
    let length: Int

    init(nsRange: NSRange) {
        location = nsRange.location
        length = nsRange.length
    }

    init(nsValue: NSValue) {
        var nsRange = NSRange()
        nsValue.getValue(&nsRange)
        self.init(nsRange: nsRange)
    }

    private var asNSRange: NSRange {
        NSRange(location: location, length: length)
    }

    func toAttributedStringRange(in attributedString: AttributedString) -> Range<AttributedString.Index>? {
        guard let stringRange = Range(asNSRange, in: attributedString) else {
            return nil
        }
        return stringRange
    }
}
