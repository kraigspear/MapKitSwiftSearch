// Deliberately not `@testable`: a consumer's previews and test doubles see only the public interface.
import MapKit
import MapKitSwiftSearch
import SwiftUI
import Testing

@MainActor
struct LocalSearchCompletionPublicInitTests {
    @Test
    func `A completion built without highlights has its title, subtitle, and id, and nothing highlighted`() {
        let completion = LocalSearchCompletion(title: "Cafe", subTitle: "123 Main Street")

        #expect(completion.title == "Cafe")
        #expect(completion.subTitle == "123 Main Street")
        #expect(completion.id == "Cafe-123 Main Street")
        #expect(highlightedText(in: completion.highlightedTitle()) == [])
        #expect(highlightedText(in: completion.highlightedSubTitle()) == [])
    }

    @Test
    func `A completion built with highlights colors exactly those parts`() throws {
        let title = "Coffee Roasters"
        let subTitle = "Grand Rapids, MI"
        let completion = try LocalSearchCompletion(
            title: title,
            subTitle: subTitle,
            titleHighlights: [#require(title.range(of: "Coffee")), #require(title.range(of: "Roast"))],
            subtitleHighlights: [#require(subTitle.range(of: "Rapids"))],
        )

        #expect(completion.title == title)
        #expect(completion.subTitle == subTitle)
        #expect(completion.id == "Coffee Roasters-Grand Rapids, MI")
        #expect(highlightedText(in: completion.highlightedTitle()) == ["Coffee", "Roast"])
        #expect(highlightedText(in: completion.highlightedSubTitle()) == ["Rapids"])
    }

    @Test
    func `placemark(for:) throws placemarkNotFound for a completion built from its fields`() async {
        let locationSearch = LocationSearch()
        let completion = LocalSearchCompletion(title: "Cafe", subTitle: "123 Main Street")

        await #expect {
            try await locationSearch.placemark(for: completion)
        } throws: { error in
            guard case let .mapKitError(mkError) = error as? LocationSearchError else { return false }
            return mkError.code == .placemarkNotFound
        }
    }

    /// The runs of `text` in the highlight color, `.primary` by default.
    private func highlightedText(in text: AttributedString) -> [String] {
        text.runs
            .filter { $0.swiftUI.foregroundColor == .primary }
            .map { String(text[$0.range].characters) }
    }
}
