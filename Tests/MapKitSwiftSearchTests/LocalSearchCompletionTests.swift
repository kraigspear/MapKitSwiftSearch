import Foundation
import MapKit
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
    @Test
    func `LocalSearchCompletion id uses title and subtitle`() {
        let completion = LocalSearchCompletion(
            title: "Cafe",
            subTitle: "123 Main Street",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        #expect(completion.id == "Cafe-123 Main Street")
    }

    @Test
    func `LocalSearchCompletion equality includes highlight ranges`() {
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

    @Test
    func `A completion snapshot keeps the MapKit completion it was taken from`() {
        let original = StubMapKitCompletion(title: "Pizza Restaurants", subtitle: "Search Nearby")

        let completion = LocalSearchCompletion(original)

        #expect(completion.mapKitCompletion === original)
        #expect(completion.title == "Pizza Restaurants")
        #expect(completion.subTitle == "Search Nearby")
    }

    @Test
    func `Completions with the same fields but different MapKit completions are equal and hash the same`() {
        let first = LocalSearchCompletion(StubMapKitCompletion(title: "Cafe", subtitle: "123 Main Street"))
        let second = LocalSearchCompletion(StubMapKitCompletion(title: "Cafe", subtitle: "123 Main Street"))

        #expect(first.mapKitCompletion !== second.mapKitCompletion)
        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(first.id == second.id)
    }

    @Test
    func `A completion with a MapKit completion equals one built from the same fields without one`() {
        let fromMapKit = LocalSearchCompletion(StubMapKitCompletion(title: "Cafe", subtitle: "123 Main Street"))
        let fromFields = LocalSearchCompletion(
            title: "Cafe",
            subTitle: "123 Main Street",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        #expect(fromMapKit == fromFields)
        #expect(fromMapKit.hashValue == fromFields.hashValue)
    }

    @Test
    func `A completion built from its fields has no MapKit completion`() {
        let completion = LocalSearchCompletion(
            title: "Cafe",
            subTitle: "123 Main Street",
            titleHighlightRange: nil,
            subtitleHighlightRange: nil,
        )

        #expect(completion.mapKitCompletion == nil)
    }

    @Test
    func `highlightedTitle uses base color when no highlight range`() {
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

    @Test
    func `highlightedSubTitle uses base color when no highlight range`() {
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
