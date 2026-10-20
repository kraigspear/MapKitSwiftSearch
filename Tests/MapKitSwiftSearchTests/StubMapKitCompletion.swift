import MapKit

/// A MapKit completion with fixed text and highlights, so tests can build one without running the completer.
final class StubMapKitCompletion: MKLocalSearchCompletion {
    private let stubTitle: String
    private let stubSubtitle: String
    private let stubTitleHighlightRanges: [NSValue]
    private let stubSubtitleHighlightRanges: [NSValue]

    /// - Parameters:
    ///   - titleHighlights: Highlights in `title`, as the UTF-16 ranges MapKit reports.
    ///   - subtitleHighlights: Highlights in `subtitle`, as the UTF-16 ranges MapKit reports.
    init(
        title: String,
        subtitle: String,
        titleHighlights: [NSRange] = [],
        subtitleHighlights: [NSRange] = [],
    ) {
        stubTitle = title
        stubSubtitle = subtitle
        stubTitleHighlightRanges = titleHighlights.map { NSValue(range: $0) }
        stubSubtitleHighlightRanges = subtitleHighlights.map { NSValue(range: $0) }
        super.init()
    }

    override var title: String {
        stubTitle
    }

    override var subtitle: String {
        stubSubtitle
    }

    override var titleHighlightRanges: [NSValue] {
        stubTitleHighlightRanges
    }

    override var subtitleHighlightRanges: [NSValue] {
        stubSubtitleHighlightRanges
    }
}
