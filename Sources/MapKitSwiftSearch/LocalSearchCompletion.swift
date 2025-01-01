//
//  LocalSearchCompletion.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/26/24.
//

import MapKit

/**
 A sendable version of ``MKLocalSearchCompletion`` with the added capability of providing a
 AttributedString for title / subtitle
 */
public struct LocalSearchCompletion: Identifiable, Equatable, Sendable, Hashable, CustomStringConvertible {
    public let id: String
    public let title: String
    public let subTitle: String
    public let titleHighlightRange: HighlightRange?
    public let subtitleHighlightRange: HighlightRange?

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

    public var description: String {
        "LocalSearchCompletion(\(title), \(subTitle))"
    }
}
