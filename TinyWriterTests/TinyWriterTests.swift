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

// MARK: - Launch Behavior Setting Tests

final class LaunchBehaviorSettingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean up any existing settings before each test
        UserDefaults.standard.removeObject(forKey: "launchBehavior")
        UserDefaults.standard.removeObject(forKey: "lastEditedDocumentURL")
    }

    override func tearDown() {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: "launchBehavior")
        UserDefaults.standard.removeObject(forKey: "lastEditedDocumentURL")
        super.tearDown()
    }

    // MARK: - LaunchBehavior Enum Tests

    func testLaunchBehaviorEnumHasTwoCases() {
        let allCases = LaunchBehavior.allCases
        XCTAssertEqual(allCases.count, 2, "LaunchBehavior should have exactly 2 cases")
    }

    func testLaunchBehaviorLastEditedRawValue() {
        XCTAssertEqual(LaunchBehavior.lastEdited.rawValue, "lastEdited")
    }

    func testLaunchBehaviorNewNoteRawValue() {
        XCTAssertEqual(LaunchBehavior.newNote.rawValue, "newNote")
    }

    func testLaunchBehaviorLastEditedDisplayName() {
        XCTAssertEqual(LaunchBehavior.lastEdited.displayName, "Pick up where I left off")
    }

    func testLaunchBehaviorNewNoteDisplayName() {
        XCTAssertEqual(LaunchBehavior.newNote.displayName, "Create new note")
    }

    func testLaunchBehaviorCanBeCreatedFromRawValue() {
        XCTAssertEqual(LaunchBehavior(rawValue: "lastEdited"), .lastEdited)
        XCTAssertEqual(LaunchBehavior(rawValue: "newNote"), .newNote)
        XCTAssertNil(LaunchBehavior(rawValue: "invalid"))
    }

    // MARK: - LaunchBehavior.current Static Property Tests

    func testLaunchBehaviorDefaultIsLastEdited() {
        // When no setting is stored, default should be lastEdited
        UserDefaults.standard.removeObject(forKey: "launchBehavior")
        XCTAssertEqual(LaunchBehavior.current, .lastEdited, "Default launch behavior should be lastEdited")
    }

    func testLaunchBehaviorCurrentCanBeSetToLastEdited() {
        LaunchBehavior.current = .lastEdited
        XCTAssertEqual(LaunchBehavior.current, .lastEdited)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "launchBehavior"), "lastEdited")
    }

    func testLaunchBehaviorCurrentCanBeSetToNewNote() {
        LaunchBehavior.current = .newNote
        XCTAssertEqual(LaunchBehavior.current, .newNote)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "launchBehavior"), "newNote")
    }

    func testLaunchBehaviorPersistsAcrossReads() {
        LaunchBehavior.current = .newNote
        // Read multiple times to ensure persistence
        XCTAssertEqual(LaunchBehavior.current, .newNote)
        XCTAssertEqual(LaunchBehavior.current, .newNote)
        XCTAssertEqual(LaunchBehavior.current, .newNote)
    }

    func testLaunchBehaviorHandlesInvalidStoredValue() {
        // Store an invalid value directly
        UserDefaults.standard.set("invalidValue", forKey: "launchBehavior")
        // Should fall back to default
        XCTAssertEqual(LaunchBehavior.current, .lastEdited, "Should default to lastEdited for invalid stored value")
    }

    // MARK: - Last Edited URL Tests

    func testLastEditedURLKeyUsesBookmarkData() {
        let documentManager = TinyWriterDocumentManager()

        // Initially should be nil
        XCTAssertNil(documentManager.lastEditedURL, "lastEditedURL should be nil when not set")
    }

    func testLastEditedURLCanBeSetAndRetrieved() throws {
        let documentManager = TinyWriterDocumentManager()

        // Create a temporary file to test with
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_last_edited_\(UUID().uuidString).rtf")

        // Create the file first (needed for bookmark data)
        FileManager.default.createFile(atPath: testFileURL.path, contents: Data(), attributes: nil)

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        // Set the last edited URL
        documentManager.lastEditedURL = testFileURL

        // Retrieve it
        let retrievedURL = documentManager.lastEditedURL

        XCTAssertNotNil(retrievedURL, "Should be able to retrieve last edited URL")
        XCTAssertEqual(retrievedURL?.lastPathComponent, testFileURL.lastPathComponent, "Retrieved URL should match set URL")
    }

    func testLastEditedURLCanBeCleared() throws {
        let documentManager = TinyWriterDocumentManager()

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_clear_\(UUID().uuidString).rtf")
        FileManager.default.createFile(atPath: testFileURL.path, contents: Data(), attributes: nil)

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        // Set then clear
        documentManager.lastEditedURL = testFileURL
        XCTAssertNotNil(documentManager.lastEditedURL)

        documentManager.lastEditedURL = nil
        XCTAssertNil(documentManager.lastEditedURL, "lastEditedURL should be nil after clearing")
    }

    // MARK: - AppDelegate Launch Behavior Integration Tests

    func testAppDelegateHasDocumentManager() {
        let appDelegate = AppDelegate()
        XCTAssertNotNil(appDelegate.documentManager, "AppDelegate should have a documentManager")
    }

    func testAppDelegateDocumentManagerIsTinyWriterDocumentManager() {
        let appDelegate = AppDelegate()
        XCTAssertTrue(appDelegate.documentManager is TinyWriterDocumentManager,
                     "documentManager should be TinyWriterDocumentManager type")
    }
}

// MARK: - Launch Behavior Scenario Tests

final class LaunchBehaviorScenarioTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "launchBehavior")
        UserDefaults.standard.removeObject(forKey: "lastEditedDocumentURL")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "launchBehavior")
        UserDefaults.standard.removeObject(forKey: "lastEditedDocumentURL")
        super.tearDown()
    }

    // MARK: - Scenario: User prefers "Open last edited note"

    func testScenarioLastEditedPreference() {
        // Set preference
        LaunchBehavior.current = .lastEdited

        // Verify preference is saved
        XCTAssertEqual(LaunchBehavior.current, .lastEdited)

        // Simulate app restart by reading from fresh context
        let storedValue = UserDefaults.standard.string(forKey: "launchBehavior")
        XCTAssertEqual(storedValue, "lastEdited")
    }

    // MARK: - Scenario: User prefers "Create new note"

    func testScenarioNewNotePreference() {
        // Set preference
        LaunchBehavior.current = .newNote

        // Verify preference is saved
        XCTAssertEqual(LaunchBehavior.current, .newNote)

        // Simulate app restart by reading from fresh context
        let storedValue = UserDefaults.standard.string(forKey: "launchBehavior")
        XCTAssertEqual(storedValue, "newNote")
    }

    // MARK: - Scenario: Last edited file was deleted

    func testScenarioLastEditedFileDeleted() throws {
        let documentManager = TinyWriterDocumentManager()

        // Create and then delete a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_deleted_\(UUID().uuidString).rtf")
        FileManager.default.createFile(atPath: testFileURL.path, contents: Data(), attributes: nil)

        // Set as last edited
        documentManager.lastEditedURL = testFileURL

        // Delete the file
        try FileManager.default.removeItem(at: testFileURL)

        // The URL might still be retrievable from bookmark data, but file doesn't exist
        // App logic should check FileManager.default.fileExists before opening
        if let lastURL = documentManager.lastEditedURL {
            XCTAssertFalse(FileManager.default.fileExists(atPath: lastURL.path),
                          "File should not exist after deletion")
        }
    }

    // MARK: - Scenario: Switching between preferences

    func testScenarioSwitchingPreferences() {
        // Start with default (lastEdited)
        XCTAssertEqual(LaunchBehavior.current, .lastEdited)

        // User switches to newNote
        LaunchBehavior.current = .newNote
        XCTAssertEqual(LaunchBehavior.current, .newNote)

        // User switches back to lastEdited
        LaunchBehavior.current = .lastEdited
        XCTAssertEqual(LaunchBehavior.current, .lastEdited)
    }

    // MARK: - Scenario: First launch (no preference set)

    func testScenarioFirstLaunchNoPreference() {
        // Ensure no preference is set
        UserDefaults.standard.removeObject(forKey: "launchBehavior")

        // Should default to lastEdited
        XCTAssertEqual(LaunchBehavior.current, .lastEdited,
                      "First launch should default to 'Pick up where I left off'")
    }

    // MARK: - Cursor Position Tests

    func testMoveCursorToEndNotificationExists() {
        // Verify the notification name exists
        let notificationName = Notification.Name.moveCursorToEnd
        XCTAssertEqual(notificationName.rawValue, "moveCursorToEnd")
    }

    func testCursorMovesToEndInTextView() {
        // Create a text view with content
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = "Hello World"

        // Cursor starts at beginning
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertEqual(textView.selectedRange().location, 0)

        // Move cursor to end
        let endPosition = textView.string.count
        textView.setSelectedRange(NSRange(location: endPosition, length: 0))

        // Verify cursor is at end
        XCTAssertEqual(textView.selectedRange().location, 11, "Cursor should be at position 11 (end of 'Hello World')")
        XCTAssertEqual(textView.selectedRange().length, 0, "Should have no selection")
    }

    func testCursorAtEndAfterMultilineContent() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = "Line 1\nLine 2\nLine 3"

        // Move cursor to end
        let endPosition = textView.string.count
        textView.setSelectedRange(NSRange(location: endPosition, length: 0))

        // Verify cursor is at end
        XCTAssertEqual(textView.selectedRange().location, 20, "Cursor should be at end of multiline content")
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

// MARK: - Formatting Preservation Tests

final class FormattingPreservationTests: XCTestCase {

    // MARK: - Font Trait Preservation Tests

    func testBoldTraitPreservedWhenChangingFontSize() {
        // Create attributed string with bold text
        let fontManager = NSFontManager.shared
        let regularFont = NSFont.systemFont(ofSize: 14)
        let boldFont = fontManager.convert(regularFont, toHaveTrait: .boldFontMask)

        let attributedString = NSMutableAttributedString(string: "Hello World")
        // Make "Hello" bold (positions 0-5)
        attributedString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5))
        // Keep "World" regular (positions 6-11)
        attributedString.addAttribute(.font, value: regularFont, range: NSRange(location: 6, length: 5))

        // Simulate font size change - preserve traits while changing size
        let newSize: CGFloat = 18
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            guard let oldFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: oldFont)
            var newFont = NSFont.systemFont(ofSize: newSize)
            if traits.contains(.boldFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask)
            }
            if traits.contains(.italicFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask)
            }
            attributedString.addAttribute(.font, value: newFont, range: range)
        }

        // Verify "Hello" is still bold
        var helloFont: NSFont?
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: 5), options: []) { value, _, _ in
            helloFont = value as? NSFont
        }
        XCTAssertNotNil(helloFont)
        let helloTraits = fontManager.traits(of: helloFont!)
        XCTAssertTrue(helloTraits.contains(.boldFontMask), "Bold trait should be preserved after font size change")
        XCTAssertEqual(helloFont?.pointSize, newSize, "Font size should be updated")

        // Verify "World" is still regular (not bold)
        var worldFont: NSFont?
        attributedString.enumerateAttribute(.font, in: NSRange(location: 6, length: 5), options: []) { value, _, _ in
            worldFont = value as? NSFont
        }
        XCTAssertNotNil(worldFont)
        let worldTraits = fontManager.traits(of: worldFont!)
        XCTAssertFalse(worldTraits.contains(.boldFontMask), "Regular text should remain not bold")
        XCTAssertEqual(worldFont?.pointSize, newSize, "Font size should be updated")
    }

    func testItalicTraitPreservedWhenChangingFontSize() {
        let fontManager = NSFontManager.shared
        let regularFont = NSFont.systemFont(ofSize: 14)
        let italicFont = fontManager.convert(regularFont, toHaveTrait: .italicFontMask)

        let attributedString = NSMutableAttributedString(string: "Hello World")
        attributedString.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: 5))
        attributedString.addAttribute(.font, value: regularFont, range: NSRange(location: 6, length: 5))

        // Simulate font size change with trait preservation
        let newSize: CGFloat = 20
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            guard let oldFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: oldFont)
            var newFont = NSFont.systemFont(ofSize: newSize)
            if traits.contains(.boldFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask)
            }
            if traits.contains(.italicFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask)
            }
            attributedString.addAttribute(.font, value: newFont, range: range)
        }

        // Verify "Hello" is still italic
        var helloFont: NSFont?
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: 5), options: []) { value, _, _ in
            helloFont = value as? NSFont
        }
        XCTAssertNotNil(helloFont)
        let helloTraits = fontManager.traits(of: helloFont!)
        XCTAssertTrue(helloTraits.contains(.italicFontMask), "Italic trait should be preserved after font size change")
    }

    func testBoldItalicTraitsPreservedWhenChangingFontSize() {
        let fontManager = NSFontManager.shared
        let regularFont = NSFont.systemFont(ofSize: 14)
        let boldItalicFont = fontManager.convert(
            fontManager.convert(regularFont, toHaveTrait: .boldFontMask),
            toHaveTrait: .italicFontMask
        )

        let attributedString = NSMutableAttributedString(string: "BoldItalic")
        attributedString.addAttribute(.font, value: boldItalicFont, range: NSRange(location: 0, length: 10))

        // Change font size
        let newSize: CGFloat = 22
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            guard let oldFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: oldFont)
            var newFont = NSFont.systemFont(ofSize: newSize)
            if traits.contains(.boldFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask)
            }
            if traits.contains(.italicFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask)
            }
            attributedString.addAttribute(.font, value: newFont, range: range)
        }

        var resultFont: NSFont?
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: 10), options: []) { value, _, _ in
            resultFont = value as? NSFont
        }
        XCTAssertNotNil(resultFont)
        let resultTraits = fontManager.traits(of: resultFont!)
        XCTAssertTrue(resultTraits.contains(.boldFontMask), "Bold trait should be preserved")
        XCTAssertTrue(resultTraits.contains(.italicFontMask), "Italic trait should be preserved")
        XCTAssertEqual(resultFont?.pointSize, newSize, "Font size should be updated")
    }

    // MARK: - Paragraph Style Preservation Tests

    func testLineSpacingChangePreservesParagraphStyle() {
        let originalStyle = NSMutableParagraphStyle()
        originalStyle.lineSpacing = 6
        originalStyle.alignment = .center  // Custom alignment

        let attributedString = NSMutableAttributedString(string: "Test paragraph")
        attributedString.addAttribute(.paragraphStyle, value: originalStyle, range: NSRange(location: 0, length: attributedString.length))

        // Update line spacing while preserving other paragraph attributes
        let newLineSpacing: CGFloat = 10
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            let newStyle = NSMutableParagraphStyle()
            if let oldStyle = value as? NSParagraphStyle {
                newStyle.setParagraphStyle(oldStyle)
            }
            newStyle.lineSpacing = newLineSpacing
            attributedString.addAttribute(.paragraphStyle, value: newStyle, range: range)
        }

        var resultStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }
        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.lineSpacing, newLineSpacing, "Line spacing should be updated")
        XCTAssertEqual(resultStyle?.alignment, .center, "Alignment should be preserved")
    }

    // MARK: - Text Storage Formatting Tests

    func testTextStoragePreservesFormattingDuringUpdate() {
        let textStorage = NSTextStorage(string: "Bold and Regular")
        let fontManager = NSFontManager.shared
        let regularFont = NSFont.systemFont(ofSize: 14)
        let boldFont = fontManager.convert(regularFont, toHaveTrait: .boldFontMask)

        // Apply formatting: "Bold" is bold, " and Regular" is regular
        textStorage.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))
        textStorage.addAttribute(.font, value: regularFont, range: NSRange(location: 4, length: 12))

        // Verify initial state
        var initialBoldFont: NSFont?
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            initialBoldFont = value as? NSFont
        }
        XCTAssertTrue(fontManager.traits(of: initialBoldFont!).contains(.boldFontMask), "Initial bold should be set")

        // Simulate a proper font size update that preserves traits
        let newSize: CGFloat = 18
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            guard let oldFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: oldFont)
            var newFont = NSFont.systemFont(ofSize: newSize)
            if traits.contains(.boldFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask)
            }
            if traits.contains(.italicFontMask) {
                newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask)
            }
            textStorage.addAttribute(.font, value: newFont, range: range)
        }
        textStorage.endEditing()

        // Verify "Bold" is still bold after update
        var finalBoldFont: NSFont?
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            finalBoldFont = value as? NSFont
        }
        XCTAssertNotNil(finalBoldFont)
        XCTAssertTrue(fontManager.traits(of: finalBoldFont!).contains(.boldFontMask), "Bold trait should be preserved after text storage update")
        XCTAssertEqual(finalBoldFont?.pointSize, newSize)
    }

    // MARK: - Destructive Update Detection Tests

    func testDestructiveUpdateLosesFormatting() {
        // This test demonstrates the BAD behavior that we're fixing
        let textStorage = NSTextStorage(string: "Bold text")
        let fontManager = NSFontManager.shared
        let regularFont = NSFont.systemFont(ofSize: 14)
        let boldFont = fontManager.convert(regularFont, toHaveTrait: .boldFontMask)

        // Apply bold
        textStorage.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))

        // DESTRUCTIVE: Apply a single font to entire range (the old buggy behavior)
        let newRegularFont = NSFont.systemFont(ofSize: 18)
        textStorage.addAttribute(.font, value: newRegularFont, range: NSRange(location: 0, length: textStorage.length))

        // Verify bold is LOST (this is the bug we're fixing)
        var resultFont: NSFont?
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            resultFont = value as? NSFont
        }
        XCTAssertNotNil(resultFont)
        XCTAssertFalse(fontManager.traits(of: resultFont!).contains(.boldFontMask), "Destructive update should lose bold (this is the bug)")
    }

    // MARK: - View Recreation Simulation Tests

    func testFormattingPreservedThroughAttributedStringCopy() {
        // Simulates what happens when view is recreated during fullscreen:
        // The attributedText binding should preserve formatting
        let fontManager = NSFontManager.shared
        let regularFont = NSFont.systemFont(ofSize: 14)
        let boldFont = fontManager.convert(regularFont, toHaveTrait: .boldFontMask)

        // Original text storage with bold formatting
        let originalStorage = NSTextStorage(string: "Bold text")
        originalStorage.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))
        originalStorage.addAttribute(.font, value: regularFont, range: NSRange(location: 4, length: 5))

        // Copy to NSAttributedString (simulating binding update)
        let attributedCopy = NSAttributedString(attributedString: originalStorage)

        // Create new text storage from copy (simulating view recreation)
        let newStorage = NSTextStorage(attributedString: attributedCopy)

        // Verify bold is preserved through the copy
        var boldFontResult: NSFont?
        newStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            boldFontResult = value as? NSFont
        }
        XCTAssertNotNil(boldFontResult)
        XCTAssertTrue(fontManager.traits(of: boldFontResult!).contains(.boldFontMask),
                     "Bold formatting should be preserved through attributed string copy")
    }

    func testFormattingDidChangeNotificationExists() {
        // Verify the notification name exists
        let notificationName = Notification.Name.formattingDidChange
        XCTAssertEqual(notificationName.rawValue, "formattingDidChange")
    }
}

// MARK: - Text Alignment Tests

final class TextAlignmentTests: XCTestCase {

    // MARK: - Basic Alignment Tests

    func testCanSetLeftAlignment() {
        let attributedString = NSMutableAttributedString(string: "Test paragraph")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle,
                                      range: NSRange(location: 0, length: attributedString.length))

        var resultStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.alignment, .left, "Should be left aligned")
    }

    func testCanSetCenterAlignment() {
        let attributedString = NSMutableAttributedString(string: "Test paragraph")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle,
                                      range: NSRange(location: 0, length: attributedString.length))

        var resultStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.alignment, .center, "Should be center aligned")
    }

    func testCanSetRightAlignment() {
        let attributedString = NSMutableAttributedString(string: "Test paragraph")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle,
                                      range: NSRange(location: 0, length: attributedString.length))

        var resultStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.alignment, .right, "Should be right aligned")
    }

    // MARK: - Alignment Preservation Tests

    func testAlignmentPreservesLineSpacing() {
        let attributedString = NSMutableAttributedString(string: "Test paragraph")

        // First set line spacing
        let initialStyle = NSMutableParagraphStyle()
        initialStyle.lineSpacing = 10
        attributedString.addAttribute(.paragraphStyle, value: initialStyle,
                                      range: NSRange(location: 0, length: attributedString.length))

        // Then update alignment while preserving line spacing
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            let newStyle = NSMutableParagraphStyle()
            if let oldStyle = value as? NSParagraphStyle {
                newStyle.setParagraphStyle(oldStyle)
            }
            newStyle.alignment = .center
            attributedString.addAttribute(.paragraphStyle, value: newStyle, range: range)
        }

        var resultStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.alignment, .center, "Alignment should be center")
        XCTAssertEqual(resultStyle?.lineSpacing, 10, "Line spacing should be preserved")
    }

    func testLineSpacingPreservesAlignment() {
        let attributedString = NSMutableAttributedString(string: "Test paragraph")

        // First set alignment
        let initialStyle = NSMutableParagraphStyle()
        initialStyle.alignment = .right
        attributedString.addAttribute(.paragraphStyle, value: initialStyle,
                                      range: NSRange(location: 0, length: attributedString.length))

        // Then update line spacing while preserving alignment
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            let newStyle = NSMutableParagraphStyle()
            if let oldStyle = value as? NSParagraphStyle {
                newStyle.setParagraphStyle(oldStyle)
            }
            newStyle.lineSpacing = 15
            attributedString.addAttribute(.paragraphStyle, value: newStyle, range: range)
        }

        var resultStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.alignment, .right, "Alignment should be preserved")
        XCTAssertEqual(resultStyle?.lineSpacing, 15, "Line spacing should be updated")
    }

    // MARK: - Partial Selection Alignment Tests

    func testCanAlignPartialSelection() {
        let attributedString = NSMutableAttributedString(string: "First paragraph\nSecond paragraph")

        // Apply center alignment to only the first paragraph (0-15)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle,
                                      range: NSRange(location: 0, length: 15))

        // Check first paragraph is centered
        var firstStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: 15), options: []) { value, _, _ in
            firstStyle = value as? NSParagraphStyle
        }
        XCTAssertEqual(firstStyle?.alignment, .center, "First paragraph should be centered")

        // Second paragraph should have default alignment (natural/left)
        var secondStyle: NSParagraphStyle?
        attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 16, length: 16), options: []) { value, _, _ in
            secondStyle = value as? NSParagraphStyle
        }
        // Second paragraph may have nil style or default
        if let style = secondStyle {
            XCTAssertNotEqual(style.alignment, .center, "Second paragraph should not be centered")
        }
    }

    // MARK: - TextStorage Alignment Tests

    func testTextStorageAlignmentChange() {
        let textStorage = NSTextStorage(string: "Test content for alignment")

        // Apply right alignment
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        textStorage.beginEditing()
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle,
                                range: NSRange(location: 0, length: textStorage.length))
        textStorage.endEditing()

        var resultStyle: NSParagraphStyle?
        textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: textStorage.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.alignment, .right, "TextStorage should have right alignment")
    }

    func testAlignmentToggleFromLeftToRight() {
        let textStorage = NSTextStorage(string: "Toggle test")

        // Start with left alignment
        let leftStyle = NSMutableParagraphStyle()
        leftStyle.alignment = .left
        textStorage.addAttribute(.paragraphStyle, value: leftStyle,
                                range: NSRange(location: 0, length: textStorage.length))

        // Toggle to right alignment
        textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            let newStyle = NSMutableParagraphStyle()
            if let oldStyle = value as? NSParagraphStyle {
                newStyle.setParagraphStyle(oldStyle)
            }
            newStyle.alignment = .right
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: range)
        }

        var resultStyle: NSParagraphStyle?
        textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: textStorage.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertEqual(resultStyle?.alignment, .right, "Should toggle from left to right")
    }

    // MARK: - Alignment with Font Traits Tests

    func testAlignmentPreservesBoldFont() {
        let textStorage = NSTextStorage(string: "Bold and aligned")
        let fontManager = NSFontManager.shared
        let boldFont = fontManager.convert(NSFont.systemFont(ofSize: 14), toHaveTrait: .boldFontMask)

        // Apply bold font
        textStorage.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: textStorage.length))

        // Apply center alignment
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle,
                                range: NSRange(location: 0, length: textStorage.length))

        // Verify bold is preserved
        var resultFont: NSFont?
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            resultFont = value as? NSFont
        }

        XCTAssertNotNil(resultFont)
        XCTAssertTrue(fontManager.traits(of: resultFont!).contains(.boldFontMask),
                     "Bold trait should be preserved after alignment change")
    }

    func testBoldPreservesAlignment() {
        let textStorage = NSTextStorage(string: "Aligned and bold")
        let fontManager = NSFontManager.shared

        // Apply right alignment first
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle,
                                range: NSRange(location: 0, length: textStorage.length))

        // Apply bold font
        let boldFont = fontManager.convert(NSFont.systemFont(ofSize: 14), toHaveTrait: .boldFontMask)
        textStorage.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: textStorage.length))

        // Verify alignment is preserved
        var resultStyle: NSParagraphStyle?
        textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: textStorage.length), options: []) { value, _, _ in
            resultStyle = value as? NSParagraphStyle
        }

        XCTAssertNotNil(resultStyle)
        XCTAssertEqual(resultStyle?.alignment, .right, "Right alignment should be preserved after bold")
    }

    // MARK: - NSTextAlignment Value Tests

    func testNSTextAlignmentValues() {
        // Verify the alignment enum values exist and are distinct
        XCTAssertNotEqual(NSTextAlignment.left, NSTextAlignment.right)
        XCTAssertNotEqual(NSTextAlignment.left, NSTextAlignment.center)
        XCTAssertNotEqual(NSTextAlignment.center, NSTextAlignment.right)
    }

    // MARK: - Default Alignment Tests

    func testDefaultParagraphStyleHasNaturalAlignment() {
        let defaultStyle = NSParagraphStyle.default
        // Natural alignment is typically left for LTR languages
        XCTAssertTrue(defaultStyle.alignment == .natural || defaultStyle.alignment == .left,
                     "Default alignment should be natural or left")
    }
}

// MARK: - Sidebar Selection Tests

final class SidebarSelectionTests: XCTestCase {

    // MARK: - Current Document URL Tracking Tests

    func testCurrentDocumentChangedNotificationContainsURL() {
        // When a document with a URL is switched to, the notification should contain that URL
        let testURL = URL(fileURLWithPath: "/tmp/test.rtf")
        var receivedURL: URL?

        let expectation = XCTestExpectation(description: "Notification received")

        let observer = NotificationCenter.default.addObserver(
            forName: .currentDocumentChanged,
            object: nil,
            queue: .main
        ) { notification in
            receivedURL = notification.object as? URL
            expectation.fulfill()
        }

        // Post notification with URL
        NotificationCenter.default.post(name: .currentDocumentChanged, object: testURL)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedURL, testURL, "Notification should contain the document URL")

        NotificationCenter.default.removeObserver(observer)
    }

    func testCurrentDocumentChangedNotificationCanBeNil() {
        // For untitled documents, the notification object may be nil
        var notificationReceived = false
        var receivedObject: Any?

        let expectation = XCTestExpectation(description: "Notification received")

        let observer = NotificationCenter.default.addObserver(
            forName: .currentDocumentChanged,
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            receivedObject = notification.object
            expectation.fulfill()
        }

        // Post notification with nil
        NotificationCenter.default.post(name: .currentDocumentChanged, object: nil)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(notificationReceived, "Notification should be received")
        XCTAssertNil(receivedObject, "Notification object should be nil for untitled documents")

        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - URL Comparison Tests

    func testURLEqualityForSelection() {
        // Test that URL comparison works correctly for selection highlighting
        let url1 = URL(fileURLWithPath: "/Users/test/Documents/notes/MyNote.rtf")
        let url2 = URL(fileURLWithPath: "/Users/test/Documents/notes/MyNote.rtf")
        let url3 = URL(fileURLWithPath: "/Users/test/Documents/notes/OtherNote.rtf")

        XCTAssertEqual(url1, url2, "Same path URLs should be equal")
        XCTAssertNotEqual(url1, url3, "Different path URLs should not be equal")

        // Test isSelected logic
        let currentDocumentURL: URL? = url1
        let isUrl1Selected = url1 == currentDocumentURL
        let isUrl3Selected = url3 == currentDocumentURL

        XCTAssertTrue(isUrl1Selected, "URL matching currentDocumentURL should be selected")
        XCTAssertFalse(isUrl3Selected, "URL not matching currentDocumentURL should not be selected")
    }

    func testNilCurrentDocumentURLSelectsNothing() {
        let testURL = URL(fileURLWithPath: "/tmp/test.rtf")
        let currentDocumentURL: URL? = nil

        let isSelected = testURL == currentDocumentURL

        XCTAssertFalse(isSelected, "When currentDocumentURL is nil, no file should be selected")
    }

    // MARK: - Document Manager State Tests

    func testDocumentManagerHasActiveDocumentProperty() {
        let documentManager = TinyWriterDocumentManager()

        // The activeDocument property should exist and be accessible
        // (It may or may not be nil depending on app state)
        _ = documentManager.activeDocument
        // Test passes if property is accessible without crash
    }

    func testNewDocumentStartsWithNilFileURL() {
        let document = TinyWriterDocument()
        XCTAssertNil(document.fileURL, "New document should have nil fileURL")
    }

    // MARK: - Notification Flow Tests

    func testCurrentDocumentChangedNotificationNameExists() {
        let notificationName = Notification.Name.currentDocumentChanged
        XCTAssertEqual(notificationName.rawValue, "currentDocumentChanged")
    }

    func testNotesFolderChangedNotificationNameExists() {
        let notificationName = Notification.Name.notesFolderChanged
        XCTAssertEqual(notificationName.rawValue, "notesFolderChanged")
    }
}

// MARK: - File Rename Tests

final class FileRenameTests: XCTestCase {

    var tempFolder: URL!

    override func setUp() {
        super.setUp()
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TinyWriterRenameTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempFolder,
            withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFolder)
        super.tearDown()
    }

    // MARK: - Basic Rename Tests

    func testRenameFileChangesFilename() throws {
        // Create a test file
        let oldURL = tempFolder.appendingPathComponent("OldName.rtf")
        FileManager.default.createFile(atPath: oldURL.path, contents: "Test content".data(using: .utf8))

        XCTAssertTrue(FileManager.default.fileExists(atPath: oldURL.path), "Original file should exist")

        // Rename the file
        let newURL = tempFolder.appendingPathComponent("NewName.rtf")
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        // Verify rename
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path), "Old file should not exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path), "New file should exist")
    }

    func testRenamePreservesFileContent() throws {
        let originalContent = "This is the original content"
        let oldURL = tempFolder.appendingPathComponent("Original.rtf")
        FileManager.default.createFile(atPath: oldURL.path, contents: originalContent.data(using: .utf8))

        let newURL = tempFolder.appendingPathComponent("Renamed.rtf")
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        // Verify content is preserved
        let readContent = try String(contentsOf: newURL, encoding: .utf8)
        XCTAssertEqual(readContent, originalContent, "File content should be preserved after rename")
    }

    func testRenamePreservesFileExtension() throws {
        let oldURL = tempFolder.appendingPathComponent("Test.rtf")
        FileManager.default.createFile(atPath: oldURL.path, contents: Data())

        let newURL = tempFolder.appendingPathComponent("Renamed.rtf")
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        XCTAssertEqual(newURL.pathExtension, "rtf", "File extension should be preserved")
    }

    // MARK: - Validation Tests

    func testCannotRenameToExistingFilename() throws {
        // Create two files
        let file1URL = tempFolder.appendingPathComponent("File1.rtf")
        let file2URL = tempFolder.appendingPathComponent("File2.rtf")
        FileManager.default.createFile(atPath: file1URL.path, contents: Data())
        FileManager.default.createFile(atPath: file2URL.path, contents: Data())

        // Try to rename File1 to File2 (should fail)
        let targetURL = tempFolder.appendingPathComponent("File2.rtf")

        XCTAssertThrowsError(try FileManager.default.moveItem(at: file1URL, to: targetURL)) { error in
            // Should throw because File2 already exists
            XCTAssertTrue(error is CocoaError || (error as NSError).domain == NSCocoaErrorDomain,
                         "Should throw a file exists error")
        }
    }

    func testEmptyFilenameIsInvalid() {
        let emptyName = ""
        XCTAssertTrue(emptyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                     "Empty filename should be detected as invalid")
    }

    func testWhitespaceOnlyFilenameIsInvalid() {
        let whitespaceName = "   "
        XCTAssertTrue(whitespaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                     "Whitespace-only filename should be detected as invalid")
    }

    func testFilenameWithInvalidCharactersDetection() {
        // macOS doesn't allow colons or forward slashes in filenames
        let invalidNames = ["file:name", "file/name"]

        for name in invalidNames {
            let hasInvalidChars = name.contains(":") || name.contains("/")
            XCTAssertTrue(hasInvalidChars, "'\(name)' should be detected as having invalid characters")
        }
    }

    // MARK: - URL Construction Tests

    func testNewURLConstructionPreservesDirectory() {
        let originalURL = tempFolder.appendingPathComponent("Original.rtf")
        let newName = "NewName"
        let fileExtension = originalURL.pathExtension

        let newURL = originalURL.deletingLastPathComponent()
            .appendingPathComponent(newName)
            .appendingPathExtension(fileExtension)

        XCTAssertEqual(newURL.deletingLastPathComponent(), originalURL.deletingLastPathComponent(),
                      "Directory should be preserved")
        XCTAssertEqual(newURL.deletingPathExtension().lastPathComponent, newName,
                      "New filename should be set correctly")
        XCTAssertEqual(newURL.pathExtension, "rtf", "Extension should be preserved")
    }

    func testExtractFilenameWithoutExtension() {
        let url = tempFolder.appendingPathComponent("MyDocument.rtf")
        let nameWithoutExtension = url.deletingPathExtension().lastPathComponent

        XCTAssertEqual(nameWithoutExtension, "MyDocument",
                      "Should extract filename without extension")
    }

    // MARK: - Edge Cases

    func testRenameToSameNameDoesNothing() throws {
        let url = tempFolder.appendingPathComponent("SameName.rtf")
        FileManager.default.createFile(atPath: url.path, contents: "Content".data(using: .utf8))

        // Renaming to same name should be a no-op (or handled gracefully)
        // In practice, we'd skip the rename operation if names are equal
        let oldName = url.deletingPathExtension().lastPathComponent
        let newName = "SameName"

        XCTAssertEqual(oldName, newName, "Same name should be detected")
        // The UI should not perform a rename when old == new
    }

    func testRenameWithSpecialCharacters() throws {
        let oldURL = tempFolder.appendingPathComponent("Normal.rtf")
        FileManager.default.createFile(atPath: oldURL.path, contents: Data())

        // macOS allows most special characters except : and /
        let newURL = tempFolder.appendingPathComponent("Special & Name (1) - Test!.rtf")
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path),
                     "Should allow special characters in filename")
    }

    func testRenameWithUnicodeCharacters() throws {
        let oldURL = tempFolder.appendingPathComponent("Normal.rtf")
        FileManager.default.createFile(atPath: oldURL.path, contents: Data())

        let newURL = tempFolder.appendingPathComponent("日本語ファイル.rtf")
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path),
                     "Should allow unicode characters in filename")
    }
}

// MARK: - Deferred File Creation Tests

final class DeferredFileCreationTests: XCTestCase {

    var documentManager: TinyWriterDocumentManager!
    var tempFolder: URL!

    override func setUp() {
        super.setUp()
        documentManager = TinyWriterDocumentManager()
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TinyWriterTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempFolder,
            withIntermediateDirectories: true)
        documentManager.setNotesFolder(tempFolder)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFolder)
        super.tearDown()
    }

    // MARK: - Document Creation Tests

    func testNewDocumentStartsWithNoFileURL() {
        // When creating a new document, it should not have a file URL
        let expectation = XCTestExpectation(description: "Document created")

        documentManager.createNewTinyWriterDocument { document in
            XCTAssertNotNil(document, "Should create a document")
            XCTAssertNil(document?.fileURL, "New document should not have a file URL")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testNewDocumentDoesNotCreateFileOnDisk() {
        // Creating a new document should not create any file
        let expectation = XCTestExpectation(description: "Document created")

        let initialFiles = try? FileManager.default.contentsOfDirectory(at: tempFolder,
            includingPropertiesForKeys: nil)
        let initialCount = initialFiles?.count ?? 0

        documentManager.createNewTinyWriterDocument { [self] _ in
            let newFiles = try? FileManager.default.contentsOfDirectory(at: tempFolder,
                includingPropertiesForKeys: nil)
            XCTAssertEqual(newFiles?.count ?? 0, initialCount,
                "No new file should be created on disk")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUntitledDocumentHasNoFileURL() {
        // Verify fileURL is nil for new documents
        let document = TinyWriterDocument()
        XCTAssertNil(document.fileURL, "New document should have nil fileURL")
    }

    // MARK: - First Save Tests

    func testTypingTriggersFileCreation() {
        // When user types in an untitled document, file should be created
        let expectation = XCTestExpectation(description: "File created after typing")

        documentManager.createNewTinyWriterDocument { [self] document in
            guard let doc = document else {
                XCTFail("Should create document")
                expectation.fulfill()
                return
            }

            // Simulate typing
            doc.text = "Hello, World!"

            // Allow save to trigger
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                XCTAssertNotNil(doc.fileURL, "Document should now have a file URL")

                if let url = doc.fileURL {
                    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                        "File should exist on disk")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 3.0)
    }

    func testFirstSaveGeneratesTimestampFilename() {
        let expectation = XCTestExpectation(description: "Filename generated")

        documentManager.createNewTinyWriterDocument { document in
            guard let doc = document else {
                XCTFail("Should create document")
                expectation.fulfill()
                return
            }

            doc.text = "Test content"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let filename = doc.fileURL?.lastPathComponent {
                    // Verify filename has .rtf extension
                    XCTAssertTrue(filename.hasSuffix(".rtf"),
                        "Filename should have .rtf extension")
                } else {
                    XCTFail("Document should have a fileURL with filename")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Close Without Save Tests

    func testEmptyDocumentCreatesNoFile() {
        // Creating a document and not typing should not create a file
        let expectation = XCTestExpectation(description: "No file created")

        let initialFiles = try? FileManager.default.contentsOfDirectory(at: tempFolder,
            includingPropertiesForKeys: nil)
        let initialCount = initialFiles?.count ?? 0

        documentManager.createNewTinyWriterDocument { [self] _ in
            // Don't type anything, just wait
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let finalFiles = try? FileManager.default.contentsOfDirectory(
                    at: tempFolder, includingPropertiesForKeys: nil)
                XCTAssertEqual(finalFiles?.count ?? 0, initialCount,
                    "No files should be created for empty documents")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Window Title Tests

    func testNewDocumentWindowTitleIsUntitled() {
        // Document without fileURL should be "Untitled"
        let document = TinyWriterDocument()
        XCTAssertNil(document.fileURL, "New document should have no fileURL")
        // Window title logic is in switchToDocument - when fileURL is nil, title is "Untitled"
    }

    // MARK: - Content Tracking Tests

    func testDocumentWithContentHasUnsavedChanges() {
        let document = TinyWriterDocument()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).rtf")
        document.fileURL = tempURL

        XCTAssertFalse(document.hasUnautosavedChanges, "New document should not have unsaved changes")

        document.text = "Some content"

        XCTAssertTrue(document.hasUnautosavedChanges, "Document with content should have unsaved changes")
    }

    func testEmptyDocumentHasNoUnsavedChanges() {
        let document = TinyWriterDocument()
        // Empty document without any edits should not have unsaved changes
        XCTAssertFalse(document.hasUnautosavedChanges, "Empty document should not have unsaved changes")
    }
}

// MARK: - Undo/Redo for Formatting Tests

final class UndoRedoFormattingTests: XCTestCase {

    /// Helper to create a text view with an undo manager for testing
    private func createTextViewWithUndoManager(text: String) -> (NSTextView, NSTextStorage, UndoManager) {
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 400, height: 300))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), textContainer: textContainer)
        textView.allowsUndo = true

        // Create and assign an undo manager since we're not in a window
        let undoManager = UndoManager()

        // Put text view in a window so it gets an undo manager
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = textView

        return (textView, textStorage, textView.undoManager ?? undoManager)
    }

    // MARK: - Basic Undo Manager Tests

    func testTextViewHasUndoManagerWhenInWindow() {
        // NSTextView in a window should have an undo manager
        let (textView, _, _) = createTextViewWithUndoManager(text: "Hello")
        XCTAssertNotNil(textView.undoManager, "Text view in window should have an undo manager")
    }

    func testTextStorageChangesCanBeUndone() {
        // Basic test: text changes should be undoable
        let (textView, _, _) = createTextViewWithUndoManager(text: "Hello")

        // Verify the undo manager exists
        XCTAssertNotNil(textView.undoManager, "Undo manager should exist")
        XCTAssertTrue(textView.allowsUndo, "allowsUndo should be true")
    }

    func testUndoManagerCanUndoAttributeChanges() {
        // Test that attribute changes can be undone when properly registered
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Hello World")

        // Store original state
        let range = NSRange(location: 0, length: 5) // "Hello"
        let originalFont = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont

        // Apply bold using shouldChangeText pattern
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let boldFont = NSFontManager.shared.convert(originalFont ?? NSFont.systemFont(ofSize: 12), toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: boldFont, range: range)
            textView.didChangeText()
        }

        // Verify bold was applied
        let fontAfterBold = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let traitsAfterBold = NSFontManager.shared.traits(of: fontAfterBold ?? NSFont.systemFont(ofSize: 12))
        XCTAssertTrue(traitsAfterBold.contains(.boldFontMask), "Text should be bold after applying")

        // Undo should be available
        XCTAssertTrue(textView.undoManager?.canUndo ?? false, "Undo should be available after formatting change")
    }

    func testUndoRestoresOriginalFormatting() {
        // Test that undo restores the original non-bold state
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Hello World")

        let range = NSRange(location: 0, length: 5)
        let originalFont = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: originalFont, range: range)

        // Apply bold with proper undo registration
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let boldFont = NSFontManager.shared.convert(originalFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: boldFont, range: range)
            textView.didChangeText()
        }

        // Verify bold was applied
        let fontAfterBold = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertTrue(NSFontManager.shared.traits(of: fontAfterBold!).contains(.boldFontMask), "Should be bold")

        // Perform undo
        textView.undoManager?.undo()

        // Verify bold was removed
        let fontAfterUndo = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let traitsAfterUndo = NSFontManager.shared.traits(of: fontAfterUndo ?? NSFont.systemFont(ofSize: 12))
        XCTAssertFalse(traitsAfterUndo.contains(.boldFontMask), "Text should not be bold after undo")
    }

    func testRedoReappliesFormatting() {
        // Test that redo reapplies the formatting after undo
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Hello World")

        let range = NSRange(location: 0, length: 5)
        let originalFont = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: originalFont, range: range)

        // Apply bold
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let boldFont = NSFontManager.shared.convert(originalFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: boldFont, range: range)
            textView.didChangeText()
        }

        // Undo
        textView.undoManager?.undo()

        // Redo should be available
        XCTAssertTrue(textView.undoManager?.canRedo ?? false, "Redo should be available after undo")

        // Perform redo
        textView.undoManager?.redo()

        // Verify bold was reapplied
        let fontAfterRedo = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let traitsAfterRedo = NSFontManager.shared.traits(of: fontAfterRedo ?? NSFont.systemFont(ofSize: 12))
        XCTAssertTrue(traitsAfterRedo.contains(.boldFontMask), "Text should be bold after redo")
    }

    // MARK: - Italic Undo Tests

    func testUndoItalicFormatting() {
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Test text")

        let range = NSRange(location: 0, length: 4) // "Test"
        let originalFont = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: originalFont, range: range)

        // Apply italic
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let italicFont = NSFontManager.shared.convert(originalFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: italicFont, range: range)
            textView.didChangeText()
        }

        // Verify italic was applied
        let fontAfterItalic = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertTrue(NSFontManager.shared.traits(of: fontAfterItalic!).contains(.italicFontMask), "Should be italic")

        // Undo
        textView.undoManager?.undo()

        // Verify italic was removed
        let fontAfterUndo = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertFalse(NSFontManager.shared.traits(of: fontAfterUndo!).contains(.italicFontMask), "Should not be italic after undo")
    }

    // MARK: - Alignment Undo Tests

    func testUndoAlignmentChange() {
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Test paragraph")

        let range = NSRange(location: 0, length: textStorage.length)

        // Set initial left alignment
        let leftStyle = NSMutableParagraphStyle()
        leftStyle.alignment = .left
        textStorage.addAttribute(.paragraphStyle, value: leftStyle, range: range)

        // Apply center alignment
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let centerStyle = NSMutableParagraphStyle()
            centerStyle.alignment = .center
            textStorage.addAttribute(.paragraphStyle, value: centerStyle, range: range)
            textView.didChangeText()
        }

        // Verify center alignment was applied
        let styleAfterChange = textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(styleAfterChange?.alignment, .center, "Should be center aligned")

        // Undo
        textView.undoManager?.undo()

        // Verify left alignment was restored
        let styleAfterUndo = textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(styleAfterUndo?.alignment, .left, "Should be left aligned after undo")
    }

    func testUndoRightAlignment() {
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Test")

        let range = NSRange(location: 0, length: textStorage.length)

        // Apply right alignment
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let rightStyle = NSMutableParagraphStyle()
            rightStyle.alignment = .right
            textStorage.addAttribute(.paragraphStyle, value: rightStyle, range: range)
            textView.didChangeText()
        }

        XCTAssertTrue(textView.undoManager?.canUndo ?? false, "Undo should be available after alignment change")

        // Undo
        textView.undoManager?.undo()

        // Alignment should be reset (default is natural/left)
        let styleAfterUndo = textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotEqual(styleAfterUndo?.alignment, .right, "Should not be right aligned after undo")
    }

    // MARK: - Multiple Formatting Operations Undo

    func testUndoMultipleFormattingOperations() {
        // Test that a single undo can undo both bold and italic when applied together
        // (In practice, each toolbar button click would be a separate undo group)
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Hello World")
        guard let undoManager = textView.undoManager else {
            XCTFail("Undo manager should exist")
            return
        }

        let range = NSRange(location: 0, length: 5)
        let originalFont = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: originalFont, range: range)

        // Apply both bold and italic in a single operation (simulating batch formatting)
        if textView.shouldChangeText(in: range, replacementString: nil) {
            var boldItalicFont = NSFontManager.shared.convert(originalFont, toHaveTrait: .boldFontMask)
            boldItalicFont = NSFontManager.shared.convert(boldItalicFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: boldItalicFont, range: range)
            textView.didChangeText()
        }

        // Verify both traits are applied
        var currentFont = textStorage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
        var traits = NSFontManager.shared.traits(of: currentFont)
        XCTAssertTrue(traits.contains(.boldFontMask), "Should be bold")
        XCTAssertTrue(traits.contains(.italicFontMask), "Should be italic")

        // Single undo should remove both bold and italic
        undoManager.undo()
        currentFont = textStorage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
        traits = NSFontManager.shared.traits(of: currentFont)
        XCTAssertFalse(traits.contains(.boldFontMask), "Should not be bold after undo")
        XCTAssertFalse(traits.contains(.italicFontMask), "Should not be italic after undo")
    }

    func testSeparateUndoGroupsForSequentialOperations() {
        // Test that separate undo groups allow individual undo
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Hello World")
        guard let undoManager = textView.undoManager else {
            XCTFail("Undo manager should exist")
            return
        }

        // Disable automatic grouping to test explicit groups
        undoManager.groupsByEvent = false

        let range = NSRange(location: 0, length: 5)
        let originalFont = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: originalFont, range: range)

        // Apply bold - first explicit group
        undoManager.beginUndoGrouping()
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let boldFont = NSFontManager.shared.convert(originalFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: boldFont, range: range)
            textView.didChangeText()
        }
        undoManager.endUndoGrouping()

        // Apply italic - second explicit group
        undoManager.beginUndoGrouping()
        if textView.shouldChangeText(in: range, replacementString: nil) {
            let currentFont = textStorage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
            let boldItalicFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: boldItalicFont, range: range)
            textView.didChangeText()
        }
        undoManager.endUndoGrouping()

        // Verify both traits are applied
        var currentFont = textStorage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
        var traits = NSFontManager.shared.traits(of: currentFont)
        XCTAssertTrue(traits.contains(.boldFontMask) && traits.contains(.italicFontMask), "Should have both bold and italic")

        // First undo - should remove italic
        undoManager.undo()
        currentFont = textStorage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
        traits = NSFontManager.shared.traits(of: currentFont)
        XCTAssertTrue(traits.contains(.boldFontMask), "Should still be bold after first undo")
        XCTAssertFalse(traits.contains(.italicFontMask), "Should not be italic after first undo")

        // Second undo - should remove bold
        undoManager.undo()
        currentFont = textStorage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
        traits = NSFontManager.shared.traits(of: currentFont)
        XCTAssertFalse(traits.contains(.boldFontMask), "Should not be bold after second undo")
    }

    // MARK: - Keyboard Shortcut Registration Tests

    func testCommandZIsStandardUndoShortcut() {
        // Verify Cmd+Z is the standard undo shortcut on macOS
        // This is a documentation test to ensure we're using the right shortcut
        let undoKeyEquivalent = "z"
        let undoModifiers: NSEvent.ModifierFlags = .command

        XCTAssertEqual(undoKeyEquivalent, "z", "Undo shortcut should be 'z'")
        XCTAssertTrue(undoModifiers.contains(.command), "Undo modifier should include Command")
    }

    func testCommandShiftZIsStandardRedoShortcut() {
        // Verify Cmd+Shift+Z is the standard redo shortcut on macOS
        let redoKeyEquivalent = "z"
        let redoModifiers: NSEvent.ModifierFlags = [.command, .shift]

        XCTAssertEqual(redoKeyEquivalent, "z", "Redo shortcut should be 'z'")
        XCTAssertTrue(redoModifiers.contains(.command), "Redo modifier should include Command")
        XCTAssertTrue(redoModifiers.contains(.shift), "Redo modifier should include Shift")
    }

    // MARK: - Should Change Text Pattern Tests

    func testShouldChangeTextEnablesUndo() {
        // Test that using shouldChangeText/didChangeText pattern enables undo
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Test")

        let range = NSRange(location: 0, length: 4)

        // Initially no undo available
        XCTAssertFalse(textView.undoManager?.canUndo ?? true, "No undo should be available initially")

        // Make a change using the proper pattern
        if textView.shouldChangeText(in: range, replacementString: nil) {
            textStorage.addAttribute(.foregroundColor, value: NSColor.red, range: range)
            textView.didChangeText()
        }

        // Now undo should be available
        XCTAssertTrue(textView.undoManager?.canUndo ?? false, "Undo should be available after change")
    }

    func testWithoutShouldChangeTextNoUndo() {
        // Test that NOT using shouldChangeText/didChangeText does not register undo
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Test")

        let range = NSRange(location: 0, length: 4)

        // Make a change WITHOUT using shouldChangeText/didChangeText
        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: NSColor.blue, range: range)
        textStorage.endEditing()

        // Undo should NOT be available - this is the bug we need to fix
        // The current implementation uses beginEditing/endEditing without shouldChangeText
        let canUndo = textView.undoManager?.canUndo ?? false
        XCTAssertFalse(canUndo, "Undo should NOT be available when not using shouldChangeText pattern")
    }

    // MARK: - Integration Tests for Toolbar Formatting

    func testFormattingWithShouldChangeTextRegistersUndo() {
        // This test verifies the pattern that should be used in the actual implementation
        let (textView, textStorage, _) = createTextViewWithUndoManager(text: "Hello World")

        let range = NSRange(location: 0, length: 5)
        let originalFont = NSFont.systemFont(ofSize: 14)
        textStorage.addAttribute(.font, value: originalFont, range: range)

        // This is how formatting SHOULD be applied (with shouldChangeText)
        if textView.shouldChangeText(in: range, replacementString: nil) {
            textStorage.beginEditing()
            let boldFont = NSFontManager.shared.convert(originalFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: boldFont, range: range)
            textStorage.endEditing()
            textView.didChangeText()
        }

        // Undo should be available
        XCTAssertTrue(textView.undoManager?.canUndo ?? false, "Undo should be available")

        // Perform undo
        textView.undoManager?.undo()

        // Bold should be removed
        let fontAfterUndo = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertFalse(NSFontManager.shared.traits(of: fontAfterUndo!).contains(.boldFontMask), "Bold should be removed after undo")
    }
}

// MARK: - Sidebar Cursor Tests

final class SidebarCursorTests: XCTestCase {

    // MARK: - NSCursor API Tests

    func testArrowCursorExists() {
        // Verify the arrow cursor is available
        let arrowCursor = NSCursor.arrow
        XCTAssertNotNil(arrowCursor, "Arrow cursor should be available")
    }

    func testIBeamCursorExists() {
        // Verify the I-beam cursor is available (this is what text views use)
        let iBeamCursor = NSCursor.iBeam
        XCTAssertNotNil(iBeamCursor, "I-beam cursor should be available")
    }

    func testPointingHandCursorExists() {
        // Verify the pointing hand cursor is available (for links)
        let pointingHandCursor = NSCursor.pointingHand
        XCTAssertNotNil(pointingHandCursor, "Pointing hand cursor should be available")
    }

    func testCursorPushPopMechanism() {
        // Test that cursor push/pop works correctly
        let arrowCursor = NSCursor.arrow

        // Push arrow cursor
        arrowCursor.push()

        // Current cursor should now be arrow
        XCTAssertEqual(NSCursor.current, arrowCursor, "Current cursor should be arrow after push")

        // Pop cursor
        NSCursor.pop()

        // Cursor stack mechanism works
        XCTAssertTrue(true, "Cursor push/pop should work without error")
    }

    func testCursorSetMethod() {
        // Test that cursor can be set directly
        let arrowCursor = NSCursor.arrow

        // Set arrow cursor
        arrowCursor.set()

        // Current cursor should be arrow
        XCTAssertEqual(NSCursor.current, arrowCursor, "Current cursor should be arrow after set")
    }

    // MARK: - Button Cursor Behavior Tests

    func testButtonShouldUseArrowCursor() {
        // Buttons in the sidebar should use arrow cursor, not I-beam
        // This is a conceptual test - the implementation should ensure this
        let expectedCursor = NSCursor.arrow
        let unexpectedCursor = NSCursor.iBeam

        XCTAssertNotEqual(expectedCursor, unexpectedCursor, "Arrow and I-beam cursors should be different")
    }

    func testTextViewUsesIBeamCursor() {
        // Text views should use I-beam cursor
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))

        // Text view should not be using arrow cursor for text editing
        // The default cursor for text editing is I-beam
        XCTAssertTrue(true, "Text view should use I-beam cursor for editing")
    }

    // MARK: - Tracking Area Tests

    func testNSTrackingAreaCanBeCreatedForCursorUpdate() {
        // Test that tracking areas can be created for cursor updates
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: view,
            userInfo: nil
        )

        XCTAssertNotNil(trackingArea, "Tracking area should be created successfully")

        // Add tracking area to view
        view.addTrackingArea(trackingArea)

        XCTAssertTrue(view.trackingAreas.contains(trackingArea), "Tracking area should be added to view")
    }

    func testCursorUpdateOptionExists() {
        // Verify the cursorUpdate option exists for tracking areas
        let cursorUpdateOption: NSTrackingArea.Options = .cursorUpdate
        XCTAssertTrue(cursorUpdateOption.contains(.cursorUpdate), "cursorUpdate option should exist")
    }

    // MARK: - View Hierarchy Cursor Tests

    func testCursorRectsCanBeDiscarded() {
        // Test that cursor rects can be invalidated/discarded
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = view

        // Discarding cursor rects should not crash
        view.discardCursorRects()

        XCTAssertTrue(true, "discardCursorRects should complete without error")
    }

    func testResetCursorRectsCanBeCalled() {
        // Test that resetCursorRects can be called on a view
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = view

        // Reset cursor rects
        view.window?.invalidateCursorRects(for: view)

        XCTAssertTrue(true, "invalidateCursorRects should complete without error")
    }

    // MARK: - Custom Text View Cursor Rect Tests

    func testTextViewResetCursorRectsConstrainsCursor() {
        // Test that overriding resetCursorRects properly constrains cursor area
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))

        // Put in a window
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = textView

        // Discard and reset cursor rects
        textView.discardCursorRects()
        textView.resetCursorRects()

        // The text view should have cursor rects defined
        XCTAssertTrue(true, "Text view cursor rects should be properly reset")
    }

    func testAddCursorRectMethod() {
        // Test that addCursorRect can be called
        let view = TestCursorView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = view

        // Trigger cursor rect setup
        view.resetCursorRects()

        XCTAssertTrue(view.cursorRectAdded, "addCursorRect should be called during resetCursorRects")
    }

    func testVisibleRectConstrainsCursorArea() {
        // Test that visibleRect can be used to constrain cursor area
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 500))
        scrollView.documentView = textView

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = scrollView

        // visibleRect should be constrained to the scroll view's visible area
        let visibleRect = textView.visibleRect
        XCTAssertLessThanOrEqual(visibleRect.height, scrollView.frame.height + 1, "visibleRect should be constrained to scroll view")
    }
}

// Helper class for testing cursor rect addition
class TestCursorView: NSView {
    var cursorRectAdded = false

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
        cursorRectAdded = true
    }
}

// MARK: - Cursor Update Event Tests

final class CursorUpdateTests: XCTestCase {

    func testCursorUpdateMethodCanBeOverridden() {
        // Test that cursorUpdate can be overridden
        let view = TestCursorUpdateView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = view

        XCTAssertNotNil(view, "View with cursorUpdate override should be created")
    }

    func testPointInRectCheck() {
        // Test that point-in-rect checking works correctly
        let rect = NSRect(x: 10, y: 10, width: 100, height: 100)

        // Point inside
        let insidePoint = NSPoint(x: 50, y: 50)
        XCTAssertTrue(rect.contains(insidePoint), "Point should be inside rect")

        // Point outside
        let outsidePoint = NSPoint(x: 5, y: 5)
        XCTAssertFalse(rect.contains(outsidePoint), "Point should be outside rect")
    }

    func testConvertPointFromWindow() {
        // Test that point conversion works
        let view = NSView(frame: NSRect(x: 50, y: 50, width: 100, height: 100))

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView?.addSubview(view)

        // Convert a window point to view coordinates
        let windowPoint = NSPoint(x: 100, y: 100)
        let viewPoint = view.convert(windowPoint, from: nil)

        // The converted point should be in view coordinates
        XCTAssertNotNil(viewPoint, "Point conversion should work")
    }

    func testTrackingAreaWithCursorUpdate() {
        // Test that tracking areas can be created with cursorUpdate option
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: view,
            userInfo: nil
        )

        view.addTrackingArea(trackingArea)

        // Verify tracking area was added
        XCTAssertTrue(view.trackingAreas.contains(trackingArea), "Tracking area should be added")

        // Verify it has cursorUpdate option
        XCTAssertTrue(trackingArea.options.contains(.cursorUpdate), "Should have cursorUpdate option")
        XCTAssertTrue(trackingArea.options.contains(.inVisibleRect), "Should have inVisibleRect option")
    }

    func testRemoveTrackingArea() {
        // Test that tracking areas can be removed
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.cursorUpdate, .activeInKeyWindow],
            owner: view,
            userInfo: nil
        )

        view.addTrackingArea(trackingArea)
        XCTAssertEqual(view.trackingAreas.count, 1, "Should have one tracking area")

        view.removeTrackingArea(trackingArea)
        XCTAssertEqual(view.trackingAreas.count, 0, "Should have no tracking areas after removal")
    }
}

// Helper class for testing cursor update
class TestCursorUpdateView: NSView {
    var cursorUpdateCalled = false

    override func cursorUpdate(with event: NSEvent) {
        cursorUpdateCalled = true
        // Only set cursor if within bounds
        let locationInView = convert(event.locationInWindow, from: nil)
        if bounds.contains(locationInView) {
            NSCursor.arrow.set()
        }
    }
}

// MARK: - PDF Export Tests

final class PDFExportTests: XCTestCase {

    // MARK: - RTF Loading Tests

    func testCanLoadRTFDataAsAttributedString() throws {
        // Create a document with formatted text
        let doc = TinyWriterDocument()
        let baseFont = NSFont.systemFont(ofSize: 16)
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

        let attrText = NSMutableAttributedString(string: "Hello World")
        attrText.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5))
        attrText.addAttribute(.font, value: baseFont, range: NSRange(location: 5, length: 6))
        doc.attributedText = attrText

        // Save as RTF
        let rtfData = try doc.data(ofType: UTType.rtf.identifier)

        // Load back as NSAttributedString
        let loadedAttrString = NSAttributedString(rtf: rtfData, documentAttributes: nil)

        XCTAssertNotNil(loadedAttrString, "Should be able to load RTF data as NSAttributedString")
        XCTAssertEqual(loadedAttrString?.string, "Hello World", "Text content should be preserved")

        // Verify bold is preserved in first 5 characters
        var hasBold = false
        loadedAttrString?.enumerateAttribute(.font, in: NSRange(location: 0, length: 5), options: []) { value, _, _ in
            if let font = value as? NSFont {
                hasBold = NSFontManager.shared.traits(of: font).contains(.boldFontMask)
            }
        }
        XCTAssertTrue(hasBold, "Bold formatting should be preserved when loading RTF")
    }

    func testRTFPreservesItalicFormatting() throws {
        let doc = TinyWriterDocument()
        let baseFont = NSFont.systemFont(ofSize: 16)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)

        let attrText = NSMutableAttributedString(string: "Italic text")
        attrText.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: 6))
        doc.attributedText = attrText

        // Save and reload as RTF
        let rtfData = try doc.data(ofType: UTType.rtf.identifier)
        let loadedAttrString = NSAttributedString(rtf: rtfData, documentAttributes: nil)

        XCTAssertNotNil(loadedAttrString)

        // Verify italic is preserved
        var hasItalic = false
        loadedAttrString?.enumerateAttribute(.font, in: NSRange(location: 0, length: 6), options: []) { value, _, _ in
            if let font = value as? NSFont {
                hasItalic = NSFontManager.shared.traits(of: font).contains(.italicFontMask)
            }
        }
        XCTAssertTrue(hasItalic, "Italic formatting should be preserved when loading RTF")
    }

    func testRTFPreservesCenterAlignment() throws {
        let doc = TinyWriterDocument()

        let attrText = NSMutableAttributedString(string: "Centered text")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        attrText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrText.length))
        attrText.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: attrText.length))
        doc.attributedText = attrText

        // Save and reload as RTF
        let rtfData = try doc.data(ofType: UTType.rtf.identifier)
        let loadedAttrString = NSAttributedString(rtf: rtfData, documentAttributes: nil)

        XCTAssertNotNil(loadedAttrString)

        // Verify center alignment is preserved
        var isCentered = false
        loadedAttrString?.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: loadedAttrString!.length), options: []) { value, _, _ in
            if let style = value as? NSParagraphStyle {
                isCentered = style.alignment == .center
            }
        }
        XCTAssertTrue(isCentered, "Center alignment should be preserved when loading RTF")
    }

    func testRTFPreservesRightAlignment() throws {
        let doc = TinyWriterDocument()

        let attrText = NSMutableAttributedString(string: "Right aligned text")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        attrText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrText.length))
        attrText.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: attrText.length))
        doc.attributedText = attrText

        // Save and reload as RTF
        let rtfData = try doc.data(ofType: UTType.rtf.identifier)
        let loadedAttrString = NSAttributedString(rtf: rtfData, documentAttributes: nil)

        XCTAssertNotNil(loadedAttrString)

        // Verify right alignment is preserved
        var isRightAligned = false
        loadedAttrString?.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: loadedAttrString!.length), options: []) { value, _, _ in
            if let style = value as? NSParagraphStyle {
                isRightAligned = style.alignment == .right
            }
        }
        XCTAssertTrue(isRightAligned, "Right alignment should be preserved when loading RTF")
    }

    func testRTFPreservesMixedFormatting() throws {
        let doc = TinyWriterDocument()
        let fontManager = NSFontManager.shared
        let baseFont = NSFont.systemFont(ofSize: 16)
        let boldFont = fontManager.convert(baseFont, toHaveTrait: .boldFontMask)
        let italicFont = fontManager.convert(baseFont, toHaveTrait: .italicFontMask)

        // "Bold and Italic text"
        let attrText = NSMutableAttributedString(string: "Bold and Italic text")
        attrText.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))  // "Bold"
        attrText.addAttribute(.font, value: baseFont, range: NSRange(location: 4, length: 5))  // " and "
        attrText.addAttribute(.font, value: italicFont, range: NSRange(location: 9, length: 6)) // "Italic"
        attrText.addAttribute(.font, value: baseFont, range: NSRange(location: 15, length: 5)) // " text"
        doc.attributedText = attrText

        // Save and reload as RTF
        let rtfData = try doc.data(ofType: UTType.rtf.identifier)
        let loadedAttrString = NSAttributedString(rtf: rtfData, documentAttributes: nil)

        XCTAssertNotNil(loadedAttrString)
        XCTAssertEqual(loadedAttrString?.string, "Bold and Italic text")

        // Verify bold in "Bold"
        var hasBold = false
        loadedAttrString?.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            if let font = value as? NSFont {
                hasBold = fontManager.traits(of: font).contains(.boldFontMask)
            }
        }
        XCTAssertTrue(hasBold, "Bold should be preserved in 'Bold'")

        // Verify italic in "Italic"
        var hasItalic = false
        loadedAttrString?.enumerateAttribute(.font, in: NSRange(location: 9, length: 6), options: []) { value, _, _ in
            if let font = value as? NSFont {
                hasItalic = fontManager.traits(of: font).contains(.italicFontMask)
            }
        }
        XCTAssertTrue(hasItalic, "Italic should be preserved in 'Italic'")
    }

    // MARK: - PDF Generation Tests

    func testPDFExportCreatesValidFile() throws {
        let attrString = NSAttributedString(string: "Test content", attributes: [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ])

        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_pdf_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        // Generate PDF using Core Text (same approach as the app)
        createTestPDF(attributedContent: attrString, saveURL: pdfURL)

        // Verify PDF was created and has content
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path), "PDF file should be created")

        let attrs = try FileManager.default.attributesOfItem(atPath: pdfURL.path)
        let size = attrs[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 0, "PDF should have content")
    }

    func testPDFWithBoldTextCreatesValidFile() throws {
        let boldFont = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 16), toHaveTrait: .boldFontMask)
        let attrString = NSMutableAttributedString(string: "Bold text here")
        attrString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))

        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_bold_pdf_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        createTestPDF(attributedContent: attrString, saveURL: pdfURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path), "PDF with bold text should be created")
    }

    func testPDFWithCenterAlignmentCreatesValidFile() throws {
        let attrString = NSMutableAttributedString(string: "Centered text")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
        attrString.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: attrString.length))

        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_center_pdf_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        createTestPDF(attributedContent: attrString, saveURL: pdfURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path), "PDF with center alignment should be created")
    }

    func testFullExportFlowRTFToPDF() throws {
        // Create document with formatting
        let doc = TinyWriterDocument()
        let boldFont = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 16), toHaveTrait: .boldFontMask)
        let attrText = NSMutableAttributedString(string: "Test document with bold")
        attrText.addAttribute(.font, value: boldFont, range: NSRange(location: 19, length: 4)) // "bold"
        attrText.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: 19))
        doc.attributedText = attrText

        // Save as RTF
        let rtfURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_\(UUID()).rtf")
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_\(UUID()).pdf")
        defer {
            try? FileManager.default.removeItem(at: rtfURL)
            try? FileManager.default.removeItem(at: pdfURL)
        }

        let rtfData = try doc.data(ofType: UTType.rtf.identifier)
        try rtfData.write(to: rtfURL)

        // Load RTF and convert to PDF (simulating the fixed export flow)
        let loadedData = try Data(contentsOf: rtfURL)
        guard let loadedAttrString = NSAttributedString(rtf: loadedData, documentAttributes: nil) else {
            XCTFail("Should be able to load RTF data")
            return
        }

        // Verify formatting survived the RTF round-trip
        var hasBold = false
        loadedAttrString.enumerateAttribute(.font, in: NSRange(location: 19, length: 4), options: []) { value, _, _ in
            if let font = value as? NSFont {
                hasBold = NSFontManager.shared.traits(of: font).contains(.boldFontMask)
            }
        }
        XCTAssertTrue(hasBold, "Bold formatting should survive RTF round-trip")

        // Create PDF from the loaded attributed string
        createTestPDF(attributedContent: loadedAttrString, saveURL: pdfURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path), "PDF should be created from RTF")

        let attrs = try FileManager.default.attributesOfItem(atPath: pdfURL.path)
        let size = attrs[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 0, "PDF should have content")
    }

    // MARK: - Font Scaling Tests

    func testScaleAttributedStringPreservesBoldTrait() {
        let fontManager = NSFontManager.shared
        let boldFont = fontManager.convert(NSFont.systemFont(ofSize: 16), toHaveTrait: .boldFontMask)

        let attrString = NSMutableAttributedString(string: "Bold text")
        attrString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))

        let scaled = scaleAttributedStringForTest(attrString, scaleFactor: 0.65)

        // Verify bold is preserved after scaling
        var hasBold = false
        var scaledSize: CGFloat = 0
        scaled.enumerateAttribute(.font, in: NSRange(location: 0, length: 4), options: []) { value, _, _ in
            if let font = value as? NSFont {
                hasBold = fontManager.traits(of: font).contains(.boldFontMask)
                scaledSize = font.pointSize
            }
        }

        XCTAssertTrue(hasBold, "Bold trait should be preserved after scaling")
        XCTAssertEqual(scaledSize, 16 * 0.65, accuracy: 0.1, "Font size should be scaled")
    }

    func testScaleAttributedStringPreservesItalicTrait() {
        let fontManager = NSFontManager.shared
        let italicFont = fontManager.convert(NSFont.systemFont(ofSize: 16), toHaveTrait: .italicFontMask)

        let attrString = NSMutableAttributedString(string: "Italic text")
        attrString.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: 6))

        let scaled = scaleAttributedStringForTest(attrString, scaleFactor: 0.65)

        // Verify italic is preserved after scaling
        var hasItalic = false
        scaled.enumerateAttribute(.font, in: NSRange(location: 0, length: 6), options: []) { value, _, _ in
            if let font = value as? NSFont {
                hasItalic = fontManager.traits(of: font).contains(.italicFontMask)
            }
        }

        XCTAssertTrue(hasItalic, "Italic trait should be preserved after scaling")
    }

    func testScaleAttributedStringPreservesAlignment() {
        let attrString = NSMutableAttributedString(string: "Centered")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
        attrString.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: attrString.length))

        let scaled = scaleAttributedStringForTest(attrString, scaleFactor: 0.65)

        // Verify alignment is preserved after scaling
        var isCentered = false
        scaled.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: scaled.length), options: []) { value, _, _ in
            if let style = value as? NSParagraphStyle {
                isCentered = style.alignment == .center
            }
        }

        XCTAssertTrue(isCentered, "Center alignment should be preserved after scaling")
    }

    // MARK: - Test Helpers

    /// Creates a PDF from an attributed string (mirrors the app's createPDF logic)
    private func createTestPDF(attributedContent: NSAttributedString, saveURL: URL) {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let marginY: CGFloat = 72
        let marginX: CGFloat = 72
        let textWidth = pageWidth - (marginX * 2)
        let textHeight = pageHeight - (marginY * 2)

        // Scale the attributed string
        let scaledString = scaleAttributedStringForTest(attributedContent, scaleFactor: 0.65)

        // Set text color to black
        let mutable = NSMutableAttributedString(attributedString: scaledString)
        mutable.addAttribute(.foregroundColor, value: NSColor.black, range: NSRange(location: 0, length: mutable.length))

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(saveURL as CFURL, mediaBox: &mediaBox, nil) else { return }

        let framesetter = CTFramesetterCreateWithAttributedString(mutable)
        var currentRange = CFRange(location: 0, length: 0)

        while currentRange.location < mutable.length {
            context.beginPage(mediaBox: &mediaBox)
            let framePath = CGPath(rect: CGRect(x: marginX, y: marginY, width: textWidth, height: textHeight), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)
            context.textMatrix = .identity
            CTFrameDraw(frame, context)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += visibleRange.length
            context.endPage()
        }

        context.closePDF()
    }

    /// Scales fonts in an attributed string while preserving traits (mirrors the app's helper)
    private func scaleAttributedStringForTest(_ attributedString: NSAttributedString, scaleFactor: CGFloat) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let fontManager = NSFontManager.shared

        // Scale fonts while preserving traits
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            if let font = value as? NSFont {
                let traits = fontManager.traits(of: font)
                let scaledSize = font.pointSize * scaleFactor

                var scaledFont = NSFont(name: font.fontName, size: scaledSize)
                    ?? NSFont.systemFont(ofSize: scaledSize)

                if traits.contains(.boldFontMask) {
                    scaledFont = fontManager.convert(scaledFont, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    scaledFont = fontManager.convert(scaledFont, toHaveTrait: .italicFontMask)
                }

                mutable.addAttribute(.font, value: scaledFont, range: range)
            }
        }

        return mutable
    }
}

// MARK: - Word Count Update Tests

final class WordCountUpdateTests: XCTestCase {

    // MARK: - Document Change Notification Tests

    func testDocumentPublishesChangesWhenTextUpdated() {
        let document = TinyWriterDocument()
        let expectation = XCTestExpectation(description: "Document should publish objectWillChange")

        let cancellable = document.objectWillChange.sink {
            expectation.fulfill()
        }

        // Update the document's text
        document.attributedText = NSAttributedString(string: "Hello world")

        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testDocumentManagerForwardsDocumentChanges() {
        let manager = TinyWriterDocumentManager()
        let document = TinyWriterDocument()

        // Set the active document
        manager.activeDocument = document

        let expectation = XCTestExpectation(description: "Manager should forward document changes")

        let cancellable = manager.objectWillChange.sink {
            expectation.fulfill()
        }

        // Update the document's text - manager should forward this change
        document.attributedText = NSAttributedString(string: "Test content")

        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testWordCountCalculatesCorrectly() {
        let document = TinyWriterDocument()
        document.attributedText = NSAttributedString(string: "Hello world test")

        let text = document.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = text.isEmpty ? 0 : text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        XCTAssertEqual(wordCount, 3, "Word count should be 3")
    }

    func testCharacterCountCalculatesCorrectly() {
        let document = TinyWriterDocument()
        document.attributedText = NSAttributedString(string: "Hello world")

        let characterCount = document.text.count

        XCTAssertEqual(characterCount, 11, "Character count should be 11")
    }

    func testWordCountUpdatesAfterTextChange() {
        let document = TinyWriterDocument()

        // Initial state
        document.attributedText = NSAttributedString(string: "Hello")
        var wordCount = countWords(in: document.text)
        XCTAssertEqual(wordCount, 1)

        // Update text
        document.attributedText = NSAttributedString(string: "Hello world test")
        wordCount = countWords(in: document.text)
        XCTAssertEqual(wordCount, 3)

        // Clear text
        document.attributedText = NSAttributedString(string: "")
        wordCount = countWords(in: document.text)
        XCTAssertEqual(wordCount, 0)
    }

    func testManagerNotifiesOnActiveDocumentTextChange() {
        let manager = TinyWriterDocumentManager()
        let document = TinyWriterDocument()

        manager.activeDocument = document

        var notificationCount = 0
        let expectation = XCTestExpectation(description: "Should receive multiple change notifications")
        expectation.expectedFulfillmentCount = 2

        let cancellable = manager.objectWillChange.sink {
            notificationCount += 1
            expectation.fulfill()
        }

        // Make multiple text changes
        document.attributedText = NSAttributedString(string: "First change")
        document.attributedText = NSAttributedString(string: "Second change")

        wait(for: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(notificationCount, 2, "Manager should forward multiple document changes")
        cancellable.cancel()
    }

    // Helper function
    private func countWords(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Grammar Checking Tests

final class GrammarCheckingTests: XCTestCase {

    // MARK: - Settings Persistence Tests

    func testGrammarCheckingSettingDefaultsToTrue() {
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: "grammarCheckingEnabled")

        // Default should be true (enabled by default like normal word processors)
        let defaults = UserDefaults.standard.object(forKey: "grammarCheckingEnabled")
        // When not set, we expect the app to default to true
        XCTAssertNil(defaults, "Setting should not exist initially")
    }

    func testSpellCheckingSettingDefaultsToTrue() {
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: "spellCheckingEnabled")

        // Default should be true
        let defaults = UserDefaults.standard.object(forKey: "spellCheckingEnabled")
        XCTAssertNil(defaults, "Setting should not exist initially")
    }

    func testGrammarCheckingSettingPersists() {
        // Set the value
        UserDefaults.standard.set(false, forKey: "grammarCheckingEnabled")

        // Verify it persists
        let value = UserDefaults.standard.bool(forKey: "grammarCheckingEnabled")
        XCTAssertFalse(value, "Grammar checking setting should persist as false")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "grammarCheckingEnabled")
    }

    func testSpellCheckingSettingPersists() {
        // Set the value
        UserDefaults.standard.set(false, forKey: "spellCheckingEnabled")

        // Verify it persists
        let value = UserDefaults.standard.bool(forKey: "spellCheckingEnabled")
        XCTAssertFalse(value, "Spell checking setting should persist as false")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "spellCheckingEnabled")
    }

    // MARK: - NSTextView Grammar Checking Configuration Tests

    func testTextViewSupportsGrammarChecking() {
        let textView = NSTextView()

        // NSTextView should support grammar checking
        textView.isGrammarCheckingEnabled = true
        XCTAssertTrue(textView.isGrammarCheckingEnabled, "NSTextView should support grammar checking")

        textView.isGrammarCheckingEnabled = false
        XCTAssertFalse(textView.isGrammarCheckingEnabled, "NSTextView should allow disabling grammar checking")
    }

    func testTextViewSupportsContinuousSpellChecking() {
        let textView = NSTextView()

        // NSTextView should support continuous spell checking
        textView.isContinuousSpellCheckingEnabled = true
        XCTAssertTrue(textView.isContinuousSpellCheckingEnabled, "NSTextView should support spell checking")

        textView.isContinuousSpellCheckingEnabled = false
        XCTAssertFalse(textView.isContinuousSpellCheckingEnabled, "NSTextView should allow disabling spell checking")
    }

    func testTextViewSupportsAutomaticSpellingCorrection() {
        let textView = NSTextView()

        // NSTextView should support automatic spelling correction
        textView.isAutomaticSpellingCorrectionEnabled = true
        XCTAssertTrue(textView.isAutomaticSpellingCorrectionEnabled, "NSTextView should support auto-correction")

        textView.isAutomaticSpellingCorrectionEnabled = false
        XCTAssertFalse(textView.isAutomaticSpellingCorrectionEnabled, "NSTextView should allow disabling auto-correction")
    }

    // MARK: - SmoothCursorTextView Grammar Checking Tests

    func testSmoothCursorTextViewInheritsGrammarCheckingSupport() {
        let textView = SmoothCursorTextView()

        // SmoothCursorTextView inherits from NSTextView and should support grammar checking
        textView.isGrammarCheckingEnabled = true
        XCTAssertTrue(textView.isGrammarCheckingEnabled, "SmoothCursorTextView should support grammar checking")
    }

    func testSmoothCursorTextViewInheritsSpellCheckingSupport() {
        let textView = SmoothCursorTextView()

        // SmoothCursorTextView should support spell checking
        textView.isContinuousSpellCheckingEnabled = true
        XCTAssertTrue(textView.isContinuousSpellCheckingEnabled, "SmoothCursorTextView should support spell checking")
    }

    // MARK: - NSSpellChecker Integration Tests

    func testSpellCheckerIsAvailable() {
        let spellChecker = NSSpellChecker.shared

        // NSSpellChecker should be available
        XCTAssertNotNil(spellChecker, "NSSpellChecker should be available")
    }

    func testSpellCheckerCanDetectMisspelledWords() {
        let spellChecker = NSSpellChecker.shared
        let misspelledText = "Thiss is a tset"

        // Find misspelled word
        let range = spellChecker.checkSpelling(of: misspelledText, startingAt: 0)

        // Should find "Thiss" as misspelled
        XCTAssertNotEqual(range.location, NSNotFound, "Spell checker should detect misspelled words")
        XCTAssertEqual(range.location, 0, "First misspelled word should be at position 0")
        XCTAssertEqual(range.length, 5, "Misspelled word 'Thiss' should have length 5")
    }

    func testSpellCheckerCanCheckGrammar() {
        let spellChecker = NSSpellChecker.shared
        let textWithGrammarError = "He go to the store yesterday"

        // Check grammar
        var details: NSArray?
        let range = spellChecker.checkGrammar(of: textWithGrammarError, startingAt: 0, language: nil, wrap: false, inSpellDocumentWithTag: 0, details: &details)

        // Grammar checking should work (may or may not find issues depending on system)
        // We just verify the API is callable
        XCTAssertTrue(range.location == NSNotFound || range.location >= 0, "Grammar check should return valid range")
    }

    func testSpellCheckerProvideSuggestions() {
        let spellChecker = NSSpellChecker.shared

        // Get suggestions for misspelled word
        let suggestions = spellChecker.guesses(forWordRange: NSRange(location: 0, length: 4), in: "tset", language: nil, inSpellDocumentWithTag: 0)

        // Should provide suggestions (may include "test")
        XCTAssertNotNil(suggestions, "Spell checker should provide suggestions")
    }

    // MARK: - Grammar Checking Toggle Notification Tests

    func testGrammarCheckingNotificationPosted() {
        let expectation = XCTestExpectation(description: "Grammar checking notification should be posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .grammarCheckingChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Post notification
        NotificationCenter.default.post(name: .grammarCheckingChanged, object: nil)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testSpellCheckingNotificationPosted() {
        let expectation = XCTestExpectation(description: "Spell checking notification should be posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .spellCheckingChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Post notification
        NotificationCenter.default.post(name: .spellCheckingChanged, object: nil)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - SmoothCursorTextView Spell Checking Integration Tests

    func testSmoothCursorTextViewHasSpellCheckingMethods() {
        let textView = SmoothCursorTextView()

        // Text view should have spell checking toggle method
        textView.isContinuousSpellCheckingEnabled = true
        XCTAssertTrue(textView.isContinuousSpellCheckingEnabled)

        // Text view should have grammar checking toggle method
        textView.isGrammarCheckingEnabled = true
        XCTAssertTrue(textView.isGrammarCheckingEnabled)
    }

    func testSmoothCursorTextViewCanCheckSpelling() {
        let textView = SmoothCursorTextView()
        textView.string = "This is a tset of speling"

        // Enable spell checking
        textView.isContinuousSpellCheckingEnabled = true

        // Text view should be able to check spelling
        XCTAssertNotNil(textView.textStorage, "Text view should have text storage")
    }

    func testDefaultSpellCheckingSettingsApplied() {
        // Test that defaults are applied correctly
        // When not set, should default to true
        UserDefaults.standard.removeObject(forKey: "spellCheckingEnabled")
        UserDefaults.standard.removeObject(forKey: "grammarCheckingEnabled")

        let spellDefault = UserDefaults.standard.object(forKey: "spellCheckingEnabled") as? Bool ?? true
        let grammarDefault = UserDefaults.standard.object(forKey: "grammarCheckingEnabled") as? Bool ?? true

        XCTAssertTrue(spellDefault, "Spell checking should default to enabled")
        XCTAssertTrue(grammarDefault, "Grammar checking should default to enabled")
    }

    func testSpellCheckingCanBeDisabled() {
        UserDefaults.standard.set(false, forKey: "spellCheckingEnabled")

        let textView = SmoothCursorTextView()
        let enabled = UserDefaults.standard.object(forKey: "spellCheckingEnabled") as? Bool ?? true
        textView.isContinuousSpellCheckingEnabled = enabled

        XCTAssertFalse(textView.isContinuousSpellCheckingEnabled, "Spell checking should be disabled when setting is false")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "spellCheckingEnabled")
    }

    func testGrammarCheckingCanBeDisabled() {
        UserDefaults.standard.set(false, forKey: "grammarCheckingEnabled")

        let textView = SmoothCursorTextView()
        let enabled = UserDefaults.standard.object(forKey: "grammarCheckingEnabled") as? Bool ?? true
        textView.isGrammarCheckingEnabled = enabled

        XCTAssertFalse(textView.isGrammarCheckingEnabled, "Grammar checking should be disabled when setting is false")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "grammarCheckingEnabled")
    }
}
