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

    /// The MapKit completion this snapshot was taken from, so ``LocationSearch/placemark(for:)``
    /// resolves exactly what the user tapped (Docs/adr/0007).
    private let original: MapKitCompletionBox

    // MARK: - Initialization

    /// Snapshots a MapKit completion, keeping the first highlight range per field (Docs/adr/0003).
    init(_ searchCompletion: MKLocalSearchCompletion) {
        original = MapKitCompletionBox(completion: searchCompletion)
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

    /// Creates a completion with no MapKit completion behind it, which can't be resolved.
    init(
        title: String,
        subTitle: String,
        titleHighlightRange: HighlightRange?,
        subtitleHighlightRange: HighlightRange?,
    ) {
        original = MapKitCompletionBox(completion: nil)
        self.title = title
        self.subTitle = subTitle
        id = "\(title)-\(subTitle)"
        self.titleHighlightRange = titleHighlightRange
        self.subtitleHighlightRange = subtitleHighlightRange
    }

    // MARK: - MapKit Completion

    /// The MapKit completion to resolve, or `nil` for a completion built from its fields.
    ///
    /// Opened only on the main actor, which is what makes the box's `@unchecked Sendable` safe.
    @MainActor
    var mapKitCompletion: MKLocalSearchCompletion? {
        original.completion
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        "LocalSearchCompletion(\(title), \(subTitle))"
    }
}

/// Carries a MapKit completion inside the `Sendable` snapshot.
///
/// `MKLocalSearchCompletion` isn't `Sendable` in the macOS 27 SDK. Sharing it is safe because
/// MapKit never mutates a completion after delivering it, and ``LocalSearchCompletion/mapKitCompletion``
/// reads it only on the main actor.
///
/// Every box is equal to every other and adds nothing to a hash, which leaves the MapKit completion
/// out of `LocalSearchCompletion`'s synthesized `==` and `hash(into:)`: two snapshots with the same
/// fields are the same completion to a caller, whichever MapKit search produced them.
private final class MapKitCompletionBox: Hashable, @unchecked Sendable {
    let completion: MKLocalSearchCompletion?

    init(completion: MKLocalSearchCompletion?) {
        self.completion = completion
    }

    static func == (_: MapKitCompletionBox, _: MapKitCompletionBox) -> Bool {
        true
    }

    func hash(into _: inout Hasher) {}
}
