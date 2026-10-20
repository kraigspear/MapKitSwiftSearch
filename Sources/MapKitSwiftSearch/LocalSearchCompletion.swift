import MapKit

/// A `Sendable` snapshot of one MapKit search completion: its title, its subtitle, and every
/// highlight that matches the query fragment.
///
/// Two completions are equal when their title, subtitle, and highlights are.
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

    /// Every part of ``title`` that matches a word of the query fragment, in the order MapKit reported
    /// them. They can overlap.
    let titleHighlights: [Range<String.Index>]

    /// Every part of ``subTitle`` that matches a word of the query fragment, in the order MapKit
    /// reported them. They can overlap.
    let subtitleHighlights: [Range<String.Index>]

    /// The MapKit completion this snapshot was taken from, so ``LocationSearch/placemark(for:)``
    /// resolves exactly what the user tapped (Docs/adr/0007).
    private let original: MapKitCompletionBox

    // MARK: - Initialization

    /// Snapshots a MapKit completion, converting every highlight it reports (Docs/adr/0008).
    init(_ searchCompletion: MKLocalSearchCompletion) {
        let title = Self.nativeCopy(of: searchCompletion.title)
        let subTitle = Self.nativeCopy(of: searchCompletion.subtitle)
        self.init(
            title: title,
            subTitle: subTitle,
            titleHighlights: Self.highlights(searchCompletion.titleHighlightRanges, in: title),
            subtitleHighlights: Self.highlights(searchCompletion.subtitleHighlightRanges, in: subTitle),
            original: searchCompletion,
        )
    }

    /// Creates a completion with no MapKit completion behind it, which can't be resolved.
    ///
    /// A highlight that doesn't fit its text is ignored when the text is colored.
    init(
        title: String,
        subTitle: String,
        titleHighlights: [Range<String.Index>] = [],
        subtitleHighlights: [Range<String.Index>] = [],
    ) {
        self.init(
            title: title,
            subTitle: subTitle,
            titleHighlights: titleHighlights,
            subtitleHighlights: subtitleHighlights,
            original: nil,
        )
    }

    private init(
        title: String,
        subTitle: String,
        titleHighlights: [Range<String.Index>],
        subtitleHighlights: [Range<String.Index>],
        original: MKLocalSearchCompletion?,
    ) {
        self.original = MapKitCompletionBox(completion: original)
        self.title = title
        self.subTitle = subTitle
        id = "\(title)-\(subTitle)"
        self.titleHighlights = titleHighlights
        self.subtitleHighlights = subtitleHighlights
    }

    /// Converts MapKit's UTF-16 ranges to ranges of `text`, dropping any that don't fit it.
    private static func highlights(_ ranges: [NSValue], in text: String) -> [Range<String.Index>] {
        ranges.compactMap { Range($0.rangeValue, in: text) }
    }

    /// A copy of `text` in native UTF-8 storage.
    ///
    /// MapKit's strings are bridged `NSString`s, which Swift indexes in UTF-16. Indices into a native
    /// copy are UTF-8 offsets, like those of any Swift string, so a snapshot's highlights compare and
    /// hash the same as equal highlights built from a Swift string.
    private static func nativeCopy(of text: String) -> String {
        var native = text
        native.makeContiguousUTF8()
        return native
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
