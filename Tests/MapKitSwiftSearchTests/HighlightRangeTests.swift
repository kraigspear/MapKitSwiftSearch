import Foundation
@testable import MapKitSwiftSearch
import Testing

struct HighlightRangeTests {
    @Test("Verify highlightedSubTitle uses correct highlight range")
    func verifyHighlightedSubTitleUsesCorrectRange() throws {
        // This test verifies that the highlightedSubTitle method uses subtitleHighlightRange
        // rather than titleHighlightRange, which was a bug found during code review
        let iosFilePath = "/Users/kraigspear/Projects/MapKitSwiftSearch/Sources/MapKitSwiftSearch/PlatformSpecific/LocalSearchCompletion+iOS.swift"
        let macOSFilePath = "/Users/kraigspear/Projects/MapKitSwiftSearch/Sources/MapKitSwiftSearch/PlatformSpecific/LocalSearchCompletion+macOS.swift"

        // Read iOS implementation
        if let iosContent = try? String(contentsOfFile: iosFilePath, encoding: .utf8) {
            let lines = iosContent.components(separatedBy: .newlines)

            // Check line 27 (0-indexed, so line 26)
            if lines.count > 26 {
                let line27 = lines[26]
                let isFixed = line27.contains("subtitleHighlightRange")

                #expect(isFixed, "iOS implementation at line 27 should be fixed (using subtitleHighlightRange)")

                // Also check the method context (line 22-30)
                if lines.count > 29 {
                    let methodLines = lines[21 ... 29].joined(separator: "\n")
                    let isInHighlightedSubTitle = methodLines.contains("func highlightedSubTitle")
                    let usesCorrectRange = methodLines.contains("highlightRange: subtitleHighlightRange")

                    #expect(isInHighlightedSubTitle && usesCorrectRange,
                            "iOS highlightedSubTitle method should be using correct range (bug fixed)")
                }
            }
        }

        // Read macOS implementation
        if let macOSContent = try? String(contentsOfFile: macOSFilePath, encoding: .utf8) {
            let lines = macOSContent.components(separatedBy: .newlines)

            // Check line 27 (0-indexed, so line 26)
            if lines.count > 26 {
                let line27 = lines[26]
                let isFixed = line27.contains("subtitleHighlightRange")

                #expect(isFixed, "macOS implementation at line 27 should be fixed (using subtitleHighlightRange)")

                // Also check the method context
                if lines.count > 29 {
                    let methodLines = lines[21 ... 29].joined(separator: "\n")
                    let isInHighlightedSubTitle = methodLines.contains("func highlightedSubTitle")
                    let usesCorrectRange = methodLines.contains("highlightRange: subtitleHighlightRange")

                    #expect(isInHighlightedSubTitle && usesCorrectRange,
                            "macOS highlightedSubTitle method should be using correct range (bug fixed)")
                }
            }
        }
    }
}
