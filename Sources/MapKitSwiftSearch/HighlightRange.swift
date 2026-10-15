import Foundation

/// A range of matched text in a search completion's title or subtitle.
///
/// MapKit reports ranges as UTF-16 offsets. ``toAttributedStringRange(in:)`` converts one to an
/// `AttributedString` range, so callers never index a Swift string with those offsets.
///
/// ```swift
/// var title = AttributedString(completion.title)
/// if let range = completion.titleHighlightRange?.toAttributedStringRange(in: title) {
///     title[range].inlinePresentationIntent = .stronglyEmphasized
/// }
/// ```
public struct HighlightRange: Equatable, Sendable, Hashable {
    private let location: Int
    private let length: Int

    // MARK: - Initialization

    /// Creates a highlight range from an `NSRange`.
    public init(nsRange: NSRange) {
        location = nsRange.location
        length = nsRange.length
    }

    /// Creates a highlight range from the `NSValue` MapKit wraps each range in.
    init(nsValue: NSValue) {
        var nsRange = NSRange()
        nsValue.getValue(&nsRange)
        self.init(nsRange: nsRange)
    }

    // MARK: - Private Helpers

    private var asNSRange: NSRange {
        NSRange(location: location, length: length)
    }

    // MARK: - Public Methods

    /// The matching range in an attributed string, or `nil` if this range falls outside it.
    ///
    /// - Parameter attributedString: The text MapKit reported this range against.
    public func toAttributedStringRange(in attributedString: AttributedString) -> Range<AttributedString.Index>? {
        guard let stringRange = Range(asNSRange, in: attributedString) else {
            return nil
        }
        return stringRange
    }
}
