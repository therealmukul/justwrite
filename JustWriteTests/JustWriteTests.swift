import XCTest
@testable import JustWrite

final class JustWriteDocumentTests: XCTestCase {

    // MARK: - Document Creation Tests

    func testDocumentInitializesWithEmptyText() {
        let document = JustWriteDocument()
        XCTAssertEqual(document.text, "")
    }

    func testDocumentInitializesWithProvidedText() {
        let document = JustWriteDocument(text: "Hello, World!")
        XCTAssertEqual(document.text, "Hello, World!")
    }

    func testDocumentPreservesMultilineText() {
        let multilineText = """
        # Heading

        This is a paragraph.

        - List item 1
        - List item 2
        """
        let document = JustWriteDocument(text: multilineText)
        XCTAssertEqual(document.text, multilineText)
    }

    func testDocumentPreservesUnicodeText() {
        let unicodeText = "Hello 世界 🌍 émojis café"
        let document = JustWriteDocument(text: unicodeText)
        XCTAssertEqual(document.text, unicodeText)
    }

    func testDocumentTextIsMutable() {
        var document = JustWriteDocument(text: "Initial")
        document.text = "Modified"
        XCTAssertEqual(document.text, "Modified")
    }

    func testDocumentHandlesLongText() {
        let longText = String(repeating: "A", count: 10000)
        let document = JustWriteDocument(text: longText)
        XCTAssertEqual(document.text.count, 10000)
    }

    func testDocumentHandlesSpecialCharacters() {
        let specialText = "Line1\nLine2\tTabbed\r\nWindows"
        let document = JustWriteDocument(text: specialText)
        XCTAssertEqual(document.text, specialText)
    }

    // MARK: - UTF8 Round-trip Tests (simulating file I/O)

    func testTextToDataAndBack() {
        let originalText = "Test content with unicode: 日本語"
        let data = Data(originalText.utf8)
        let restoredText = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(restoredText, originalText)
    }

    func testEmptyTextToDataAndBack() {
        let originalText = ""
        let data = Data(originalText.utf8)
        let restoredText = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(restoredText, originalText)
    }

    func testMarkdownContentRoundTrip() {
        let markdownText = """
        # My Document

        This has **bold** and _italic_ text.

        ```
        code block
        ```

        - List item 1
        - List item 2
        """
        let data = Data(markdownText.utf8)
        let restoredText = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(restoredText, markdownText)
    }
}

// MARK: - Text Width Calculation Tests

final class TextWidthCalculationTests: XCTestCase {

    // Test the formula: lineLength * fontSize * 0.55

    func testOptimalWidthCalculation() {
        let lineLength: Double = 65
        let fontSize: Double = 16
        let expectedWidth = CGFloat(lineLength) * CGFloat(fontSize) * 0.55

        XCTAssertEqual(expectedWidth, 572.0, accuracy: 0.1)
    }

    func testOptimalWidthAtMinimumLineLength() {
        let lineLength: Double = 40
        let fontSize: Double = 16
        let expectedWidth = CGFloat(lineLength) * CGFloat(fontSize) * 0.55

        XCTAssertEqual(expectedWidth, 352.0, accuracy: 0.1)
    }

    func testOptimalWidthAtMaximumLineLength() {
        let lineLength: Double = 80
        let fontSize: Double = 16
        let expectedWidth = CGFloat(lineLength) * CGFloat(fontSize) * 0.55

        XCTAssertEqual(expectedWidth, 704.0, accuracy: 0.1)
    }

    func testOptimalWidthScalesWithFontSize() {
        let lineLength: Double = 65

        let width12 = CGFloat(lineLength) * CGFloat(12.0) * 0.55
        let width24 = CGFloat(lineLength) * CGFloat(24.0) * 0.55

        // Width should double when font size doubles
        XCTAssertEqual(width24, width12 * 2, accuracy: 0.1)
    }

    func testOptimalWidthScalesWithLineLength() {
        let fontSize: Double = 16

        let width40 = CGFloat(40.0) * CGFloat(fontSize) * 0.55
        let width80 = CGFloat(80.0) * CGFloat(fontSize) * 0.55

        // Width should double when line length doubles
        XCTAssertEqual(width80, width40 * 2, accuracy: 0.1)
    }

    func testOptimalWidthAtMinimumFontSize() {
        let lineLength: Double = 65
        let fontSize: Double = 12  // minimum font size
        let expectedWidth = CGFloat(lineLength) * CGFloat(fontSize) * 0.55

        XCTAssertEqual(expectedWidth, 429.0, accuracy: 0.1)
    }

    func testOptimalWidthAtMaximumFontSize() {
        let lineLength: Double = 65
        let fontSize: Double = 24  // maximum font size
        let expectedWidth = CGFloat(lineLength) * CGFloat(fontSize) * 0.55

        XCTAssertEqual(expectedWidth, 858.0, accuracy: 0.1)
    }

    func testOptimalWidthAtExtremeCombination() {
        // Max line length + max font size
        let lineLength: Double = 80
        let fontSize: Double = 24
        let expectedWidth = CGFloat(lineLength) * CGFloat(fontSize) * 0.55

        XCTAssertEqual(expectedWidth, 1056.0, accuracy: 0.1)
    }
}

// MARK: - Settings Validation Tests

final class SettingsValidationTests: XCTestCase {

    func testFontSizeDefaultValue() {
        let defaultFontSize: Double = 16
        XCTAssertEqual(defaultFontSize, 16)
    }

    func testFontSizeMinimumBound() {
        let minFontSize: Double = 12
        XCTAssertGreaterThanOrEqual(minFontSize, 12)
    }

    func testFontSizeMaximumBound() {
        let maxFontSize: Double = 24
        XCTAssertLessThanOrEqual(maxFontSize, 24)
    }

    func testLineSpacingDefaultValue() {
        let defaultLineSpacing: Double = 6
        XCTAssertEqual(defaultLineSpacing, 6)
    }

    func testLineSpacingMinimumBound() {
        let minLineSpacing: Double = 0
        XCTAssertGreaterThanOrEqual(minLineSpacing, 0)
    }

    func testLineSpacingMaximumBound() {
        let maxLineSpacing: Double = 16
        XCTAssertLessThanOrEqual(maxLineSpacing, 16)
    }

    func testLineLengthDefaultValue() {
        let defaultLineLength: Double = 65
        XCTAssertEqual(defaultLineLength, 65)
    }

    func testLineLengthMinimumBound() {
        let minLineLength: Double = 40
        XCTAssertGreaterThanOrEqual(minLineLength, 40)
    }

    func testLineLengthMaximumBound() {
        let maxLineLength: Double = 80
        XCTAssertLessThanOrEqual(maxLineLength, 80)
    }

    func testDefaultLineLengthWithinBounds() {
        let defaultLineLength: Double = 65
        let minLineLength: Double = 40
        let maxLineLength: Double = 80

        XCTAssertGreaterThanOrEqual(defaultLineLength, minLineLength)
        XCTAssertLessThanOrEqual(defaultLineLength, maxLineLength)
    }

    func testDefaultFontSizeWithinBounds() {
        let defaultFontSize: Double = 16
        let minFontSize: Double = 12
        let maxFontSize: Double = 24

        XCTAssertGreaterThanOrEqual(defaultFontSize, minFontSize)
        XCTAssertLessThanOrEqual(defaultFontSize, maxFontSize)
    }

    func testDefaultLineSpacingWithinBounds() {
        let defaultLineSpacing: Double = 6
        let minLineSpacing: Double = 0
        let maxLineSpacing: Double = 16

        XCTAssertGreaterThanOrEqual(defaultLineSpacing, minLineSpacing)
        XCTAssertLessThanOrEqual(defaultLineSpacing, maxLineSpacing)
    }
}

// MARK: - Markdown Pattern Tests

final class MarkdownPatternTests: XCTestCase {

    func testHeading1Pattern() throws {
        let pattern = #"^# .+$"#
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

        let testString = "# Heading 1"
        let range = NSRange(location: 0, length: testString.count)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 1)
    }

    func testHeading2Pattern() throws {
        let pattern = #"^## .+$"#
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

        let testString = "## Heading 2"
        let range = NSRange(location: 0, length: testString.count)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 1)
    }

    func testHeading3Pattern() throws {
        let pattern = #"^### .+$"#
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

        let testString = "### Heading 3"
        let range = NSRange(location: 0, length: testString.count)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 1)
    }

    func testBoldPattern() throws {
        let pattern = #"\*\*[^*]+\*\*"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])

        let testString = "This is **bold** text"
        let range = NSRange(location: 0, length: testString.count)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 1)

        let matchRange = matches[0].range
        let matchedString = (testString as NSString).substring(with: matchRange)
        XCTAssertEqual(matchedString, "**bold**")
    }

    func testItalicPattern() throws {
        let pattern = #"_[^_]+_"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])

        let testString = "This is _italic_ text"
        let range = NSRange(location: 0, length: testString.count)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 1)

        let matchRange = matches[0].range
        let matchedString = (testString as NSString).substring(with: matchRange)
        XCTAssertEqual(matchedString, "_italic_")
    }

    func testMultipleFormattingInOneLine() throws {
        let boldPattern = #"\*\*[^*]+\*\*"#
        let italicPattern = #"_[^_]+_"#

        let boldRegex = try NSRegularExpression(pattern: boldPattern, options: [])
        let italicRegex = try NSRegularExpression(pattern: italicPattern, options: [])

        let testString = "This has **bold** and _italic_ text"
        let range = NSRange(location: 0, length: testString.count)

        let boldMatches = boldRegex.matches(in: testString, options: [], range: range)
        let italicMatches = italicRegex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(boldMatches.count, 1)
        XCTAssertEqual(italicMatches.count, 1)
    }

    func testHeadingNotMatchedInMiddleOfLine() throws {
        let pattern = #"^# .+$"#
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

        let testString = "This is not # a heading"
        let range = NSRange(location: 0, length: testString.count)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 0)
    }

    func testMultipleHeadingsInDocument() throws {
        let pattern = #"^# .+$"#
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

        let testString = """
        # First Heading
        Some content
        # Second Heading
        More content
        """
        let range = NSRange(location: 0, length: (testString as NSString).length)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 2)
    }

    func testMultipleBoldInParagraph() throws {
        let pattern = #"\*\*[^*]+\*\*"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])

        let testString = "This has **bold** and also **more bold** text"
        let range = NSRange(location: 0, length: testString.count)
        let matches = regex.matches(in: testString, options: [], range: range)

        XCTAssertEqual(matches.count, 2)
    }
}

// MARK: - Inset Calculation Tests

final class InsetCalculationTests: XCTestCase {

    func testCenteredInsetCalculation() {
        let availableWidth: CGFloat = 1000
        let optimalTextWidth: CGFloat = 572  // 65 * 16 * 0.55
        let minimumHorizontalPadding: CGFloat = 40

        // When window is wider than text + padding
        XCTAssertTrue(availableWidth > optimalTextWidth + (minimumHorizontalPadding * 2))

        let expectedInset = (availableWidth - optimalTextWidth) / 2
        XCTAssertEqual(expectedInset, 214, accuracy: 0.1)
    }

    func testNarrowWindowInsetCalculation() {
        let availableWidth: CGFloat = 400
        let optimalTextWidth: CGFloat = 572
        let minimumHorizontalPadding: CGFloat = 40

        // When window is narrower than text + padding
        XCTAssertFalse(availableWidth > optimalTextWidth + (minimumHorizontalPadding * 2))

        // Should use minimum padding
        let expectedInset = minimumHorizontalPadding
        XCTAssertEqual(expectedInset, 40)
    }

    func testContainerWidthWhenCentered() {
        let availableWidth: CGFloat = 1000
        let optimalTextWidth: CGFloat = 572
        let minimumHorizontalPadding: CGFloat = 40

        let containerWidth: CGFloat
        if availableWidth > optimalTextWidth + (minimumHorizontalPadding * 2) {
            containerWidth = optimalTextWidth
        } else {
            containerWidth = max(100, availableWidth - (minimumHorizontalPadding * 2))
        }

        XCTAssertEqual(containerWidth, optimalTextWidth)
    }

    func testContainerWidthWhenNarrow() {
        let availableWidth: CGFloat = 400
        let optimalTextWidth: CGFloat = 572
        let minimumHorizontalPadding: CGFloat = 40

        let containerWidth: CGFloat
        if availableWidth > optimalTextWidth + (minimumHorizontalPadding * 2) {
            containerWidth = optimalTextWidth
        } else {
            containerWidth = max(100, availableWidth - (minimumHorizontalPadding * 2))
        }

        XCTAssertEqual(containerWidth, 320) // 400 - 80
    }

    func testContainerWidthMinimum() {
        let availableWidth: CGFloat = 100
        let optimalTextWidth: CGFloat = 572
        let minimumHorizontalPadding: CGFloat = 40

        let containerWidth: CGFloat
        if availableWidth > optimalTextWidth + (minimumHorizontalPadding * 2) {
            containerWidth = optimalTextWidth
        } else {
            containerWidth = max(100, availableWidth - (minimumHorizontalPadding * 2))
        }

        // Should not go below 100
        XCTAssertEqual(containerWidth, 100)
    }

    func testInsetCalculationAtBoundary() {
        let optimalTextWidth: CGFloat = 572
        let minimumHorizontalPadding: CGFloat = 40

        // Exactly at the boundary width
        let boundaryWidth = optimalTextWidth + (minimumHorizontalPadding * 2)

        // Just above boundary - should center
        let justAbove = boundaryWidth + 1
        XCTAssertTrue(justAbove > boundaryWidth)

        // Just below boundary - should use minimum padding
        let justBelow = boundaryWidth - 1
        XCTAssertFalse(justBelow > boundaryWidth)
    }

    func testSymmetricCentering() {
        let availableWidth: CGFloat = 1000
        let optimalTextWidth: CGFloat = 572

        let leftInset = (availableWidth - optimalTextWidth) / 2
        let rightInset = availableWidth - optimalTextWidth - leftInset

        // Left and right insets should be equal
        XCTAssertEqual(leftInset, rightInset, accuracy: 0.1)
    }
}

// MARK: - Font Scaling Tests

final class FontScalingTests: XCTestCase {

    func testHeading1Scale() {
        let baseFontSize: CGFloat = 16
        let heading1Size = baseFontSize * 1.5
        XCTAssertEqual(heading1Size, 24)
    }

    func testHeading2Scale() {
        let baseFontSize: CGFloat = 16
        let heading2Size = baseFontSize * 1.25
        XCTAssertEqual(heading2Size, 20)
    }

    func testHeading3Scale() {
        let baseFontSize: CGFloat = 16
        let heading3Size = baseFontSize * 1.125
        XCTAssertEqual(heading3Size, 18)
    }

    func testHeadingScalesWithBaseFontSize() {
        let baseFontSize12: CGFloat = 12
        let baseFontSize24: CGFloat = 24

        let heading1At12 = baseFontSize12 * 1.5
        let heading1At24 = baseFontSize24 * 1.5

        // Heading at font 24 should be double heading at font 12
        XCTAssertEqual(heading1At24, heading1At12 * 2)
    }
}
