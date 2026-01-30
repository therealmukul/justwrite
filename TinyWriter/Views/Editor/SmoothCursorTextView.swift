import AppKit
import QuartzCore

/// NSTextView subclass with smooth animated cursor and formatting support
class SmoothCursorTextView: NSTextView {
    private var cursorLayer: CALayer?
    private var blinkTimer: Timer?
    private var cursorColor: NSColor = .black  // Safe default, will be updated
    var baseFontSize: CGFloat = 16  // Set from coordinator, used for fixed cursor height
    private var moveCursorObserver: Any?

    // MARK: - Cursor Setup

    func setupCursor(color: NSColor) {
        cursorColor = color
        insertionPointColor = color

        wantsLayer = true

        // Create cursor layer
        let cursor = CALayer()
        cursor.backgroundColor = color.cgColor
        cursor.cornerRadius = 1.5
        cursor.frame = CGRect(x: 0, y: 0, width: 2.5, height: 20)

        layer?.addSublayer(cursor)
        cursorLayer = cursor

        // Start blinking
        startBlinking()

        // Position after a brief delay to ensure layout is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateCursorPosition(animated: false)
        }
    }

    // MARK: - Cursor Color

    func updateCursorColor(_ color: NSColor) {
        cursorColor = color
        insertionPointColor = color
        cursorLayer?.backgroundColor = color.cgColor
    }

    // MARK: - Cursor Blinking

    private func startBlinking() {
        blinkTimer?.invalidate()
        cursorLayer?.opacity = 1

        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let cursor = self.cursorLayer else { return }
            guard self.window?.firstResponder == self else { return }

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = cursor.opacity
            fade.toValue = cursor.opacity > 0.5 ? 0.0 : 1.0
            fade.duration = 0.15
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false
            cursor.add(fade, forKey: "blink")
            cursor.opacity = cursor.opacity > 0.5 ? 0.0 : 1.0
        }
    }

    private func resetBlink() {
        cursorLayer?.removeAnimation(forKey: "blink")
        cursorLayer?.opacity = 1
        startBlinking()
    }

    // MARK: - Cursor Positioning

    func updateCursorPosition(animated: Bool) {
        guard let cursor = cursorLayer else { return }
        guard let window = window else { return }

        // Hide if there's a selection
        if selectedRange().length > 0 {
            cursor.isHidden = true
            return
        }
        cursor.isHidden = false

        let insertionPoint = selectedRange().location

        // Fixed cursor height based on base font size from settings
        let baseFont = NSFont.systemFont(ofSize: baseFontSize)
        let cursorHeight = baseFont.ascender + abs(baseFont.descender)

        // Get cursor position using firstRect - simple and reliable
        let charRange = NSRange(location: insertionPoint, length: 0)
        var actualRange = NSRange()
        let screenRect = firstRect(forCharacterRange: charRange, actualRange: &actualRange)
        let windowRect = window.convertFromScreen(screenRect)
        let viewRect = convert(windowRect, from: nil)

        let newFrame = CGRect(
            x: viewRect.origin.x,
            y: viewRect.origin.y,
            width: 2.5,
            height: cursorHeight
        )

        // Validate frame
        guard !newFrame.origin.x.isNaN && !newFrame.origin.y.isNaN else { return }

        if animated {
            // Liquid glass spring animation using CASpringAnimation
            let oldFrame = cursor.frame

            // Calculate movement distance
            let dx = abs(newFrame.origin.x - oldFrame.origin.x)
            let dy = abs(newFrame.origin.y - oldFrame.origin.y)
            let dh = abs(newFrame.height - oldFrame.height)

            // Only animate if there's meaningful movement
            if dx > 0.5 || dy > 0.5 || dh > 0.5 {
                // Determine if this is a small movement (typing) or large jump (clicking/navigation)
                let isSmallMovement = dx < 20 && dy < 5

                // Position animation with spring physics
                let positionAnimation = CASpringAnimation(keyPath: "position")
                positionAnimation.fromValue = NSValue(point: NSPoint(
                    x: oldFrame.origin.x + oldFrame.width / 2,
                    y: oldFrame.origin.y + oldFrame.height / 2
                ))
                positionAnimation.toValue = NSValue(point: NSPoint(
                    x: newFrame.origin.x + newFrame.width / 2,
                    y: newFrame.origin.y + newFrame.height / 2
                ))

                if isSmallMovement {
                    // Fast, snappy animation for typing - minimal lag
                    positionAnimation.damping = 30
                    positionAnimation.stiffness = 800
                    positionAnimation.mass = 0.3
                } else {
                    // Smooth liquid animation for larger movements
                    positionAnimation.damping = 30
                    positionAnimation.stiffness = 800
                    positionAnimation.mass = 0.3
                }
                positionAnimation.initialVelocity = 0
                positionAnimation.duration = positionAnimation.settlingDuration

                // Height animation for smooth heading transitions
                let boundsAnimation = CASpringAnimation(keyPath: "bounds.size.height")
                boundsAnimation.fromValue = oldFrame.height
                boundsAnimation.toValue = newFrame.height
                boundsAnimation.damping = 25
                boundsAnimation.stiffness = 500
                boundsAnimation.mass = 0.4
                boundsAnimation.duration = boundsAnimation.settlingDuration

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                cursor.frame = newFrame
                CATransaction.commit()

                cursor.add(positionAnimation, forKey: "liquidPosition")
                cursor.add(boundsAnimation, forKey: "liquidBounds")
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                cursor.frame = newFrame
                CATransaction.commit()
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            cursor.frame = newFrame
            CATransaction.commit()
        }
    }

    // MARK: - Hide Default Cursor

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // Don't draw default cursor
    }

    override func setNeedsDisplay(_ rect: NSRect) {
        // Prevent cursor rect from triggering redraws
        var newRect = rect
        if rect.width <= 5 {
            newRect = .zero
        }
        super.setNeedsDisplay(newRect)
    }

    // MARK: - Cursor Rects (System Mouse Cursor)

    override func resetCursorRects() {
        // Only set I-beam cursor rect for the visible portion of this text view
        // This prevents the I-beam from "bleeding" into other areas like the sidebar
        discardCursorRects()
        addCursorRect(visibleRect, cursor: .iBeam)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Remove any existing cursor update tracking areas we added
        for trackingArea in trackingAreas where trackingArea.options.contains(.cursorUpdate) {
            removeTrackingArea(trackingArea)
        }
        // Add tracking area only for visible rect with cursor update
        let trackingArea = NSTrackingArea(
            rect: visibleRect,
            options: [.cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func cursorUpdate(with event: NSEvent) {
        // Only show I-beam if mouse is within our visible bounds
        let locationInView = convert(event.locationInWindow, from: nil)
        if visibleRect.contains(locationInView) {
            NSCursor.iBeam.set()
        } else {
            // Let the system handle cursor for areas outside our bounds
            super.cursorUpdate(with: event)
        }
    }

    // MARK: - Event Handling

    override var selectedRanges: [NSValue] {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateCursorPosition(animated: true)
                self?.resetBlink()
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        // Handle Cmd+B for bold
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "b" {
            toggleBold()
            return
        }

        // Handle Cmd+I for italic
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
            toggleItalic()
            return
        }

        super.keyDown(with: event)
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    // MARK: - Rich Text Formatting

    func toggleBold() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()

        if range.length == 0 {
            // No selection - toggle typing attributes for future text
            var typingAttributes = self.typingAttributes
            if let currentFont = typingAttributes[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let traits = fontManager.traits(of: currentFont)
                let newFont: NSFont
                if traits.contains(.boldFontMask) {
                    newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                }
                typingAttributes[.font] = newFont
                self.typingAttributes = typingAttributes
            }
            return
        }

        // Has selection - toggle bold on selected text
        // Use shouldChangeText/didChangeText pattern to enable undo support
        guard shouldChangeText(in: range, replacementString: nil) else { return }

        let fontManager = NSFontManager.shared
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: currentFont)
            let newFont: NSFont
            if traits.contains(.boldFontMask) {
                newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
            } else {
                newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()

        // Complete the change to register with undo manager
        didChangeText()

        // Notify that formatting changed so the binding can be updated
        NotificationCenter.default.post(name: .formattingDidChange, object: self)

        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    func toggleItalic() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()

        if range.length == 0 {
            // No selection - toggle typing attributes for future text
            var typingAttributes = self.typingAttributes
            if let currentFont = typingAttributes[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let traits = fontManager.traits(of: currentFont)
                let newFont: NSFont
                if traits.contains(.italicFontMask) {
                    newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                }
                typingAttributes[.font] = newFont
                self.typingAttributes = typingAttributes
            }
            return
        }

        // Has selection - toggle italic on selected text
        // Use shouldChangeText/didChangeText pattern to enable undo support
        guard shouldChangeText(in: range, replacementString: nil) else { return }

        let fontManager = NSFontManager.shared
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: currentFont)
            let newFont: NSFont
            if traits.contains(.italicFontMask) {
                newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
            } else {
                newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()

        // Complete the change to register with undo manager
        didChangeText()

        // Notify that formatting changed so the binding can be updated
        NotificationCenter.default.post(name: .formattingDidChange, object: self)

        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: .hideFormattingToolbar, object: nil)
        super.mouseDown(with: event)
        // Update cursor after selection is set
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        updateCursorPosition(animated: true)
        resetBlink()
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        updateCursorPosition(animated: false)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            cursorLayer?.isHidden = false
            updateCursorPosition(animated: false)
            resetBlink()
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        blinkTimer?.invalidate()
        cursorLayer?.isHidden = true
        return result
    }

    // MARK: - Paste/Cut/Delete Operations

    override func paste(_ sender: Any?) {
        super.paste(sender)
        // Update cursor position after paste
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func pasteAsPlainText(_ sender: Any?) {
        super.pasteAsPlainText(sender)
        // Update cursor position after paste
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func cut(_ sender: Any?) {
        super.cut(sender)
        // Update cursor position after cut
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func delete(_ sender: Any?) {
        super.delete(sender)
        // Update cursor position after delete
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func deleteBackward(_ sender: Any?) {
        super.deleteBackward(sender)
        // Update cursor position after delete
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func deleteForward(_ sender: Any?) {
        super.deleteForward(sender)
        // Update cursor position after delete
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && cursorLayer == nil {
            // Determine correct color based on appearance
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let color = isDark ? NSColor.white : NSColor.black
            setupCursor(color: color)
        }

        // Set up observer for moving cursor to end
        if window != nil && moveCursorObserver == nil {
            moveCursorObserver = NotificationCenter.default.addObserver(
                forName: .moveCursorToEnd,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.moveCursorToEnd()
            }
        }
    }

    /// Moves the cursor to the end of the document
    func moveCursorToEnd() {
        let endPosition = string.count
        setSelectedRange(NSRange(location: endPosition, length: 0))
        scrollRangeToVisible(NSRange(location: endPosition, length: 0))
        updateCursorPosition(animated: false)
        resetBlink()
    }

    override func layout() {
        super.layout()
        updateCursorPosition(animated: false)
    }

    deinit {
        blinkTimer?.invalidate()
        if let observer = moveCursorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Right Click Formatting

    // Override right-click to show formatting toolbar instead of context menu
    override func rightMouseDown(with event: NSEvent) {
        let range = selectedRange()
        guard range.length > 0 else {
            // No selection, hide toolbar and do nothing
            NotificationCenter.default.post(name: .hideFormattingToolbar, object: nil)
            return
        }

        // Get the rect of the selection for positioning
        guard let layoutManager = layoutManager, let textContainer = textContainer else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let selectionRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Convert to view coordinates
        var rectInView = selectionRect
        rectInView.origin.x += textContainerInset.width
        rectInView.origin.y += textContainerInset.height

        // Convert to window coordinates
        let rectInWindow = convert(rectInView, to: nil)

        NotificationCenter.default.post(
            name: .showFormattingToolbar,
            object: nil,
            userInfo: ["selectionRect": rectInWindow]
        )
    }

    // Return nil to prevent default context menu
    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

}
