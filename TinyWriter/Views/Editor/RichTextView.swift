import SwiftUI
import AppKit

/// NSViewRepresentable wrapper for rich text editing with smooth cursor
struct RichTextView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var fontSize: Double
    var lineSpacing: Double
    var lineLength: Double
    var darkMode: Bool
    var fontFamily: String

    // Calculate text width based on line length and font size
    // Average character width is approximately 0.55 * fontSize for system font
    private var optimalTextWidth: CGFloat {
        CGFloat(lineLength) * CGFloat(fontSize) * 0.55
    }
    private let verticalPadding: CGFloat = 40
    private let minimumHorizontalPadding: CGFloat = 40

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = SmoothCursorTextView()

        // ===========================================
        // GPU-ACCELERATED RENDERING SETUP
        // ===========================================

        // Enable layer-backing for GPU compositing
        scrollView.wantsLayer = true
        textView.wantsLayer = true

        // Configure scroll view layer for GPU acceleration
        if let scrollLayer = scrollView.layer {
            scrollLayer.drawsAsynchronously = true
            scrollLayer.shouldRasterize = false
            scrollLayer.allowsEdgeAntialiasing = true
        }

        // Configure text view layer for optimal rendering
        if let textLayer = textView.layer {
            textLayer.drawsAsynchronously = true
            textLayer.shouldRasterize = false
            textLayer.allowsEdgeAntialiasing = true
        }

        // Optimize layer redraw policy - only redraw on resize, not scroll
        scrollView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        textView.layerContentsRedrawPolicy = .onSetNeedsDisplay

        // Enable responsive scrolling (renders ahead for smooth scrolling)
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        if let clipLayer = scrollView.contentView.layer {
            clipLayer.drawsAsynchronously = true
        }

        // ===========================================
        // SCROLL VIEW CONFIGURATION
        // ===========================================

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        // Native bouncy scroll - this is the Apple way
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        scrollView.usesPredominantAxisScrolling = true

        // Hide scrollers completely for distraction-free writing
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false

        // Content insets to allow bounce even with short content
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 20, left: 0, bottom: 100, right: 0)

        // ===========================================
        // TEXT VIEW CONFIGURATION
        // ===========================================

        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true

        // Enable spell and grammar checking based on user preferences
        let spellCheckingEnabled = UserDefaults.standard.object(forKey: "spellCheckingEnabled") as? Bool ?? true
        let grammarCheckingEnabled = UserDefaults.standard.object(forKey: "grammarCheckingEnabled") as? Bool ?? true
        textView.isContinuousSpellCheckingEnabled = spellCheckingEnabled
        textView.isGrammarCheckingEnabled = grammarCheckingEnabled
        textView.isAutomaticSpellingCorrectionEnabled = false  // User controls corrections manually

        // Enable layout manager GPU optimizations
        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = true
            layoutManager.backgroundLayoutEnabled = true
        }

        // Apply dark mode colors
        let backgroundColor = darkMode ? NSColor.black : NSColor.textBackgroundColor
        let textColor = darkMode ? NSColor.white : NSColor.textColor
        scrollView.backgroundColor = backgroundColor
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.insertionPointColor = textColor

        // Setup smooth cursor with correct color
        textView.setupCursor(color: textColor)

        // Typography for comfortable writing
        let font = FontService.getFont(family: fontFamily, size: CGFloat(fontSize))
        textView.font = font
        textView.baseFontSize = CGFloat(fontSize)
        textView.fontFamily = fontFamily
        textView.lineSpacing = CGFloat(lineSpacing)
        textView.isDarkMode = darkMode
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(lineSpacing)
        textView.defaultParagraphStyle = paragraphStyle

        // Text container setup - don't track text view width so we can center manually
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: optimalTextWidth,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Auto-resize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Set document view
        scrollView.documentView = textView

        // Set delegate
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.verticalPadding = verticalPadding
        context.coordinator.minimumHorizontalPadding = minimumHorizontalPadding

        // Set initial attributed text
        textView.textStorage?.setAttributedString(attributedText)

        // Observe frame changes to update centering
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        // Register for first responder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            context.coordinator.updateTextInsets()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SmoothCursorTextView else { return }

        // Update coordinator's parent reference so it has current values
        context.coordinator.parent = self

        // Only update if text changed externally (compare plain string for efficiency)
        if textView.string != attributedText.string {
            let selectedRanges = textView.selectedRanges
            textView.textStorage?.setAttributedString(attributedText)
            textView.selectedRanges = selectedRanges
        }

        // Update font settings for paste formatting
        textView.fontFamily = fontFamily
        textView.lineSpacing = CGFloat(lineSpacing)
        textView.isDarkMode = darkMode

        // Update font (size or family) while preserving bold/italic traits
        let newBaseFont = FontService.getFont(family: fontFamily, size: CGFloat(fontSize))
        let currentFontName = textView.font?.fontName ?? ""
        let newFontName = newBaseFont.fontName
        if textView.font?.pointSize != CGFloat(fontSize) || currentFontName != newFontName {
            textView.font = newBaseFont
            textView.baseFontSize = CGFloat(fontSize)
            // Update all existing text with new font SIZE while preserving traits
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                let fontManager = NSFontManager.shared
                textStorage.beginEditing()
                textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
                    let traits: NSFontTraitMask
                    if let oldFont = value as? NSFont {
                        traits = fontManager.traits(of: oldFont)
                    } else {
                        traits = []
                    }
                    // Start with the new base font and apply preserved traits
                    var updatedFont = newBaseFont
                    if traits.contains(.boldFontMask) {
                        updatedFont = fontManager.convert(updatedFont, toHaveTrait: .boldFontMask)
                    }
                    if traits.contains(.italicFontMask) {
                        updatedFont = fontManager.convert(updatedFont, toHaveTrait: .italicFontMask)
                    }
                    textStorage.addAttribute(.font, value: updatedFont, range: range)
                }
                textStorage.endEditing()
            }
        }

        // Update line spacing while preserving other paragraph attributes
        let newLineSpacing = CGFloat(lineSpacing)
        if textView.defaultParagraphStyle?.lineSpacing != newLineSpacing {
            let defaultParagraphStyle = NSMutableParagraphStyle()
            defaultParagraphStyle.lineSpacing = newLineSpacing
            textView.defaultParagraphStyle = defaultParagraphStyle
            // Update all existing text with new line spacing, preserving other paragraph attributes
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.beginEditing()
                textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
                    let newStyle = NSMutableParagraphStyle()
                    if let oldStyle = value as? NSParagraphStyle {
                        newStyle.setParagraphStyle(oldStyle)
                    }
                    newStyle.lineSpacing = newLineSpacing
                    textStorage.addAttribute(.paragraphStyle, value: newStyle, range: range)
                }
                textStorage.endEditing()
            }
        }

        // Update dark mode colors
        let backgroundColor = darkMode ? NSColor.black : NSColor.textBackgroundColor
        let textColor = darkMode ? NSColor.white : NSColor.textColor

        // Always update cursor color - use explicit colors for CALayer compatibility
        let cursorColor = darkMode ? NSColor.white : NSColor.black
        textView.updateCursorColor(cursorColor)

        if scrollView.backgroundColor != backgroundColor {
            scrollView.backgroundColor = backgroundColor
            textView.backgroundColor = backgroundColor
            textView.textColor = textColor
            // Update all existing text with new color
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: textStorage.length))
            }
        }

        // Update centering
        context.coordinator.updateTextInsets()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextView
        weak var textView: NSTextView?
        var verticalPadding: CGFloat = 40
        var minimumHorizontalPadding: CGFloat = 40
        private var formattingObserver: Any?
        private var formattingChangeObserver: Any?
        private var spellCheckingObserver: Any?
        private var grammarCheckingObserver: Any?

        var optimalTextWidth: CGFloat {
            parent.optimalTextWidth
        }

        init(_ parent: RichTextView) {
            self.parent = parent
            super.init()

            // Listen for formatting toolbar actions
            formattingObserver = NotificationCenter.default.addObserver(
                forName: .applyFormatting,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let format = notification.userInfo?["format"] as? String,
                      let textView = self?.textView,
                      let textStorage = textView.textStorage else { return }

                let range = textView.selectedRange()
                guard range.length > 0 else { return }

                // Use shouldChangeText/didChangeText pattern to enable undo support
                guard textView.shouldChangeText(in: range, replacementString: nil) else { return }

                let fontManager = NSFontManager.shared

                // Apply formatting to selected range
                textStorage.beginEditing()

                switch format {
                case "bold", "italic":
                    // Handle font trait changes
                    textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
                        guard let currentFont = value as? NSFont else { return }

                        let newFont: NSFont
                        if format == "bold" {
                            // Toggle bold
                            let traits = fontManager.traits(of: currentFont)
                            if traits.contains(.boldFontMask) {
                                newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                            } else {
                                newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                            }
                        } else {
                            // Toggle italic
                            let traits = fontManager.traits(of: currentFont)
                            if traits.contains(.italicFontMask) {
                                newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                            } else {
                                newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                            }
                        }

                        textStorage.addAttribute(.font, value: newFont, range: attrRange)
                    }

                case "alignLeft", "alignCenter", "alignRight":
                    // Handle paragraph alignment changes
                    let alignment: NSTextAlignment
                    switch format {
                    case "alignLeft":
                        alignment = .left
                    case "alignCenter":
                        alignment = .center
                    case "alignRight":
                        alignment = .right
                    default:
                        alignment = .left
                    }

                    // Get existing paragraph style or create new one, then modify alignment
                    textStorage.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, attrRange, _ in
                        let existingStyle = value as? NSParagraphStyle ?? NSParagraphStyle.default
                        let mutableStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
                        mutableStyle.alignment = alignment
                        textStorage.addAttribute(.paragraphStyle, value: mutableStyle, range: attrRange)
                    }

                default:
                    break
                }

                textStorage.endEditing()

                // Complete the change to register with undo manager
                textView.didChangeText()

                // Notify that formatting changed so the binding can be updated
                NotificationCenter.default.post(name: .formattingDidChange, object: textView)
            }

            // Listen for formatting changes to update the binding
            formattingChangeObserver = NotificationCenter.default.addObserver(
                forName: .formattingDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let textView = notification.object as? NSTextView,
                      textView === self.textView,
                      let textStorage = textView.textStorage else { return }

                // Update the binding with the current attributed text (including formatting)
                self.parent.attributedText = NSAttributedString(attributedString: textStorage)
            }

            // Listen for spell checking setting changes
            spellCheckingObserver = NotificationCenter.default.addObserver(
                forName: .spellCheckingChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let textView = self?.textView else { return }
                let enabled = UserDefaults.standard.object(forKey: "spellCheckingEnabled") as? Bool ?? true
                textView.isContinuousSpellCheckingEnabled = enabled
            }

            // Listen for grammar checking setting changes
            grammarCheckingObserver = NotificationCenter.default.addObserver(
                forName: .grammarCheckingChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let textView = self?.textView else { return }
                let enabled = UserDefaults.standard.object(forKey: "grammarCheckingEnabled") as? Bool ?? true
                textView.isGrammarCheckingEnabled = enabled
            }
        }

        deinit {
            if let observer = formattingObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = formattingChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = spellCheckingObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = grammarCheckingObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        @objc func frameDidChange(_ notification: Notification) {
            updateTextInsets()
        }

        func updateTextInsets() {
            guard let textView = textView,
                  let scrollView = textView.enclosingScrollView,
                  let textContainer = textView.textContainer else { return }

            let availableWidth = scrollView.frame.width
            let horizontalInset: CGFloat
            let containerWidth: CGFloat

            if availableWidth > optimalTextWidth + (minimumHorizontalPadding * 2) {
                // Center the text by calculating equal margins
                containerWidth = optimalTextWidth
                horizontalInset = (availableWidth - optimalTextWidth) / 2
            } else {
                // Use minimum padding when window is narrow
                containerWidth = max(100, availableWidth - (minimumHorizontalPadding * 2))
                horizontalInset = minimumHorizontalPadding
            }

            textContainer.containerSize = NSSize(
                width: containerWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.textContainerInset = NSSize(width: horizontalInset, height: verticalPadding)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }

            // Commit the attributed text to the document binding
            // NSDocument's autosave will handle the actual file saving
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.attributedText = NSAttributedString(attributedString: textStorage)
            }
        }

    }
}
