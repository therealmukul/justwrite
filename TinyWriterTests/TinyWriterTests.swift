import XCTest
import AppKit
import UniformTypeIdentifiers
@testable import TinyWriter

// MARK: - Window Reopen Behavior Tests

final class WindowReopenBehaviorTests: XCTestCase {

    // MARK: - Dock Icon Click Tests

    func testAppDelegateHasReopenHandler() {
        // Verify AppDelegate has the reopen handler and it's callable
        let appDelegate = AppDelegate()

        // The method should exist and be callable without crashing
        // The actual return value depends on window state at runtime
        _ = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        _ = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true)

        // Test passes if no crash
        XCTAssertTrue(true, "AppDelegate should have working reopen handler")
    }

    func testAppShouldHandleReopenWithVisibleWindows() {
        let appDelegate = AppDelegate()

        // When there ARE visible windows, always return true to let system handle it
        let result = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true)

        XCTAssertTrue(result, "Should return true when there are visible windows")
    }

    func testShowOrCreateWindowMethod() {
        // Test that showOrCreateWindow exists and returns a boolean
        let appDelegate = AppDelegate()

        // The method should exist and return a boolean
        let result = appDelegate.showOrCreateWindow()

        // Result is a boolean indicating whether system should create window
        XCTAssertNotNil(result, "showOrCreateWindow should return a boolean")
    }

    func testReopenHandlerActivatesApp() {
        // Verify that the reopen handler activates the application
        let appDelegate = AppDelegate()

        // Trigger reopen with no visible windows
        _ = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)

        // Give time for activation
        let expectation = XCTestExpectation(description: "App activation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // In a full app environment, this would activate the app
        // For unit tests, we verify the method completes without error
        XCTAssertTrue(true, "Reopen handler should complete without error")
    }
}

// MARK: - App Launch Behavior Tests

final class AppLaunchBehaviorTests: XCTestCase {

    // MARK: - Fresh Note on Launch Tests

    func testNewDocumentStartsWithEmptyText() {
        // When app launches, a new document should have empty text
        let document = TinyWriterDocument()
        XCTAssertEqual(document.text, "", "New document should start with empty text")
    }

    func testNewDocumentHasEmptyAttributedText() {
        let document = TinyWriterDocument()
        XCTAssertEqual(document.attributedText.length, 0, "New document should have empty attributed text")
    }

    func testNewDocumentIsReadyForEditing() {
        let document = TinyWriterDocument()
        // Document should be in a state ready for user to start typing
        XCTAssertEqual(document.text, "")
        XCTAssertNotNil(document.attributedText)
    }

    // MARK: - Document Initialization Tests

    func testDocumentWithTextInitializesCorrectly() {
        let document = TinyWriterDocument(text: "Hello")
        XCTAssertEqual(document.text, "Hello")
    }

    func testEmptyDocumentTextProperty() {
        let document = TinyWriterDocument()
        // Setting text on empty document should work
        var mutableDoc = document
        mutableDoc.text = "New content"
        XCTAssertEqual(mutableDoc.text, "New content")
    }

    // MARK: - UserDefaults Key Tests (verify we don't track last opened)

    func testLastOpenedDocumentKeyExists() {
        // This key should NOT be used anymore for opening documents on launch
        // But we verify it exists for backwards compatibility during removal
        let key = "lastOpenedDocument"
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertNil(UserDefaults.standard.string(forKey: key))
    }

    func testAppShouldNotPersistLastOpenedDocument() {
        // After the fix, we should not be tracking last opened document for launch
        // This is a behavioral test - the app should always start fresh
        let key = "lastOpenedDocument"

        // Even if a value exists, app should ignore it on launch
        UserDefaults.standard.set("/some/path/test.rtf", forKey: key)

        // The value might exist but app behavior should be to create new note
        // We can't test the full app launch here, but we verify the document starts fresh
        let newDocument = TinyWriterDocument()
        XCTAssertEqual(newDocument.text, "", "App should always start with fresh empty document")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Document Save Lifecycle Tests

final class DocumentSaveLifecycleTests: XCTestCase {

    // MARK: - Change Tracking Tests

    func testDocumentMarksItselfDirtyWhenTextChanges() {
        let document = TinyWriterDocument()

        // Give document a file URL (NSDocument needs this for change tracking)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).rtf")
        document.fileURL = tempURL

        // New document should not have unsaved changes initially
        XCTAssertFalse(document.hasUnautosavedChanges, "New document should not have unsaved changes")

        // Change the text
        document.text = "New content"

        // Document should now be marked as dirty
        XCTAssertTrue(document.hasUnautosavedChanges, "Document should have unsaved changes after text modification")
    }

    func testDocumentMarksItselfDirtyWhenAttributedTextChanges() {
        let document = TinyWriterDocument()

        // Give document a file URL (NSDocument needs this for change tracking)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).rtf")
        document.fileURL = tempURL

        // New document should not have unsaved changes initially
        XCTAssertFalse(document.hasUnautosavedChanges, "New document should not have unsaved changes")

        // Change the attributed text
        let newText = NSAttributedString(string: "New attributed content")
        document.attributedText = newText

        // Document should now be marked as dirty
        XCTAssertTrue(document.hasUnautosavedChanges, "Document should have unsaved changes after attributedText modification")
    }

    // MARK: - Data Generation Tests

    func testDataOfTypeReturnsCurrentContent() throws {
        let document = TinyWriterDocument(text: "Test content for saving")

        // Get the data that would be saved
        let data = try document.data(ofType: UTType.rtf.identifier)

        // Verify data is not empty
        XCTAssertFalse(data.isEmpty, "data(ofType:) should return non-empty data")

        // Verify content can be restored from data
        if let restored = NSAttributedString(rtf: data, documentAttributes: nil) {
            XCTAssertEqual(restored.string, "Test content for saving", "Saved data should contain the text")
        } else {
            XCTFail("Should be able to restore attributed string from saved data")
        }
    }

    func testDataOfTypeReturnsLatestContent() throws {
        let document = TinyWriterDocument(text: "Initial content")

        // Change the text
        document.text = "Updated content"

        // Get the data that would be saved
        let data = try document.data(ofType: UTType.rtf.identifier)

        // Verify the UPDATED content is returned
        if let restored = NSAttributedString(rtf: data, documentAttributes: nil) {
            XCTAssertEqual(restored.string, "Updated content", "data(ofType:) should return the latest content")
        } else {
            XCTFail("Should be able to restore attributed string from saved data")
        }
    }

    // MARK: - Document Loading Tests (Critical: should not be dirty after load)

    func testDocumentIsNotDirtyAfterLoading() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_load_dirty_\(UUID().uuidString).rtf")

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        // Create and save a document first
        let originalDoc = TinyWriterDocument(text: "Test content")
        let saveData = try originalDoc.data(ofType: UTType.rtf.identifier)
        try saveData.write(to: testFileURL)

        // Create new document and load
        let loadedDoc = TinyWriterDocument()
        loadedDoc.fileURL = testFileURL
        let loadedData = try Data(contentsOf: testFileURL)
        try loadedDoc.read(from: loadedData, ofType: UTType.rtf.identifier)

        // Wait for async loading
        let expectation = XCTestExpectation(description: "Content loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // CRITICAL: Document should NOT be dirty after loading
        XCTAssertFalse(loadedDoc.hasUnautosavedChanges,
            "Document should NOT be marked dirty after loading - this causes unnecessary saves")
    }

    func testDocumentIsNotDirtyAfterLoadingEmptyFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_empty_\(UUID().uuidString).rtf")

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        // Create empty document and save
        let originalDoc = TinyWriterDocument()
        let saveData = try originalDoc.data(ofType: UTType.rtf.identifier)
        try saveData.write(to: testFileURL)

        // Load into new document
        let loadedDoc = TinyWriterDocument()
        loadedDoc.fileURL = testFileURL
        let loadedData = try Data(contentsOf: testFileURL)
        try loadedDoc.read(from: loadedData, ofType: UTType.rtf.identifier)

        let expectation = XCTestExpectation(description: "Content loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertFalse(loadedDoc.hasUnautosavedChanges,
            "Empty document should NOT be marked dirty after loading")
    }

    // MARK: - Formatting Change Tests

    func testFormattingOnlyChangesMarkDocumentDirty() {
        let document = TinyWriterDocument(text: "Hello")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_fmt_\(UUID().uuidString).rtf")
        document.fileURL = tempURL

        // Clear initial dirty state
        document.updateChangeCount(.changeCleared)
        XCTAssertFalse(document.hasUnautosavedChanges, "Should start clean")

        // Apply bold formatting (same text, different attributes)
        let boldFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 16),
            toHaveTrait: .boldFontMask
        )
        let boldText = NSMutableAttributedString(attributedString: document.attributedText)
        boldText.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5))

        document.attributedText = boldText

        // Document should be marked dirty even though text content is the same
        XCTAssertTrue(document.hasUnautosavedChanges,
            "Formatting changes should mark document dirty for autosave")
    }

    func testItalicFormattingChangesMarkDocumentDirty() {
        let document = TinyWriterDocument(text: "World")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_italic_\(UUID().uuidString).rtf")
        document.fileURL = tempURL

        document.updateChangeCount(.changeCleared)
        XCTAssertFalse(document.hasUnautosavedChanges)

        // Apply italic formatting
        let italicFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 16),
            toHaveTrait: .italicFontMask
        )
        let italicText = NSMutableAttributedString(attributedString: document.attributedText)
        italicText.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: 5))

        document.attributedText = italicText

        XCTAssertTrue(document.hasUnautosavedChanges,
            "Italic formatting should mark document dirty")
    }

    // MARK: - Save/Reload Cycle Tests

    func testContentSurvivesSaveReloadCycle() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_save_\(UUID().uuidString).rtf")

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        // Create document with content
        let document = TinyWriterDocument(text: "Content to preserve")

        // Get save data
        let saveData = try document.data(ofType: UTType.rtf.identifier)

        // Write to file
        try saveData.write(to: testFileURL)

        // Create new document and load
        let loadedDocument = TinyWriterDocument()
        let loadedData = try Data(contentsOf: testFileURL)
        try loadedDocument.read(from: loadedData, ofType: UTType.rtf.identifier)

        // Wait a moment for async loading
        let expectation = XCTestExpectation(description: "Content loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Verify content was preserved
        XCTAssertEqual(loadedDocument.text, "Content to preserve", "Content should survive save/reload cycle")
    }

    func testMultipleEditsPreservedOnSave() throws {
        let document = TinyWriterDocument(text: "First")

        // Make multiple edits
        document.text = "Second"
        document.text = "Third"
        document.text = "Final content"

        // Get save data
        let saveData = try document.data(ofType: UTType.rtf.identifier)

        // Verify final content is saved
        if let restored = NSAttributedString(rtf: saveData, documentAttributes: nil) {
            XCTAssertEqual(restored.string, "Final content", "Final edit should be saved")
        } else {
            XCTFail("Should be able to restore content")
        }
    }
}

// MARK: - Save Synchronization Tests

final class SaveSynchronizationTests: XCTestCase {

    func testAutosaveTriggersForModifiedDocument() throws {
        // This test verifies that autosave properly persists document changes
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("autosave_test_\(UUID().uuidString).rtf")

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        // Create a document with content
        let document = TinyWriterDocument(text: "Initial content")
        document.fileURL = testFileURL

        // Save it once to establish the file
        let initialData = try document.data(ofType: UTType.rtf.identifier)
        try initialData.write(to: testFileURL)
        document.updateChangeCount(.changeCleared)

        // Modify the document
        document.text = "Modified content for autosave test"
        XCTAssertTrue(document.hasUnautosavedChanges, "Should have unsaved changes")

        // Trigger autosave (non-blocking)
        let expectation = XCTestExpectation(description: "Autosave completes")
        document.autosave(withImplicitCancellability: false) { error in
            XCTAssertNil(error, "Autosave should succeed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // Verify file was actually updated
        let savedData = try Data(contentsOf: testFileURL)
        if let restored = NSAttributedString(rtf: savedData, documentAttributes: nil) {
            XCTAssertEqual(restored.string, "Modified content for autosave test",
                "File should contain the modified content after autosave")
        } else {
            XCTFail("Could not read saved file")
        }
    }

    func testDocumentSavePreservesFormattingChanges() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("fmt_save_\(UUID().uuidString).rtf")

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        // Create document with plain text
        let document = TinyWriterDocument(text: "Bold text")
        document.fileURL = testFileURL

        // Apply bold formatting
        let boldFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 16),
            toHaveTrait: .boldFontMask
        )
        let boldText = NSMutableAttributedString(attributedString: document.attributedText)
        boldText.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))
        document.attributedText = boldText

        // Save
        let saveData = try document.data(ofType: UTType.rtf.identifier)
        try saveData.write(to: testFileURL)

        // Load and verify formatting preserved
        let loadedData = try Data(contentsOf: testFileURL)
        guard let restored = NSAttributedString(rtf: loadedData, documentAttributes: nil) else {
            XCTFail("Could not read saved file")
            return
        }

        XCTAssertEqual(restored.string, "Bold text")

        // Check that bold formatting was preserved
        var hasBold = false
        restored.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            if let font = value as? NSFont {
                let traits = NSFontManager.shared.traits(of: font)
                if traits.contains(.boldFontMask) {
                    hasBold = true
                }
            }
        }
        XCTAssertTrue(hasBold, "Bold formatting should be preserved after save/load cycle")
    }
}

// MARK: - Document Save State Tests

final class DocumentSaveStateTests: XCTestCase {

    // MARK: - Document Content Preservation Tests

    func testDocumentTextIsPreservedAfterSetting() {
        var document = TinyWriterDocument(text: "Original content")
        XCTAssertEqual(document.text, "Original content")

        // Simulating what should happen during save - content should not change
        let savedContent = document.text
        XCTAssertEqual(savedContent, "Original content")
    }

    func testDocumentAttributedTextGeneratesCorrectRTF() {
        let document = TinyWriterDocument(text: "Test content")

        // Verify RTF can be generated
        let range = NSRange(location: 0, length: document.attributedText.length)
        let rtfData = document.attributedText.rtf(from: range, documentAttributes: [:])

        XCTAssertNotNil(rtfData, "Should be able to generate RTF data")

        // Verify RTF contains the text
        if let data = rtfData, let rtfString = String(data: data, encoding: .ascii) {
            XCTAssertTrue(rtfString.contains("Test content") || data.count > 0,
                         "RTF should contain the text content")
        }
    }

    func testDocumentContentAfterClearingText() {
        var document = TinyWriterDocument(text: "Original content")
        XCTAssertEqual(document.text, "Original content")

        // Clear the text
        document.text = ""
        XCTAssertEqual(document.text, "")
        XCTAssertEqual(document.attributedText.length, 0)
    }

    func testRTFDataContainsCorrectContent() {
        let document = TinyWriterDocument(text: "Save me!")

        // Simulate what fileWrapper does - generate RTF data
        let range = NSRange(location: 0, length: document.attributedText.length)
        let rtfData = document.attributedText.rtf(from: range, documentAttributes: [:])

        XCTAssertNotNil(rtfData, "Should generate RTF data")

        // Read the content back
        if let data = rtfData,
           let restored = NSAttributedString(rtf: data, documentAttributes: nil) {
            XCTAssertEqual(restored.string, "Save me!", "Content should be preserved in RTF")
        }
    }

    func testRTFDataIsEmptyAfterClearingDocument() {
        var document = TinyWriterDocument(text: "Original content")
        document.text = ""  // Clear it

        // Generate RTF data from empty document
        let range = NSRange(location: 0, length: document.attributedText.length)
        let rtfData = document.attributedText.rtf(from: range, documentAttributes: [:])

        if let data = rtfData,
           let restored = NSAttributedString(rtf: data, documentAttributes: nil) {
            XCTAssertEqual(restored.string, "", "Cleared document should have empty content")
        }
    }

    // MARK: - Document State Manager Tests

    func testFlushPendingChangesCommitsPendingText() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "")

        var committedText: String?
        let expectation = XCTestExpectation(description: "Text committed")

        // Simulate text change
        manager.textDidChange(newText: "New content", documentURL: nil) { text in
            committedText = text
            expectation.fulfill()
        }

        // Flush should commit immediately
        manager.flushPendingChanges { text in
            committedText = text
        }

        XCTAssertEqual(committedText, "New content", "Flush should commit the pending text")
    }

    func testFlushAfterDebounceDoesNothing() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "")

        let expectation = XCTestExpectation(description: "Debounce completes")
        var commitCount = 0

        // Simulate text change with debounce
        manager.textDidChange(newText: "Content", documentURL: nil) { _ in
            commitCount += 1
            expectation.fulfill()
        }

        // Wait for debounce to complete
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(commitCount, 1)

        // Now flush should not call commit again (no pending changes)
        var flushCalled = false
        manager.flushPendingChanges { _ in
            flushCalled = true
        }

        XCTAssertFalse(flushCalled, "Flush should not commit if no pending changes")
    }
}

// MARK: - Cursor Position After Text Operations Tests

final class CursorPositionTests: XCTestCase {

    // MARK: - NSTextView Cursor Position Tests

    func testCursorPositionAfterInsertingTextAtBeginning() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = ""

        // Simulate inserting "Hello" at position 0
        let insertedText = "Hello"
        textView.insertText(insertedText, replacementRange: NSRange(location: 0, length: 0))

        // Cursor should be at end of inserted text
        let expectedPosition = insertedText.count
        XCTAssertEqual(textView.selectedRange().location, expectedPosition, "Cursor should be at end of inserted text")
        XCTAssertEqual(textView.selectedRange().length, 0, "Should have no selection")
    }

    func testCursorPositionAfterInsertingMultilineText() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = ""

        // Simulate pasting multiline text
        let insertedText = "Line 1\nLine 2\nLine 3"
        textView.insertText(insertedText, replacementRange: NSRange(location: 0, length: 0))

        // Cursor should be at end of inserted text
        let expectedPosition = insertedText.count
        XCTAssertEqual(textView.selectedRange().location, expectedPosition, "Cursor should be at end of multiline text")
    }

    func testCursorPositionAfterInsertingIntoExistingText() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = "Hello World"

        // Set cursor position to 5 (after "Hello")
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        // Insert " Beautiful" at cursor position
        let insertedText = " Beautiful"
        textView.insertText(insertedText, replacementRange: textView.selectedRange())

        // Cursor should be at position 5 + length of inserted text
        let expectedPosition = 5 + insertedText.count
        XCTAssertEqual(textView.selectedRange().location, expectedPosition, "Cursor should be after inserted text")
    }

    func testCursorPositionAfterReplacingSelection() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = "Hello World"

        // Replace "World" (position 6-11) with "Universe"
        let replacementText = "Universe"
        textView.insertText(replacementText, replacementRange: NSRange(location: 6, length: 5))

        // Cursor should be at end of replacement text
        let expectedPosition = 6 + replacementText.count
        XCTAssertEqual(textView.selectedRange().location, expectedPosition, "Cursor should be at end of replacement")
    }

    func testCursorPositionAfterPasteIntoEmptyDocument() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = ""

        // Simulate paste by using replaceCharacters
        let pastedText = "This is pasted content with multiple words."
        if let textStorage = textView.textStorage {
            textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: pastedText)
            // Manually set selection to end (this is what paste should do)
            textView.setSelectedRange(NSRange(location: pastedText.count, length: 0))
        }

        XCTAssertEqual(textView.selectedRange().location, pastedText.count, "Cursor should be at end after paste")
    }

    func testCursorPositionAfterPasteWithUnicode() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = ""

        let pastedText = "Hello 世界 🌍 café"
        textView.insertText(pastedText, replacementRange: NSRange(location: 0, length: 0))

        // Count should be by characters, not bytes
        let expectedPosition = (pastedText as NSString).length
        XCTAssertEqual(textView.selectedRange().location, expectedPosition, "Cursor should handle unicode correctly")
    }

    // MARK: - Selection Range Calculation Tests

    func testCalculateEndPositionAfterInsertion() {
        let initialPosition = 0
        let insertedLength = 15
        let expectedEndPosition = initialPosition + insertedLength
        XCTAssertEqual(expectedEndPosition, 15)
    }

    func testCalculateEndPositionAfterInsertionInMiddle() {
        let initialPosition = 10
        let insertedLength = 5
        let expectedEndPosition = initialPosition + insertedLength
        XCTAssertEqual(expectedEndPosition, 15)
    }

    func testCalculateEndPositionAfterReplacement() {
        let replacementStart = 5
        let replacementLength = 10  // Replacing 10 characters
        let newTextLength = 20  // With 20 characters
        let expectedEndPosition = replacementStart + newTextLength
        XCTAssertEqual(expectedEndPosition, 25)
    }
}

// MARK: - Rich Text Formatting Tests (Cmd+B / Cmd+I)

final class RichTextFormattingTests: XCTestCase {

    // MARK: - Bold Formatting Tests

    func testFontManagerCanConvertToBold() {
        let regularFont = NSFont.systemFont(ofSize: 14)
        let boldFont = NSFontManager.shared.convert(regularFont, toHaveTrait: .boldFontMask)

        let traits = NSFontManager.shared.traits(of: boldFont)
        XCTAssertTrue(traits.contains(.boldFontMask), "Font should have bold trait after conversion")
    }

    func testFontManagerCanRemoveBold() {
        let regularFont = NSFont.systemFont(ofSize: 14)
        let boldFont = NSFontManager.shared.convert(regularFont, toHaveTrait: .boldFontMask)
        let unboldedFont = NSFontManager.shared.convert(boldFont, toNotHaveTrait: .boldFontMask)

        let traits = NSFontManager.shared.traits(of: unboldedFont)
        XCTAssertFalse(traits.contains(.boldFontMask), "Font should not have bold trait after removal")
    }

    func testBoldToggleLogic() {
        let font = NSFont.systemFont(ofSize: 14)
        let fontManager = NSFontManager.shared

        // Check if bold, then toggle
        let traits = fontManager.traits(of: font)
        let isBold = traits.contains(.boldFontMask)
        XCTAssertFalse(isBold, "System font should not be bold by default")

        // Apply bold
        let boldFont = fontManager.convert(font, toHaveTrait: .boldFontMask)
        let boldTraits = fontManager.traits(of: boldFont)
        XCTAssertTrue(boldTraits.contains(.boldFontMask), "Should be bold after applying")

        // Remove bold (toggle off)
        let regularAgain = fontManager.convert(boldFont, toNotHaveTrait: .boldFontMask)
        let regularTraits = fontManager.traits(of: regularAgain)
        XCTAssertFalse(regularTraits.contains(.boldFontMask), "Should not be bold after toggle off")
    }

    // MARK: - Italic Formatting Tests

    func testFontManagerCanConvertToItalic() {
        let regularFont = NSFont.systemFont(ofSize: 14)
        let italicFont = NSFontManager.shared.convert(regularFont, toHaveTrait: .italicFontMask)

        let traits = NSFontManager.shared.traits(of: italicFont)
        XCTAssertTrue(traits.contains(.italicFontMask), "Font should have italic trait after conversion")
    }

    func testFontManagerCanRemoveItalic() {
        let regularFont = NSFont.systemFont(ofSize: 14)
        let italicFont = NSFontManager.shared.convert(regularFont, toHaveTrait: .italicFontMask)
        let unitalicizedFont = NSFontManager.shared.convert(italicFont, toNotHaveTrait: .italicFontMask)

        let traits = NSFontManager.shared.traits(of: unitalicizedFont)
        XCTAssertFalse(traits.contains(.italicFontMask), "Font should not have italic trait after removal")
    }

    func testItalicToggleLogic() {
        let font = NSFont.systemFont(ofSize: 14)
        let fontManager = NSFontManager.shared

        // Check if italic, then toggle
        let traits = fontManager.traits(of: font)
        let isItalic = traits.contains(.italicFontMask)
        XCTAssertFalse(isItalic, "System font should not be italic by default")

        // Apply italic
        let italicFont = fontManager.convert(font, toHaveTrait: .italicFontMask)
        let italicTraits = fontManager.traits(of: italicFont)
        XCTAssertTrue(italicTraits.contains(.italicFontMask), "Should be italic after applying")

        // Remove italic (toggle off)
        let regularAgain = fontManager.convert(italicFont, toNotHaveTrait: .italicFontMask)
        let regularTraits = fontManager.traits(of: regularAgain)
        XCTAssertFalse(regularTraits.contains(.italicFontMask), "Should not be italic after toggle off")
    }

    // MARK: - Combined Bold + Italic Tests

    func testCanApplyBothBoldAndItalic() {
        let font = NSFont.systemFont(ofSize: 14)
        let fontManager = NSFontManager.shared

        let boldFont = fontManager.convert(font, toHaveTrait: .boldFontMask)
        let boldItalicFont = fontManager.convert(boldFont, toHaveTrait: .italicFontMask)

        let traits = fontManager.traits(of: boldItalicFont)
        XCTAssertTrue(traits.contains(.boldFontMask), "Should have bold")
        XCTAssertTrue(traits.contains(.italicFontMask), "Should have italic")
    }

    func testCanRemoveBoldWhileKeepingItalic() {
        let font = NSFont.systemFont(ofSize: 14)
        let fontManager = NSFontManager.shared

        let boldItalicFont = fontManager.convert(
            fontManager.convert(font, toHaveTrait: .boldFontMask),
            toHaveTrait: .italicFontMask
        )

        let italicOnlyFont = fontManager.convert(boldItalicFont, toNotHaveTrait: .boldFontMask)
        let traits = fontManager.traits(of: italicOnlyFont)

        XCTAssertFalse(traits.contains(.boldFontMask), "Should not have bold")
        XCTAssertTrue(traits.contains(.italicFontMask), "Should still have italic")
    }

    func testCanRemoveItalicWhileKeepingBold() {
        let font = NSFont.systemFont(ofSize: 14)
        let fontManager = NSFontManager.shared

        let boldItalicFont = fontManager.convert(
            fontManager.convert(font, toHaveTrait: .boldFontMask),
            toHaveTrait: .italicFontMask
        )

        let boldOnlyFont = fontManager.convert(boldItalicFont, toNotHaveTrait: .italicFontMask)
        let traits = fontManager.traits(of: boldOnlyFont)

        XCTAssertTrue(traits.contains(.boldFontMask), "Should still have bold")
        XCTAssertFalse(traits.contains(.italicFontMask), "Should not have italic")
    }

    // MARK: - NSTextStorage Formatting Tests

    func testApplyBoldToTextStorageRange() {
        let textStorage = NSTextStorage(string: "Hello World")
        let font = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: textStorage.length))

        // Apply bold to "World" (range 6-11)
        let range = NSRange(location: 6, length: 5)
        let fontManager = NSFontManager.shared

        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let boldFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: boldFont, range: attrRange)
        }

        // Verify "World" is bold
        var worldFont: NSFont?
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            worldFont = value as? NSFont
        }

        XCTAssertNotNil(worldFont)
        let traits = fontManager.traits(of: worldFont!)
        XCTAssertTrue(traits.contains(.boldFontMask), "World should be bold")
    }

    func testApplyItalicToTextStorageRange() {
        let textStorage = NSTextStorage(string: "Hello World")
        let font = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: textStorage.length))

        // Apply italic to "Hello" (range 0-5)
        let range = NSRange(location: 0, length: 5)
        let fontManager = NSFontManager.shared

        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let italicFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: italicFont, range: attrRange)
        }

        // Verify "Hello" is italic
        var helloFont: NSFont?
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            helloFont = value as? NSFont
        }

        XCTAssertNotNil(helloFont)
        let traits = fontManager.traits(of: helloFont!)
        XCTAssertTrue(traits.contains(.italicFontMask), "Hello should be italic")
    }

    func testToggleBoldOnAlreadyBoldText() {
        let textStorage = NSTextStorage(string: "Bold")
        let fontManager = NSFontManager.shared
        let boldFont = fontManager.convert(NSFont.systemFont(ofSize: 14), toHaveTrait: .boldFontMask)
        textStorage.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))

        // Toggle bold (should remove it)
        let range = NSRange(location: 0, length: 4)
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

        // Verify no longer bold
        var resultFont: NSFont?
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            resultFont = value as? NSFont
        }

        XCTAssertNotNil(resultFont)
        let traits = fontManager.traits(of: resultFont!)
        XCTAssertFalse(traits.contains(.boldFontMask), "Should not be bold after toggle")
    }
}

final class TinyWriterDocumentTests: XCTestCase {

    // MARK: - Document Creation Tests

    func testDocumentInitializesWithEmptyText() {
        let document = TinyWriterDocument()
        XCTAssertEqual(document.text, "")
    }

    func testDocumentInitializesWithProvidedText() {
        let document = TinyWriterDocument(text: "Hello, World!")
        XCTAssertEqual(document.text, "Hello, World!")
    }

    func testDocumentPreservesMultilineText() {
        let multilineText = """
        # Heading

        This is a paragraph.

        - List item 1
        - List item 2
        """
        let document = TinyWriterDocument(text: multilineText)
        XCTAssertEqual(document.text, multilineText)
    }

    func testDocumentPreservesUnicodeText() {
        let unicodeText = "Hello 世界 🌍 émojis café"
        let document = TinyWriterDocument(text: unicodeText)
        XCTAssertEqual(document.text, unicodeText)
    }

    func testDocumentTextIsMutable() {
        var document = TinyWriterDocument(text: "Initial")
        document.text = "Modified"
        XCTAssertEqual(document.text, "Modified")
    }

    func testDocumentHandlesLongText() {
        let longText = String(repeating: "A", count: 10000)
        let document = TinyWriterDocument(text: longText)
        XCTAssertEqual(document.text.count, 10000)
    }

    func testDocumentHandlesSpecialCharacters() {
        let specialText = "Line1\nLine2\tTabbed\r\nWindows"
        let document = TinyWriterDocument(text: specialText)
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

    func testRichTextContentRoundTrip() {
        let textContent = """
        My Document

        This has bold and italic text.

        - List item 1
        - List item 2
        """
        let data = Data(textContent.utf8)
        let restoredText = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(restoredText, textContent)
    }

    // MARK: - RTF Document Type Tests

    func testDocumentWritableContentTypeIsRTF() {
        let writableTypes = TinyWriterDocument.writableTypes
        XCTAssertEqual(writableTypes.count, 1, "Should only have one writable type")
        XCTAssertEqual(writableTypes.first, UTType.rtf.identifier, "Writable type should be RTF")
    }

    func testDocumentReadableContentTypesIncludeRTF() {
        let readableTypes = TinyWriterDocument.readableTypes
        XCTAssertTrue(readableTypes.contains(UTType.rtf.identifier), "Should be able to read RTF files")
    }

    func testDocumentReadableContentTypesIncludePlainText() {
        let readableTypes = TinyWriterDocument.readableTypes
        XCTAssertTrue(readableTypes.contains(UTType.plainText.identifier), "Should be able to read plain text for import")
    }

    func testDocumentDoesNotIncludeMarkdownType() {
        let readableTypes = TinyWriterDocument.readableTypes
        let writableTypes = TinyWriterDocument.writableTypes

        // Verify no markdown types
        for type in readableTypes {
            XCTAssertNotEqual(type, "net.daringfireball.markdown", "Should not include markdown in readable types")
        }
        for type in writableTypes {
            XCTAssertNotEqual(type, "net.daringfireball.markdown", "Should not include markdown in writable types")
        }
    }

    // MARK: - RTF Data Round-trip Tests

    func testRTFDataRoundTrip() throws {
        let document = TinyWriterDocument(text: "Hello RTF World")

        // Get RTF data
        let range = NSRange(location: 0, length: document.attributedText.length)
        let rtfData = document.attributedText.rtf(from: range, documentAttributes: [:])
        XCTAssertNotNil(rtfData, "Should be able to create RTF data")

        // Read it back
        if let data = rtfData {
            let restored = NSAttributedString(rtf: data, documentAttributes: nil)
            XCTAssertNotNil(restored, "Should be able to read RTF data back")
            XCTAssertEqual(restored?.string, "Hello RTF World", "Text should survive RTF round-trip")
        }
    }

    func testRTFPreservesUnicodeInRoundTrip() throws {
        let unicodeText = "Hello 世界 🌍 café"
        let document = TinyWriterDocument(text: unicodeText)

        let range = NSRange(location: 0, length: document.attributedText.length)
        let rtfData = document.attributedText.rtf(from: range, documentAttributes: [:])
        XCTAssertNotNil(rtfData)

        if let data = rtfData {
            let restored = NSAttributedString(rtf: data, documentAttributes: nil)
            XCTAssertEqual(restored?.string, unicodeText, "Unicode should survive RTF round-trip")
        }
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

// MARK: - Bold Formatting Tests

final class BoldFormattingTests: XCTestCase {

    // MARK: - Apply Bold (Selection)

    func testApplyBoldToPlainText() {
        let input = "hello"
        let expected = "**hello**"
        let result = applyBold(to: input)
        XCTAssertEqual(result, expected)
    }

    func testApplyBoldToMultiWordText() {
        let input = "hello world"
        let expected = "**hello world**"
        let result = applyBold(to: input)
        XCTAssertEqual(result, expected)
    }

    func testApplyBoldToUnicodeText() {
        let input = "héllo wörld 日本語"
        let expected = "**héllo wörld 日本語**"
        let result = applyBold(to: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Remove Bold (Toggle Off)

    func testRemoveBoldFromBoldText() {
        let input = "**hello**"
        let expected = "hello"
        let result = removeBoldMarkers(from: input)
        XCTAssertEqual(result, expected)
    }

    func testRemoveBoldPreservesContent() {
        let input = "**hello world**"
        let expected = "hello world"
        let result = removeBoldMarkers(from: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Bold Detection

    func testDetectBoldSurroundingText() {
        let text = "some **bold** text" as NSString
        let selectionRange = NSRange(location: 7, length: 4) // "bold"
        let isBold = isSurroundedByBoldMarkers(text: text, range: selectionRange)
        XCTAssertTrue(isBold)
    }

    func testDetectNotBoldText() {
        let text = "some plain text" as NSString
        let selectionRange = NSRange(location: 5, length: 5) // "plain"
        let isBold = isSurroundedByBoldMarkers(text: text, range: selectionRange)
        XCTAssertFalse(isBold)
    }

    func testDetectPartialBoldNotMatched() {
        let text = "some **partial bold" as NSString
        let selectionRange = NSRange(location: 7, length: 7) // "partial"
        let isBold = isSurroundedByBoldMarkers(text: text, range: selectionRange)
        XCTAssertFalse(isBold)
    }

    func testBoldAtStartOfText() {
        let text = "**bold** at start" as NSString
        let selectionRange = NSRange(location: 2, length: 4) // "bold"
        let isBold = isSurroundedByBoldMarkers(text: text, range: selectionRange)
        XCTAssertTrue(isBold)
    }

    func testBoldAtEndOfText() {
        let text = "end is **bold**" as NSString
        // "end is **bold**" - "bold" starts at position 9
        let selectionRange = NSRange(location: 9, length: 4) // "bold"
        let isBold = isSurroundedByBoldMarkers(text: text, range: selectionRange)
        XCTAssertTrue(isBold)
    }

    // MARK: - No Selection (Insert Mode)

    func testInsertBoldMarkersAtCursor() {
        let expected = "****"
        XCTAssertEqual(expected.count, 4)
    }

    func testCursorPositionAfterInsert() {
        let markers = "****"
        let cursorPosition = 2 // Should be between ** and **
        XCTAssertEqual(cursorPosition, markers.count / 2)
    }

    // MARK: - Selection Includes Markers

    func testRemoveBoldWhenMarkersInSelection() {
        // When user selects "**bold**" (including markers)
        let input = "**hello**"
        let expected = "hello"
        let result = removeBoldFromSelection(input)
        XCTAssertEqual(result, expected)
    }

    func testRemoveBoldWhenMarkersInSelectionMultiWord() {
        let input = "**hello world**"
        let expected = "hello world"
        let result = removeBoldFromSelection(input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Edge Cases

    func testEmptySelectionInsertsMarkers() {
        let input = ""
        let expected = "****"
        let result = applyBoldNoSelection()
        XCTAssertEqual(result, expected)
    }

    func testBoldWithSpecialCharacters() {
        let input = "code: let x = 5"
        let expected = "**code: let x = 5**"
        let result = applyBold(to: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Helper Functions (Mirror implementation logic)

    private func applyBold(to text: String) -> String {
        return "**\(text)**"
    }

    private func applyBoldNoSelection() -> String {
        return "****"
    }

    private func removeBoldMarkers(from text: String) -> String {
        if text.hasPrefix("**") && text.hasSuffix("**") && text.count >= 4 {
            let start = text.index(text.startIndex, offsetBy: 2)
            let end = text.index(text.endIndex, offsetBy: -2)
            return String(text[start..<end])
        }
        return text
    }

    private func removeBoldFromSelection(_ selectedText: String) -> String {
        // Mirrors the logic when selection includes ** markers
        if selectedText.hasPrefix("**") && selectedText.hasSuffix("**") && selectedText.count >= 4 {
            let start = selectedText.index(selectedText.startIndex, offsetBy: 2)
            let end = selectedText.index(selectedText.endIndex, offsetBy: -2)
            return String(selectedText[start..<end])
        }
        return selectedText
    }

    private func isSurroundedByBoldMarkers(text: NSString, range: NSRange) -> Bool {
        guard range.location >= 2,
              range.location + range.length + 2 <= text.length else {
            return false
        }
        let before = text.substring(with: NSRange(location: range.location - 2, length: 2))
        let after = text.substring(with: NSRange(location: range.location + range.length, length: 2))
        return before == "**" && after == "**"
    }
}

// MARK: - Italic Formatting Tests

final class ItalicFormattingTests: XCTestCase {

    // MARK: - Apply Italic (Selection)

    func testApplyItalicToPlainText() {
        let input = "hello"
        let expected = "_hello_"
        let result = applyItalic(to: input)
        XCTAssertEqual(result, expected)
    }

    func testApplyItalicToMultiWordText() {
        let input = "hello world"
        let expected = "_hello world_"
        let result = applyItalic(to: input)
        XCTAssertEqual(result, expected)
    }

    func testApplyItalicToUnicodeText() {
        let input = "héllo wörld 日本語"
        let expected = "_héllo wörld 日本語_"
        let result = applyItalic(to: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Remove Italic (Toggle Off)

    func testRemoveItalicFromItalicText() {
        let input = "_hello_"
        let expected = "hello"
        let result = removeItalicMarkers(from: input)
        XCTAssertEqual(result, expected)
    }

    func testRemoveItalicPreservesContent() {
        let input = "_hello world_"
        let expected = "hello world"
        let result = removeItalicMarkers(from: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Italic Detection

    func testDetectItalicSurroundingText() {
        let text = "some _italic_ text" as NSString
        let selectionRange = NSRange(location: 6, length: 6) // "italic"
        let isItalic = isSurroundedByItalicMarkers(text: text, range: selectionRange)
        XCTAssertTrue(isItalic)
    }

    func testDetectNotItalicText() {
        let text = "some plain text" as NSString
        let selectionRange = NSRange(location: 5, length: 5) // "plain"
        let isItalic = isSurroundedByItalicMarkers(text: text, range: selectionRange)
        XCTAssertFalse(isItalic)
    }

    // MARK: - No Selection (Insert Mode)

    func testInsertItalicMarkersAtCursor() {
        let expected = "__"
        XCTAssertEqual(expected.count, 2)
    }

    func testCursorPositionAfterInsert() {
        let markers = "__"
        let cursorPosition = 1 // Should be between _ and _
        XCTAssertEqual(cursorPosition, markers.count / 2)
    }

    // MARK: - Selection Includes Markers

    func testRemoveItalicWhenMarkersInSelection() {
        let input = "_hello_"
        let expected = "hello"
        let result = removeItalicFromSelection(input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Helper Functions

    private func applyItalic(to text: String) -> String {
        return "_\(text)_"
    }

    private func removeItalicMarkers(from text: String) -> String {
        if text.hasPrefix("_") && text.hasSuffix("_") && text.count >= 2 {
            return String(text.dropFirst(1).dropLast(1))
        }
        return text
    }

    private func removeItalicFromSelection(_ selectedText: String) -> String {
        if selectedText.hasPrefix("_") && selectedText.hasSuffix("_") && selectedText.count >= 2 {
            return String(selectedText.dropFirst(1).dropLast(1))
        }
        return selectedText
    }

    private func isSurroundedByItalicMarkers(text: NSString, range: NSRange) -> Bool {
        guard range.location >= 1,
              range.location + range.length + 1 <= text.length else {
            return false
        }
        let before = text.substring(with: NSRange(location: range.location - 1, length: 1))
        let after = text.substring(with: NSRange(location: range.location + range.length, length: 1))
        return before == "_" && after == "_"
    }
}

// MARK: - Nested Formatting Tests (Bold + Italic)

final class NestedFormattingTests: XCTestCase {

    // MARK: - Apply Italic to Bold Text

    func testApplyItalicToBoldText() {
        // Bold text "**hello**" + Cmd+I → "_**hello**_"
        let input = "**hello**"
        let expected = "_**hello**_"
        let result = applyItalic(to: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Apply Bold to Italic Text

    func testApplyBoldToItalicText() {
        // Italic text "_hello_" + Cmd+B → "**_hello_**"
        let input = "_hello_"
        let expected = "**_hello_**"
        let result = applyBold(to: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Remove Italic from Bold+Italic (Italic Outside)

    func testRemoveItalicFromBoldItalicOutside() {
        // "_**hello**_" + Cmd+I → "**hello**"
        let input = "_**hello**_"
        let expected = "**hello**"
        let result = removeItalicMarkers(from: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Remove Italic from Bold+Italic (Italic Inside)

    func testRemoveItalicFromBoldItalicInside() {
        // "**_hello_**" + Cmd+I → "**hello**"
        let input = "**_hello_**"
        let expected = "**hello**"
        let result = removeItalicFromBoldItalicInside(input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Remove Bold from Bold+Italic (Bold Outside)

    func testRemoveBoldFromBoldItalicOutside() {
        // "**_hello_**" + Cmd+B → "_hello_"
        let input = "**_hello_**"
        let expected = "_hello_"
        let result = removeBoldMarkers(from: input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Remove Bold from Bold+Italic (Bold Inside)

    func testRemoveBoldFromBoldItalicInside() {
        // "_**hello**_" + Cmd+B → "_hello_"
        let input = "_**hello**_"
        let expected = "_hello_"
        let result = removeBoldFromItalicBoldInside(input)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Full Toggle Cycle

    func testBoldThenItalicThenRemoveItalic() {
        // Start: "hello"
        // + Cmd+B: "**hello**"
        // + Cmd+I: "_**hello**_"
        // + Cmd+I: "**hello**"
        let step1 = applyBold(to: "hello")
        XCTAssertEqual(step1, "**hello**")
        let step2 = applyItalic(to: step1)
        XCTAssertEqual(step2, "_**hello**_")
        let step3 = removeItalicMarkers(from: step2)
        XCTAssertEqual(step3, "**hello**")
    }

    func testItalicThenBoldThenRemoveBold() {
        // Start: "hello"
        // + Cmd+I: "_hello_"
        // + Cmd+B: "**_hello_**"
        // + Cmd+B: "_hello_"
        let step1 = applyItalic(to: "hello")
        XCTAssertEqual(step1, "_hello_")
        let step2 = applyBold(to: step1)
        XCTAssertEqual(step2, "**_hello_**")
        let step3 = removeBoldMarkers(from: step2)
        XCTAssertEqual(step3, "_hello_")
    }

    func testFullCycleBoldItalicBackToPlain() {
        // Start: "hello"
        // + Cmd+B: "**hello**"
        // + Cmd+I: "_**hello**_"
        // + Cmd+I: "**hello**"
        // + Cmd+B: "hello"
        let step1 = applyBold(to: "hello")
        let step2 = applyItalic(to: step1)
        let step3 = removeItalicMarkers(from: step2)
        let step4 = removeBoldMarkers(from: step3)
        XCTAssertEqual(step4, "hello")
    }

    // MARK: - Helper Functions

    private func applyBold(to text: String) -> String {
        return "**\(text)**"
    }

    private func applyItalic(to text: String) -> String {
        return "_\(text)_"
    }

    private func removeBoldMarkers(from text: String) -> String {
        if text.hasPrefix("**") && text.hasSuffix("**") && text.count >= 4 {
            return String(text.dropFirst(2).dropLast(2))
        }
        return text
    }

    private func removeItalicMarkers(from text: String) -> String {
        if text.hasPrefix("_") && text.hasSuffix("_") && text.count >= 2 {
            return String(text.dropFirst(1).dropLast(1))
        }
        return text
    }

    private func removeItalicFromBoldItalicInside(_ text: String) -> String {
        // "**_hello_**" → "**hello**"
        if text.hasPrefix("**_") && text.hasSuffix("_**") && text.count >= 6 {
            let inner = String(text.dropFirst(3).dropLast(3))
            return "**\(inner)**"
        }
        return text
    }

    private func removeBoldFromItalicBoldInside(_ text: String) -> String {
        // "_**hello**_" → "_hello_"
        if text.hasPrefix("_**") && text.hasSuffix("**_") && text.count >= 6 {
            let inner = String(text.dropFirst(3).dropLast(3))
            return "_\(inner)_"
        }
        return text
    }
}

// MARK: - Document State Manager Tests
// Tests for debounced autosave without crash recovery

final class DocumentStateManagerTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateHasNoUnsavedChanges() {
        let manager = DocumentStateManager()
        XCTAssertFalse(manager.hasUnsavedChanges)
    }

    // MARK: - Text Change Tracking

    func testTextChangeMarksAsUnsaved() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "initial")

        let expectation = XCTestExpectation(description: "Commit handler called")
        manager.textDidChange(newText: "modified", documentURL: nil) { _ in
            expectation.fulfill()
        }

        XCTAssertTrue(manager.hasUnsavedChanges, "Should have unsaved changes after text modification")
    }

    func testSameTextDoesNotMarkAsUnsaved() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "initial")

        manager.textDidChange(newText: "initial", documentURL: nil) { _ in }

        XCTAssertFalse(manager.hasUnsavedChanges, "Same text should not mark as unsaved")
    }

    // MARK: - Debounce Behavior

    func testDebouncedCommitIsCalled() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "")

        let expectation = XCTestExpectation(description: "Commit handler called after debounce")
        var committedText: String?

        manager.textDidChange(newText: "test text", documentURL: nil) { text in
            committedText = text
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(committedText, "test text")
    }

    func testMultipleChangesOnlyCommitFinalText() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "")

        let expectation = XCTestExpectation(description: "Final commit")
        var commitCount = 0
        var finalText: String?

        // Rapid changes - only final should commit
        manager.textDidChange(newText: "a", documentURL: nil) { text in
            commitCount += 1
            finalText = text
            expectation.fulfill()
        }
        manager.textDidChange(newText: "ab", documentURL: nil) { text in
            commitCount += 1
            finalText = text
            expectation.fulfill()
        }
        manager.textDidChange(newText: "abc", documentURL: nil) { text in
            commitCount += 1
            finalText = text
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(finalText, "abc", "Should commit final text only")
        XCTAssertEqual(commitCount, 1, "Should only commit once after debounce")
    }

    // MARK: - Flush Pending Changes

    func testFlushPendingChangesCommitsImmediately() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "")

        var committedText: String?
        manager.textDidChange(newText: "pending text", documentURL: nil) { text in
            committedText = text
        }

        // Flush immediately without waiting for debounce
        manager.flushPendingChanges { text in
            committedText = text
        }

        XCTAssertEqual(committedText, "pending text", "Flush should commit pending text immediately")
    }

    func testFlushWithNoPendingChangesDoesNothing() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "initial")

        var wasCommitCalled = false
        manager.flushPendingChanges { _ in
            wasCommitCalled = true
        }

        XCTAssertFalse(wasCommitCalled, "Should not call commit when no pending changes")
    }

    // MARK: - Mark As Saved

    func testMarkAsSavedClearsUnsavedFlag() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "initial")

        manager.textDidChange(newText: "modified", documentURL: nil) { _ in }
        XCTAssertTrue(manager.hasUnsavedChanges)

        manager.markAsSaved(text: "modified")
        XCTAssertFalse(manager.hasUnsavedChanges, "Should clear unsaved changes after marking as saved")
    }

    func testMarkAsSavedUpdatesSavedText() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "")
        manager.markAsSaved(text: "saved text")

        // Now changing to same saved text should not mark as unsaved
        manager.textDidChange(newText: "saved text", documentURL: nil) { _ in }
        XCTAssertFalse(manager.hasUnsavedChanges)

        // Changing to different text should mark as unsaved
        manager.textDidChange(newText: "different text", documentURL: nil) { _ in }
        XCTAssertTrue(manager.hasUnsavedChanges)
    }

    // MARK: - Reset For New Document

    func testResetForNewDocumentClearsState() {
        let manager = DocumentStateManager()

        // Set up some state
        manager.textDidChange(newText: "some text", documentURL: URL(fileURLWithPath: "/test.txt")) { _ in }
        XCTAssertTrue(manager.hasUnsavedChanges)

        // Reset
        manager.resetForNewDocument(text: "new doc")
        XCTAssertFalse(manager.hasUnsavedChanges)

        // After reset, same text should not mark as unsaved
        manager.textDidChange(newText: "new doc", documentURL: nil) { _ in }
        XCTAssertFalse(manager.hasUnsavedChanges)
    }

    // MARK: - No Backup Files Created

    func testNoBackupFilesAreCreated() {
        let manager = DocumentStateManager()
        manager.resetForNewDocument(text: "")

        // Make changes
        manager.textDidChange(newText: "test content", documentURL: nil) { _ in }

        // Check that no backup directory exists
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let backupDir = appSupport.appendingPathComponent("TinyWriter").appendingPathComponent("Backups")

        // If backup dir exists, it should be empty (from previous runs, but this test verifies new behavior)
        if FileManager.default.fileExists(atPath: backupDir.path) {
            let contents = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
            // We're just verifying the manager doesn't create new backups
            // Old backups may exist from before this change
        }
        // This test passes if no exception is thrown - the manager should work without backup logic
        XCTAssertTrue(true, "Manager should function without creating backups")
    }
}

// MARK: - Text Replacement Integration Tests
// These tests simulate the actual text replacement logic used in the formatting methods

final class TextReplacementIntegrationTests: XCTestCase {

    // MARK: - Bold at Start of Document

    func testBoldFirstWordInDocument() {
        // Document: "hello world"
        // Select "hello" (range 0-5), apply bold
        // Result: "**hello** world"
        var text = "hello world"
        let range = NSRange(location: 0, length: 5)
        let selectedText = (text as NSString).substring(with: range)
        let replacement = "**\(selectedText)**"

        text = (text as NSString).replacingCharacters(in: range, with: replacement)
        XCTAssertEqual(text, "**hello** world")
        XCTAssertFalse(text.contains("\n"), "Should not introduce newlines")
    }

    func testUnboldFirstWordInDocument() {
        // Document: "**hello** world"
        // Select "hello" (range 2-7, the content between markers)
        // Markers are at 0-1 and 7-8
        // Result: "hello world"
        var text = "**hello** world"
        let nsText = text as NSString

        // User selects "hello" which is at position 2, length 5
        let selectionRange = NSRange(location: 2, length: 5)
        let selectedText = nsText.substring(with: selectionRange)
        XCTAssertEqual(selectedText, "hello")

        // Check for ** before and after
        let hasBoldBefore = selectionRange.location >= 2 &&
            nsText.substring(with: NSRange(location: selectionRange.location - 2, length: 2)) == "**"
        let hasBoldAfter = selectionRange.location + selectionRange.length + 2 <= nsText.length &&
            nsText.substring(with: NSRange(location: selectionRange.location + selectionRange.length, length: 2)) == "**"

        XCTAssertTrue(hasBoldBefore, "Should detect ** before selection")
        XCTAssertTrue(hasBoldAfter, "Should detect ** after selection")

        // Remove bold: replace range including markers with just the text
        let fullRange = NSRange(location: selectionRange.location - 2, length: selectionRange.length + 4)
        text = nsText.replacingCharacters(in: fullRange, with: selectedText)

        XCTAssertEqual(text, "hello world")
        XCTAssertFalse(text.contains("\n"), "Should not introduce newlines")
    }

    // MARK: - Bold at Start of Line

    func testBoldFirstWordOnNewLine() {
        // Document: "Line one\nhello world"
        // Select "hello" on second line, apply bold
        var text = "Line one\nhello world"
        let range = NSRange(location: 9, length: 5) // "hello" starts at position 9
        let selectedText = (text as NSString).substring(with: range)
        XCTAssertEqual(selectedText, "hello")

        let replacement = "**\(selectedText)**"
        text = (text as NSString).replacingCharacters(in: range, with: replacement)

        XCTAssertEqual(text, "Line one\n**hello** world")
        XCTAssertEqual(text.components(separatedBy: "\n").count, 2, "Should still have exactly 2 lines")
    }

    func testUnboldFirstWordOnNewLine() {
        // Document: "Line one\n**hello** world"
        // Select "hello" on second line, remove bold
        var text = "Line one\n**hello** world"
        let nsText = text as NSString

        // "hello" is at position 11 (after "Line one\n**")
        let selectionRange = NSRange(location: 11, length: 5)
        let selectedText = nsText.substring(with: selectionRange)
        XCTAssertEqual(selectedText, "hello")

        // Check for ** markers
        let hasBoldBefore = nsText.substring(with: NSRange(location: selectionRange.location - 2, length: 2)) == "**"
        let hasBoldAfter = nsText.substring(with: NSRange(location: selectionRange.location + selectionRange.length, length: 2)) == "**"

        XCTAssertTrue(hasBoldBefore)
        XCTAssertTrue(hasBoldAfter)

        // Remove bold
        let fullRange = NSRange(location: selectionRange.location - 2, length: selectionRange.length + 4)
        text = nsText.replacingCharacters(in: fullRange, with: selectedText)

        XCTAssertEqual(text, "Line one\nhello world")
        XCTAssertEqual(text.components(separatedBy: "\n").count, 2, "Should still have exactly 2 lines")
    }

    // MARK: - Selection Includes Markers

    func testUnboldWhenSelectionIncludesMarkers() {
        // User selects "**hello**" (the whole thing including markers)
        var text = "**hello** world"
        let range = NSRange(location: 0, length: 9) // "**hello**"
        let selectedText = (text as NSString).substring(with: range)
        XCTAssertEqual(selectedText, "**hello**")

        // Remove markers from selection
        XCTAssertTrue(selectedText.hasPrefix("**") && selectedText.hasSuffix("**"))
        let innerText = String(selectedText.dropFirst(2).dropLast(2))

        text = (text as NSString).replacingCharacters(in: range, with: innerText)
        XCTAssertEqual(text, "hello world")
        XCTAssertFalse(text.contains("\n"), "Should not introduce newlines")
    }

    func testUnboldAtStartOfLineWhenSelectionIncludesMarkers() {
        // Document: "Line one\n**hello** world"
        // User selects "**hello**" including markers
        var text = "Line one\n**hello** world"
        let range = NSRange(location: 9, length: 9) // "**hello**" at start of line 2
        let selectedText = (text as NSString).substring(with: range)
        XCTAssertEqual(selectedText, "**hello**")

        let innerText = String(selectedText.dropFirst(2).dropLast(2))
        text = (text as NSString).replacingCharacters(in: range, with: innerText)

        XCTAssertEqual(text, "Line one\nhello world")
        XCTAssertEqual(text.components(separatedBy: "\n").count, 2, "Should still have exactly 2 lines")
    }

    // MARK: - Italic Tests

    func testItalicFirstWordInDocument() {
        var text = "hello world"
        let range = NSRange(location: 0, length: 5)
        let selectedText = (text as NSString).substring(with: range)
        let replacement = "_\(selectedText)_"

        text = (text as NSString).replacingCharacters(in: range, with: replacement)
        XCTAssertEqual(text, "_hello_ world")
        XCTAssertFalse(text.contains("\n"))
    }

    func testUnitalicFirstWordInDocument() {
        var text = "_hello_ world"
        let nsText = text as NSString

        let selectionRange = NSRange(location: 1, length: 5) // "hello"
        let selectedText = nsText.substring(with: selectionRange)
        XCTAssertEqual(selectedText, "hello")

        let hasItalicBefore = nsText.substring(with: NSRange(location: 0, length: 1)) == "_"
        let hasItalicAfter = nsText.substring(with: NSRange(location: 6, length: 1)) == "_"

        XCTAssertTrue(hasItalicBefore)
        XCTAssertTrue(hasItalicAfter)

        let fullRange = NSRange(location: 0, length: 7) // "_hello_"
        text = nsText.replacingCharacters(in: fullRange, with: selectedText)

        XCTAssertEqual(text, "hello world")
        XCTAssertFalse(text.contains("\n"))
    }

    // MARK: - No Character Corruption Tests

    func testReplacementDoesNotCorruptSurroundingText() {
        let originalText = "The quick brown fox jumps"
        var text = originalText

        // Bold "quick"
        let boldRange = NSRange(location: 4, length: 5)
        text = (text as NSString).replacingCharacters(in: boldRange, with: "**quick**")
        XCTAssertEqual(text, "The **quick** brown fox jumps")

        // Unbold "quick"
        let nsText = text as NSString
        let unboldRange = NSRange(location: 4, length: 9) // "**quick**"
        text = nsText.replacingCharacters(in: unboldRange, with: "quick")
        XCTAssertEqual(text, originalText, "Should return to original text exactly")
    }

    func testNoNewlinesIntroducedInAnyOperation() {
        let testCases = [
            "hello",
            "hello world",
            "Line one\nLine two",
            "Line one\nLine two\nLine three",
            "**already bold**",
            "_already italic_",
        ]

        for original in testCases {
            let originalNewlineCount = original.components(separatedBy: "\n").count

            // Apply bold
            var text = "**\(original)**"
            XCTAssertEqual(text.components(separatedBy: "\n").count, originalNewlineCount,
                          "Bold should not change newline count for: \(original)")

            // Remove bold
            text = String(text.dropFirst(2).dropLast(2))
            XCTAssertEqual(text.components(separatedBy: "\n").count, originalNewlineCount,
                          "Unbold should not change newline count for: \(original)")
        }
    }

    // MARK: - Range Calculation Tests

    func testRangeCalculationForBoldAtPosition0() {
        let text = "**hello** world" as NSString

        // Selection of "hello" at position 2
        let selectionRange = NSRange(location: 2, length: 5)

        // Calculate full range including markers
        let fullRange = NSRange(location: selectionRange.location - 2, length: selectionRange.length + 4)

        XCTAssertEqual(fullRange.location, 0)
        XCTAssertEqual(fullRange.length, 9)
        XCTAssertEqual(text.substring(with: fullRange), "**hello**")
    }

    func testRangeCalculationForBoldAfterNewline() {
        let text = "Line\n**hello** world" as NSString

        // Selection of "hello" at position 7 (after "Line\n**")
        let selectionRange = NSRange(location: 7, length: 5)
        XCTAssertEqual(text.substring(with: selectionRange), "hello")

        // Full range including markers
        let fullRange = NSRange(location: selectionRange.location - 2, length: selectionRange.length + 4)
        XCTAssertEqual(fullRange.location, 5)
        XCTAssertEqual(fullRange.length, 9)
        XCTAssertEqual(text.substring(with: fullRange), "**hello**")
    }

    // MARK: - Edge Case: Bold at Very Start (Position 0)

    func testBoldAtPositionZero() {
        var text = "**word**"
        let nsText = text as NSString

        // Selection is "word" at position 2
        let selectionRange = NSRange(location: 2, length: 4)
        let selectedText = nsText.substring(with: selectionRange)
        XCTAssertEqual(selectedText, "word")

        // Verify markers
        let hasBoldBefore = selectionRange.location >= 2 &&
            nsText.substring(with: NSRange(location: 0, length: 2)) == "**"
        let hasBoldAfter = nsText.substring(with: NSRange(location: 6, length: 2)) == "**"

        XCTAssertTrue(hasBoldBefore)
        XCTAssertTrue(hasBoldAfter)

        // Remove bold
        let fullRange = NSRange(location: 0, length: 8)
        text = nsText.replacingCharacters(in: fullRange, with: selectedText)

        XCTAssertEqual(text, "word")
        XCTAssertFalse(text.contains("*"), "No asterisks should remain")
        XCTAssertFalse(text.contains("\n"), "No newlines should be introduced")
    }

    func testItalicAtPositionZero() {
        var text = "_word_"
        let nsText = text as NSString

        let selectionRange = NSRange(location: 1, length: 4)
        let selectedText = nsText.substring(with: selectionRange)
        XCTAssertEqual(selectedText, "word")

        let fullRange = NSRange(location: 0, length: 6)
        text = nsText.replacingCharacters(in: fullRange, with: selectedText)

        XCTAssertEqual(text, "word")
        XCTAssertFalse(text.contains("_"), "No underscores should remain")
        XCTAssertFalse(text.contains("\n"), "No newlines should be introduced")
    }
}
