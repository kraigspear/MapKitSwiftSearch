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

@MainActor
struct LocalSearchCompletionTests {
    @Test("LocalSearchCompletion id uses title and subtitle")
    func localSearchCompletionIdUsesTitleAndSubtitle() throws {
        let completion = LocalSearchCompletion(
            title: "Cafe",
            subTitle: "123 Main Street",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        #expect(completion.id == "Cafe-123 Main Street")
    }

    @Test("LocalSearchCompletion equality includes highlight ranges")
    func localSearchCompletionEqualityIncludesHighlightRanges() throws {
        let titleRange = HighlightRange(nsRange: NSRange(location: 0, length: 2))
        let subtitleRange = HighlightRange(nsRange: NSRange(location: 4, length: 3))

        let first = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: titleRange,
            subtitleHighlightRange: subtitleRange,
        )
        let second = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: titleRange,
            subtitleHighlightRange: subtitleRange,
        )
        let third = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: nil,
            subtitleHighlightRange: subtitleRange,
        )

        #expect(first == second)
        #expect(first != third)

        let set = Set([first, second, third])
        #expect(set.count == 2)
    }

    @Test("highlightedTitle uses base color when no highlight range")
    func highlightedTitleUsesBaseColorWhenNoHighlightRange() throws {
        #if os(iOS) || os(macOS)
        let completion = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        let foregroundColor = PlatformColor.red
        let highlightColor = PlatformColor.blue
        let attributedTitle = completion.highlightedTitle(
            foregroundColor: foregroundColor,
            highlightColor: highlightColor,
        )
        let nsAttributed = NSAttributedString(attributedTitle)

        var effectiveRange = NSRange()
        let color = nsAttributed.attribute(.foregroundColor, at: 0, effectiveRange: &effectiveRange) as? PlatformColor

        #expect(color?.isEqual(foregroundColor) == true)
        #expect(effectiveRange.location == 0 && effectiveRange.length == nsAttributed.length)
        #endif
    }

    @Test("highlightedSubTitle uses base color when no highlight range")
    func highlightedSubTitleUsesBaseColorWhenNoHighlightRange() throws {
        #if os(iOS) || os(macOS)
        let completion = LocalSearchCompletion(
            title: "Coffee",
            subTitle: "Roasters",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        let foregroundColor = PlatformColor.red
        let highlightColor = PlatformColor.blue
        let attributedSubtitle = completion.highlightedSubTitle(
            foregroundColor: foregroundColor,
            highlightColor: highlightColor,
        )
        let nsAttributed = NSAttributedString(attributedSubtitle)

        var effectiveRange = NSRange()
        let color = nsAttributed.attribute(.foregroundColor, at: 0, effectiveRange: &effectiveRange) as? PlatformColor

        #expect(color?.isEqual(foregroundColor) == true)
        #expect(effectiveRange.location == 0 && effectiveRange.length == nsAttributed.length)
        #endif
    }
}
