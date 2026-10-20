import Foundation
import MapKit
import SwiftUI
import Testing
@testable import MapKitSwiftSearch

@MainActor
struct LocalSearchCompletionTests {
    // MARK: - Identity and equality

    @Test
    func `LocalSearchCompletion id uses title and subtitle`() {
        let completion = LocalSearchCompletion(title: "Cafe", subTitle: "123 Main Street")

        #expect(completion.id == "Cafe-123 Main Street")
    }

    @Test
    func `LocalSearchCompletion equality includes highlights`() throws {
        let title = "Coffee"
        let subTitle = "Roasters"
        let titleHighlight = try #require(title.range(of: "Co"))
        let subtitleHighlight = try #require(subTitle.range(of: "ter"))

        let first = LocalSearchCompletion(
            title: title,
            subTitle: subTitle,
            titleHighlights: [titleHighlight],
            subtitleHighlights: [subtitleHighlight],
        )
        let second = LocalSearchCompletion(
            title: title,
            subTitle: subTitle,
            titleHighlights: [titleHighlight],
            subtitleHighlights: [subtitleHighlight],
        )
        let differentTitleHighlights = LocalSearchCompletion(
            title: title,
            subTitle: subTitle,
            subtitleHighlights: [subtitleHighlight],
        )
        let differentSubtitleHighlights = LocalSearchCompletion(
            title: title,
            subTitle: subTitle,
            titleHighlights: [titleHighlight],
        )

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(first != differentTitleHighlights)
        #expect(first != differentSubtitleHighlights)
        #expect(first.id == differentTitleHighlights.id)

        let set = Set([first, second, differentTitleHighlights, differentSubtitleHighlights])
        #expect(set.count == 3)
    }

    // MARK: - MapKit completion

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
    func `A completion with a MapKit completion equals one built from the same fields without one`() throws {
        let title = "Mains Treat Coffeehouse"
        let fromMapKit = LocalSearchCompletion(
            StubMapKitCompletion(
                title: title,
                subtitle: "123 Main Street",
                titleHighlights: [NSRange(location: 12, length: 6)],
            ),
        )
        let fromFields = try LocalSearchCompletion(
            title: title,
            subTitle: "123 Main Street",
            titleHighlights: [#require(title.range(of: "Coffee"))],
        )

        #expect(fromMapKit == fromFields)
        #expect(fromMapKit.hashValue == fromFields.hashValue)
    }

    @Test
    func `A completion built from its fields has no MapKit completion`() {
        let completion = LocalSearchCompletion(title: "Cafe", subTitle: "123 Main Street")

        #expect(completion.mapKitCompletion == nil)
    }

    // MARK: - Highlighting

    @Test
    func `Every title highlight is colored, whatever order MapKit reports them in`() {
        let completion = LocalSearchCompletion(
            StubMapKitCompletion(
                title: "Mains Treat Coffeehouse",
                subtitle: "",
                titleHighlights: [NSRange(location: 12, length: 6), NSRange(location: 0, length: 4)],
            ),
        )

        let runs = colorRuns(completion.highlightedTitle(foreground: .red, highlight: .blue))

        #expect(runs == [
            ColorRun(text: "Main", color: .blue),
            ColorRun(text: "s Treat ", color: .red),
            ColorRun(text: "Coffee", color: .blue),
            ColorRun(text: "house", color: .red),
        ])
    }

    @Test
    func `Overlapping highlights color their union`() {
        let completion = LocalSearchCompletion(
            StubMapKitCompletion(
                title: "Sheridan, IN",
                subtitle: "",
                titleHighlights: [
                    NSRange(location: 0, length: 8),
                    NSRange(location: 10, length: 2),
                    NSRange(location: 0, length: 12),
                ],
            ),
        )

        let runs = colorRuns(completion.highlightedTitle(foreground: .red, highlight: .blue))

        #expect(runs == [ColorRun(text: "Sheridan, IN", color: .blue)])
    }

    @Test
    func `Every subtitle highlight is colored`() {
        let completion = LocalSearchCompletion(
            StubMapKitCompletion(
                title: "Coffee",
                subtitle: "123 Main Street, Grand Rapids",
                subtitleHighlights: [NSRange(location: 17, length: 5), NSRange(location: 4, length: 4)],
            ),
        )

        let runs = colorRuns(completion.highlightedSubTitle(foreground: .red, highlight: .blue))

        #expect(runs == [
            ColorRun(text: "123 ", color: .red),
            ColorRun(text: "Main", color: .blue),
            ColorRun(text: " Street, ", color: .red),
            ColorRun(text: "Grand", color: .blue),
            ColorRun(text: " Rapids", color: .red),
        ])
    }

    @Test
    func `A highlight past the end of the text is dropped and the rest still color`() {
        let completion = LocalSearchCompletion(
            StubMapKitCompletion(
                title: "Coffee shop",
                subtitle: "",
                titleHighlights: [
                    NSRange(location: 7, length: 99),
                    NSRange(location: 0, length: 6),
                    NSRange(location: NSNotFound, length: 0),
                ],
            ),
        )

        let runs = colorRuns(completion.highlightedTitle(foreground: .red, highlight: .blue))

        #expect(runs == [
            ColorRun(text: "Coffee", color: .blue),
            ColorRun(text: " shop", color: .red),
        ])
    }

    @Test(arguments: [
        ("Zürich", NSRange(location: 1, length: 3), "üri"),
        ("São Paulo", NSRange(location: 4, length: 5), "Paulo"),
        ("Café 🙂 Bar", NSRange(location: 8, length: 3), "Bar"),
    ])
    func `Non-ASCII text converts from UTF-16 offsets`(title: String, highlight: NSRange, expected: String) {
        let completion = LocalSearchCompletion(
            StubMapKitCompletion(title: title, subtitle: "", titleHighlights: [highlight]),
        )

        let runs = colorRuns(completion.highlightedTitle(foreground: .red, highlight: .blue))

        #expect(runs.filter { $0.color == .blue }.map(\.text) == [expected])
    }

    @Test
    func `Highlights in bridged NSString text, as MapKit returns it, color and compare like native text`() throws {
        // MapKit's strings are lazily bridged NSStrings, which Swift indexes in UTF-16.
        let text = "Café 🙂 São Paulo"
        let utf16 = Array(text.utf16)
        let bridged = NSString(characters: utf16, length: utf16.count) as String
        try #require(bridged.utf8.withContiguousStorageIfAvailable { _ in true } == nil)

        let fromMapKit = LocalSearchCompletion(
            StubMapKitCompletion(
                title: bridged,
                subtitle: bridged,
                titleHighlights: [NSRange(location: 8, length: 3), NSRange(location: 0, length: 4)],
                subtitleHighlights: [NSRange(location: 12, length: 5)],
            ),
        )
        let fromFields = try LocalSearchCompletion(
            title: text,
            subTitle: text,
            titleHighlights: [#require(text.range(of: "São")), #require(text.range(of: "Café"))],
            subtitleHighlights: [#require(text.range(of: "Paulo"))],
        )

        #expect(colorRuns(fromMapKit.highlightedTitle(foreground: .red, highlight: .blue)) == [
            ColorRun(text: "Café", color: .blue),
            ColorRun(text: " 🙂 ", color: .red),
            ColorRun(text: "São", color: .blue),
            ColorRun(text: " Paulo", color: .red),
        ])
        #expect(fromMapKit == fromFields)
        #expect(fromMapKit.hashValue == fromFields.hashValue)
    }

    @Test
    func `A highlight that splits a UTF-16 surrogate pair is dropped`() {
        let completion = LocalSearchCompletion(
            StubMapKitCompletion(
                title: "A🙂B",
                subtitle: "",
                titleHighlights: [NSRange(location: 2, length: 1), NSRange(location: 3, length: 1)],
            ),
        )

        let runs = colorRuns(completion.highlightedTitle(foreground: .red, highlight: .blue))

        #expect(runs == [
            ColorRun(text: "A🙂", color: .red),
            ColorRun(text: "B", color: .blue),
        ])
    }

    @Test
    func `With no highlights the whole text takes the foreground color`() {
        let completion = LocalSearchCompletion(title: "Coffee", subTitle: "Roasters")

        #expect(colorRuns(completion.highlightedTitle(foreground: .red, highlight: .blue))
            == [ColorRun(text: "Coffee", color: .red)])
        #expect(colorRuns(completion.highlightedSubTitle(foreground: .red, highlight: .blue))
            == [ColorRun(text: "Roasters", color: .red)])
    }

    @Test
    func `The default colors are secondary with a primary highlight`() {
        let completion = LocalSearchCompletion(
            StubMapKitCompletion(
                title: "Coffee shop",
                subtitle: "Grand Rapids",
                titleHighlights: [NSRange(location: 0, length: 6)],
                subtitleHighlights: [NSRange(location: 6, length: 6)],
            ),
        )

        #expect(colorRuns(completion.highlightedTitle()) == [
            ColorRun(text: "Coffee", color: .primary),
            ColorRun(text: " shop", color: .secondary),
        ])
        #expect(colorRuns(completion.highlightedSubTitle()) == [
            ColorRun(text: "Grand ", color: .secondary),
            ColorRun(text: "Rapids", color: .primary),
        ])
    }

    @Test
    func `Highlights given as string ranges color the same runs as the equivalent MapKit ranges`() throws {
        let title = "Mains Treat Coffeehouse"
        let subTitle = "Zürich, Switzerland"
        let fromMapKit = LocalSearchCompletion(
            StubMapKitCompletion(
                title: title,
                subtitle: subTitle,
                titleHighlights: [NSRange(location: 12, length: 6), NSRange(location: 0, length: 4)],
                subtitleHighlights: [NSRange(location: 0, length: 6)],
            ),
        )
        let fromFields = try LocalSearchCompletion(
            title: title,
            subTitle: subTitle,
            titleHighlights: [#require(title.range(of: "Coffee")), #require(title.range(of: "Main"))],
            subtitleHighlights: [#require(subTitle.range(of: "Zürich"))],
        )

        #expect(fromFields.highlightedTitle() == fromMapKit.highlightedTitle())
        #expect(fromFields.highlightedSubTitle() == fromMapKit.highlightedSubTitle())
        #expect(colorRuns(fromFields.highlightedTitle()).filter { $0.color == .primary }.map(\.text)
            == ["Main", "Coffee"])
    }

    @Test
    func `A string range from other text is dropped when it does not fit`() throws {
        let otherText = "Mains Treat Coffeehouse"
        let completion = try LocalSearchCompletion(
            title: "Coffee",
            subTitle: "",
            titleHighlights: [#require(otherText.range(of: "house")), #require("Coffee".range(of: "Cof"))],
        )

        let runs = colorRuns(completion.highlightedTitle(foreground: .red, highlight: .blue))

        #expect(runs == [
            ColorRun(text: "Cof", color: .blue),
            ColorRun(text: "fee", color: .red),
        ])
    }
}

// MARK: - Helpers

/// A stretch of text and the SwiftUI foreground color it renders in.
private struct ColorRun: Equatable, CustomStringConvertible {
    let text: String
    let color: Color?

    var description: String {
        "\(text): \(color.map(String.init(describing:)) ?? "nil")"
    }
}

/// The text split into runs of one foreground color, in text order.
private func colorRuns(_ text: AttributedString) -> [ColorRun] {
    text.runs[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self].map { color, range in
        ColorRun(text: String(text[range].characters), color: color)
    }
}
