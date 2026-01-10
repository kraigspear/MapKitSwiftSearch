import Foundation
import Testing
@testable import MapKitSwiftSearch

#if os(iOS)
import UIKit

private typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit

private typealias PlatformColor = NSColor
#endif

struct HighlightRangeTests {
    @Test("HighlightRange converts valid ranges")
    func highlightRangeConvertsValidRange() throws {
        let text = AttributedString("Coffee shops")
        let range = HighlightRange(nsRange: NSRange(location: 0, length: 6))

        let attributedRange = try #require(range.toAttributedStringRange(in: text))
        let substring = String(text[attributedRange].characters)
        #expect(substring == "Coffee")
    }

    @Test("HighlightRange returns nil for out-of-bounds ranges")
    func highlightRangeOutOfBoundsReturnsNil() throws {
        let text = AttributedString("Coffee")
        let range = HighlightRange(nsRange: NSRange(location: 0, length: 99))

        #expect(range.toAttributedStringRange(in: text) == nil)
    }

    @Test("HighlightRange handles extended grapheme clusters")
    func highlightRangeHandlesGraphemeClusters() throws {
        let text = AttributedString("A🙂B")
        let range = HighlightRange(nsRange: NSRange(location: 1, length: 2))

        let attributedRange = try #require(range.toAttributedStringRange(in: text))
        let substring = String(text[attributedRange].characters)
        #expect(substring == "🙂")
    }

    @Test("HighlightRange allows zero-length range at end")
    func highlightRangeAllowsZeroLengthAtEnd() throws {
        let text = AttributedString("Coffee")
        let range = HighlightRange(nsRange: NSRange(location: text.characters.count, length: 0))

        let attributedRange = try #require(range.toAttributedStringRange(in: text))
        #expect(attributedRange.isEmpty)
    }

    @Test("Verify highlightedSubTitle uses correct highlight range")
    func verifyHighlightedSubTitleUsesCorrectRange() throws {
        #if os(iOS) || os(macOS)
        let title = "Pizza Place"
        let subTitle = "123 Main Street"
        let titleRange = NSRange(location: 0, length: 3)
        let subtitleRange = NSRange(location: 4, length: 4)

        let completion = LocalSearchCompletion(
            title: title,
            subTitle: subTitle,
            titleHighlightRange: HighlightRange(nsRange: titleRange),
            subtitleHighlightRange: HighlightRange(nsRange: subtitleRange),
        )

        let foregroundColor = PlatformColor.red
        let highlightColor = PlatformColor.blue
        let attributedSubtitle = completion.highlightedSubTitle(
            foregroundColor: foregroundColor,
            highlightColor: highlightColor,
        )
        let nsAttributed = NSAttributedString(attributedSubtitle)
        let subtitleStart = subtitleRange.location

        var baseRange = NSRange()
        _ = nsAttributed.attribute(.foregroundColor, at: 0, effectiveRange: &baseRange)
        #expect(
            baseRange.location == 0 && baseRange.length == subtitleStart,
            "Expected base color range to stop at subtitleHighlightRange",
        )

        var highlightRange = NSRange()
        _ = nsAttributed.attribute(.foregroundColor, at: subtitleStart, effectiveRange: &highlightRange)
        #expect(
            highlightRange.location == subtitleStart && highlightRange.length == subtitleRange.length,
            "Expected highlight range to match subtitleHighlightRange",
        )
        #endif
    }
}
