import MapKit

/// A MapKit completion with fixed text, so tests can build one without running the completer.
final class StubMapKitCompletion: MKLocalSearchCompletion {
    private let stubTitle: String
    private let stubSubtitle: String

    init(title: String, subtitle: String) {
        stubTitle = title
        stubSubtitle = subtitle
        super.init()
    }

    override var title: String {
        stubTitle
    }

    override var subtitle: String {
        stubSubtitle
    }

    override var titleHighlightRanges: [NSValue] {
        []
    }

    override var subtitleHighlightRanges: [NSValue] {
        []
    }
}
