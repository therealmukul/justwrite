import AppKit
import UniformTypeIdentifiers

/// Service for exporting documents to PDF format
struct PDFExportService {

    /// Exports a file at the given URL to PDF format
    /// - Parameters:
    ///   - url: Source file URL (RTF or text file)
    ///   - fontSize: Font size setting
    ///   - lineSpacing: Line spacing setting
    ///   - lineLength: Line length setting
    ///   - fontFamily: Font family setting
    static func exportAsPDF(
        url: URL,
        fontSize: Double,
        lineSpacing: Double,
        lineLength: Double,
        fontFamily: String
    ) {
        // Read file as Data (not String) to properly handle RTF format
        guard let data = try? Data(contentsOf: url) else { return }

        // Parse as RTF to preserve formatting (bold, italic, alignment, etc.)
        let attributedContent: NSAttributedString
        if let rtfContent = NSAttributedString(rtf: data, documentAttributes: nil) {
            attributedContent = rtfContent
        } else {
            // Fallback to plain text if RTF parsing fails
            let plainText = String(decoding: data, as: UTF8.self)
            attributedContent = NSAttributedString(string: plainText, attributes: [
                .font: FontService.getFont(family: fontFamily, size: CGFloat(fontSize)),
                .foregroundColor: NSColor.black
            ])
        }

        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + ".pdf"
        savePanel.title = "Export as PDF"

        if savePanel.runModal() == .OK, let saveURL = savePanel.url {
            createPDF(
                attributedContent: attributedContent,
                saveURL: saveURL,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                lineLength: lineLength
            )
        }
    }

    /// Creates a PDF file from attributed content
    /// - Parameters:
    ///   - attributedContent: The content to render as PDF
    ///   - saveURL: Destination file URL
    ///   - fontSize: Font size for scaling
    ///   - lineSpacing: Line spacing for scaling
    ///   - lineLength: Line length for text width calculation
    static func createPDF(
        attributedContent: NSAttributedString,
        saveURL: URL,
        fontSize: Double,
        lineSpacing: Double,
        lineLength: Double
    ) {
        // PDF page settings
        let pageWidth: CGFloat = 612  // US Letter width in points
        let pageHeight: CGFloat = 792 // US Letter height in points
        let marginY: CGFloat = 72     // 1 inch top/bottom margins

        // Scale factor for PDF (fonts render smaller in PDF than on screen)
        let scaleFactor: CGFloat = 0.65
        let pdfFontSize = CGFloat(fontSize) * scaleFactor
        let pdfLineSpacing = CGFloat(lineSpacing) * scaleFactor

        // Calculate text width based on line length setting
        let optimalTextWidth = CGFloat(lineLength) * pdfFontSize * 0.5
        let maxTextWidth = pageWidth - 72  // At least 0.5 inch margins on each side
        let textWidth = min(optimalTextWidth, maxTextWidth)
        let textHeight = pageHeight - (marginY * 2)

        // Center text horizontally on page
        let marginX = (pageWidth - textWidth) / 2

        // Scale the attributed string while preserving all formatting (bold, italic, alignment)
        let scaledString = scaleAttributedString(
            attributedContent,
            scaleFactor: scaleFactor,
            defaultLineSpacing: pdfLineSpacing
        )

        // Create PDF context
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let context = CGContext(saveURL as CFURL, mediaBox: &mediaBox, nil) else { return }

        // Calculate text layout (Core Text handles alignment via paragraph styles)
        let framesetter = CTFramesetterCreateWithAttributedString(scaledString)
        var currentRange = CFRange(location: 0, length: 0)

        while currentRange.location < scaledString.length {
            // Start new page
            context.beginPage(mediaBox: &mediaBox)

            // Create text frame for this page
            let framePath = CGPath(rect: CGRect(x: marginX, y: marginY, width: textWidth, height: textHeight), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)

            // Draw the text
            context.textMatrix = .identity
            CTFrameDraw(frame, context)

            // Get the range that was drawn
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += visibleRange.length

            context.endPage()
        }

        context.closePDF()
    }

    /// Scales fonts in an attributed string while preserving all other attributes (bold, italic, alignment)
    /// - Parameters:
    ///   - attributedString: The original attributed string
    ///   - scaleFactor: Factor to scale font sizes by
    ///   - defaultLineSpacing: Line spacing to apply
    /// - Returns: A new attributed string with scaled fonts
    static func scaleAttributedString(
        _ attributedString: NSAttributedString,
        scaleFactor: CGFloat,
        defaultLineSpacing: CGFloat
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let fontManager = NSFontManager.shared

        // Scale fonts while preserving traits (bold, italic)
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            if let font = value as? NSFont {
                let traits = fontManager.traits(of: font)
                let scaledSize = font.pointSize * scaleFactor

                var scaledFont = NSFont(name: font.fontName, size: scaledSize)
                    ?? NSFont.systemFont(ofSize: scaledSize)

                // Re-apply traits to ensure they're preserved
                if traits.contains(.boldFontMask) {
                    scaledFont = fontManager.convert(scaledFont, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    scaledFont = fontManager.convert(scaledFont, toHaveTrait: .italicFontMask)
                }

                mutable.addAttribute(.font, value: scaledFont, range: range)
            }
        }

        // Update line spacing while preserving alignment
        mutable.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            let existingStyle = value as? NSParagraphStyle ?? NSParagraphStyle.default
            let newStyle = NSMutableParagraphStyle()
            newStyle.setParagraphStyle(existingStyle)  // Preserves alignment
            newStyle.lineSpacing = defaultLineSpacing
            mutable.addAttribute(.paragraphStyle, value: newStyle, range: range)
        }

        // Set text color to black for print
        mutable.addAttribute(.foregroundColor, value: NSColor.black, range: fullRange)

        return mutable
    }
}
