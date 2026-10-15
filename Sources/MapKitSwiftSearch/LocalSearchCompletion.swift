import MapKit

/// A `Sendable` snapshot of one MapKit search completion.
///
/// ```swift
/// Text(completion.highlightedTitle())
/// Text(completion.highlightedSubTitle())
/// ```
public struct LocalSearchCompletion: Identifiable, Equatable, Sendable, Hashable, CustomStringConvertible {
    /// The title and subtitle joined; completions with the same text share an `id`.
    public let id: String

    /// The primary text, such as a place name.
    public let title: String

    /// The secondary text, such as an address or region.
    public let subTitle: String

    /// The first range in ``title`` that MapKit matched to the query, if any.
    ///
    /// MapKit matches each word of a multi-word query separately; this keeps only its first match.
    public let titleHighlightRange: HighlightRange?

    /// The first range in ``subTitle`` that MapKit matched to the query, if any.
    public let subtitleHighlightRange: HighlightRange?

    // MARK: - Initialization

    /// Snapshots a MapKit completion, keeping the first highlight range per field (Docs/adr/0003).
    init(_ searchCompletion: MKLocalSearchCompletion) {
        title = searchCompletion.title
        subTitle = searchCompletion.subtitle
        id = "\(title)-\(subTitle)"

        titleHighlightRange = searchCompletion.titleHighlightRanges.first.map {
            HighlightRange(nsValue: $0)
        }

        subtitleHighlightRange = searchCompletion.subtitleHighlightRanges.first.map {
            HighlightRange(nsValue: $0)
        }
    }

    init(
        title: String,
        subTitle: String,
        titleHighlightRange: HighlightRange?,
        subtitleHighlightRange: HighlightRange?,
    ) {
        self.title = title
        self.subTitle = subTitle
        id = "\(title)-\(subTitle)"
        self.titleHighlightRange = titleHighlightRange
        self.subtitleHighlightRange = subtitleHighlightRange
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        "LocalSearchCompletion(\(title), \(subTitle))"
    }
}
