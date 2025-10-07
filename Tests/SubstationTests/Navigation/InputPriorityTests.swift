import XCTest
@testable import Substation

@MainActor
final class InputPriorityTests: XCTestCase {

    // MARK: - Classification Tests

    func testClassifyNavigationKeys() {
        // Enter keys
        XCTAssertEqual(InputPriority.classify(10), .navigation, "Enter (LF) should be navigation")
        XCTAssertEqual(InputPriority.classify(13), .navigation, "Enter (CR) should be navigation")

        // Arrow keys
        XCTAssertEqual(InputPriority.classify(258), .navigation, "Down arrow should be navigation")
        XCTAssertEqual(InputPriority.classify(259), .navigation, "Up arrow should be navigation")

        // Page keys
        XCTAssertEqual(InputPriority.classify(338), .navigation, "Page Down should be navigation")
        XCTAssertEqual(InputPriority.classify(339), .navigation, "Page Up should be navigation")
    }

    func testClassifyTextInputKeys() {
        // Backspace
        XCTAssertEqual(InputPriority.classify(127), .textInput, "Backspace (127) should be textInput")
        XCTAssertEqual(InputPriority.classify(8), .textInput, "Backspace (8) should be textInput")

        // Alphanumeric
        XCTAssertEqual(InputPriority.classify(97), .textInput, "'a' should be textInput")  // 'a'
        XCTAssertEqual(InputPriority.classify(65), .textInput, "'A' should be textInput")  // 'A'
        XCTAssertEqual(InputPriority.classify(48), .textInput, "'0' should be textInput")  // '0'
        XCTAssertEqual(InputPriority.classify(57), .textInput, "'9' should be textInput")  // '9'

        // Space
        XCTAssertEqual(InputPriority.classify(32), .textInput, "Space should be textInput")

        // Punctuation in printable range
        XCTAssertEqual(InputPriority.classify(33), .textInput, "'!' should be textInput")
        XCTAssertEqual(InputPriority.classify(63), .textInput, "'?' should be textInput")
    }

    func testClassifyCommandActivation() {
        XCTAssertEqual(InputPriority.classify(58), .command, "':' should be command")
    }

    func testClassifyFallback() {
        // ESC
        XCTAssertEqual(InputPriority.classify(27), .fallback, "ESC should be fallback")

        // Tab
        XCTAssertEqual(InputPriority.classify(9), .fallback, "Tab should be fallback")

        // Control characters outside defined ranges
        XCTAssertEqual(InputPriority.classify(1), .fallback, "Ctrl-A should be fallback")
        XCTAssertEqual(InputPriority.classify(7), .fallback, "Ctrl-G should be fallback")

        // Extended ASCII
        XCTAssertEqual(InputPriority.classify(200), .fallback, "Extended ASCII should be fallback")
    }

    // MARK: - Helper Method Tests

    func testIsNavigation() {
        XCTAssertTrue(InputPriority.isNavigation(10), "Enter should be navigation")
        XCTAssertTrue(InputPriority.isNavigation(13), "Enter should be navigation")
        XCTAssertTrue(InputPriority.isNavigation(258), "Down should be navigation")
        XCTAssertTrue(InputPriority.isNavigation(259), "Up should be navigation")

        XCTAssertFalse(InputPriority.isNavigation(97), "'a' should not be navigation")
        XCTAssertFalse(InputPriority.isNavigation(27), "ESC should not be navigation")
    }

    func testIsTextInput() {
        XCTAssertTrue(InputPriority.isTextInput(97), "'a' should be text input")
        XCTAssertTrue(InputPriority.isTextInput(65), "'A' should be text input")
        XCTAssertTrue(InputPriority.isTextInput(48), "'0' should be text input")
        XCTAssertTrue(InputPriority.isTextInput(127), "Backspace should be text input")
        XCTAssertTrue(InputPriority.isTextInput(32), "Space should be text input")

        XCTAssertFalse(InputPriority.isTextInput(10), "Enter should not be text input")
        XCTAssertFalse(InputPriority.isTextInput(27), "ESC should not be text input")
    }

    func testIsCommandActivation() {
        XCTAssertTrue(InputPriority.isCommandActivation(58), "':' should activate command")

        XCTAssertFalse(InputPriority.isCommandActivation(47), "'/' should not activate command")
        XCTAssertFalse(InputPriority.isCommandActivation(97), "'a' should not activate command")
    }

    // MARK: - Key Description Tests

    func testDescribeNavigationKeys() {
        XCTAssertEqual(InputPriority.describe(10), "Enter")
        XCTAssertEqual(InputPriority.describe(13), "Enter")
        XCTAssertEqual(InputPriority.describe(258), "Down Arrow")
        XCTAssertEqual(InputPriority.describe(259), "Up Arrow")
        XCTAssertEqual(InputPriority.describe(260), "Left Arrow")
        XCTAssertEqual(InputPriority.describe(261), "Right Arrow")
        XCTAssertEqual(InputPriority.describe(338), "Page Down")
        XCTAssertEqual(InputPriority.describe(339), "Page Up")
    }

    func testDescribeControlKeys() {
        XCTAssertEqual(InputPriority.describe(27), "ESC")
        XCTAssertEqual(InputPriority.describe(9), "Tab")
        XCTAssertEqual(InputPriority.describe(127), "Backspace")
        XCTAssertEqual(InputPriority.describe(8), "Backspace")
        XCTAssertEqual(InputPriority.describe(32), "Space")
    }

    func testDescribeCommandKeys() {
        XCTAssertEqual(InputPriority.describe(58), ":")
    }

    func testDescribePrintableKeys() {
        XCTAssertEqual(InputPriority.describe(97), "'a'")
        XCTAssertEqual(InputPriority.describe(65), "'A'")
        XCTAssertEqual(InputPriority.describe(48), "'0'")
        XCTAssertEqual(InputPriority.describe(33), "'!'")
    }

    func testDescribeUnknownKeys() {
        let description = InputPriority.describe(500)
        XCTAssertTrue(description.contains("Unknown"), "Should indicate unknown key")
        XCTAssertTrue(description.contains("500"), "Should include key code")
    }

    // MARK: - Key Set Consistency Tests

    func testNavigationKeySetConsistency() {
        // All navigation keys should classify as navigation
        for key in InputPriority.navigationKeys {
            XCTAssertEqual(
                InputPriority.classify(key),
                .navigation,
                "Navigation key \(key) should classify as navigation"
            )
        }
    }

    func testTextEditingKeySetConsistency() {
        // All text editing keys should classify as textInput
        for key in InputPriority.textEditingKeys {
            XCTAssertEqual(
                InputPriority.classify(key),
                .textInput,
                "Text editing key \(key) should classify as textInput"
            )
        }
    }

    func testCommandActivationKeySetConsistency() {
        // All command activation keys should classify as command
        for key in InputPriority.commandActivationKeys {
            XCTAssertEqual(
                InputPriority.classify(key),
                .command,
                "Command key \(key) should classify as command"
            )
        }
    }

    // MARK: - Printable Range Tests

    func testPrintableRangeAllTextInput() {
        // All printable characters should be textInput (except : which is command)
        for key in InputPriority.printableRange {
            if key == 58 {
                // ':' is command activation
                XCTAssertEqual(InputPriority.classify(key), .command)
            } else {
                XCTAssertEqual(
                    InputPriority.classify(key),
                    .textInput,
                    "Printable key \(key) should be textInput"
                )
            }
        }
    }

    func testPrintableRangeBounds() {
        // Just below range
        XCTAssertNotEqual(InputPriority.classify(31), .textInput, "Below printable range")

        // Lower bound
        XCTAssertEqual(InputPriority.classify(32), .textInput, "Space (lower bound)")

        // Upper bound
        XCTAssertEqual(InputPriority.classify(126), .textInput, "'~' (upper bound)")

        // Just above range
        XCTAssertNotEqual(InputPriority.classify(127), .navigation, "Backspace is textInput, not navigation")
    }

    // MARK: - Edge Cases

    func testNegativeKeyCode() {
        // Should handle gracefully
        let category = InputPriority.classify(-1)
        XCTAssertEqual(category, .fallback, "Negative key should be fallback")
    }

    func testZeroKeyCode() {
        let category = InputPriority.classify(0)
        XCTAssertEqual(category, .fallback, "Zero key should be fallback")
    }

    func testVeryLargeKeyCode() {
        let category = InputPriority.classify(10000)
        XCTAssertEqual(category, .fallback, "Large key code should be fallback")
    }

    // MARK: - No Overlap Tests

    func testKeySetsDontOverlap() {
        // Navigation and textEditing shouldn't overlap
        let navAndText = InputPriority.navigationKeys.intersection(InputPriority.textEditingKeys)
        XCTAssertTrue(navAndText.isEmpty, "Navigation and text editing keys shouldn't overlap")

        // Navigation and command shouldn't overlap
        let navAndCommand = InputPriority.navigationKeys.intersection(InputPriority.commandActivationKeys)
        XCTAssertTrue(navAndCommand.isEmpty, "Navigation and command keys shouldn't overlap")

        // TextEditing and command shouldn't overlap
        let textAndCommand = InputPriority.textEditingKeys.intersection(InputPriority.commandActivationKeys)
        XCTAssertTrue(textAndCommand.isEmpty, "Text editing and command keys shouldn't overlap")
    }

    // MARK: - Complete Coverage Tests

    func testCommonKeysHaveCategories() {
        // Ensure all commonly used keys have a defined category
        let commonKeys: [Int32] = [
            10, 13,      // Enter
            27,          // ESC
            9,           // Tab
            32,          // Space
            127, 8,      // Backspace
            258, 259,    // Arrows
            260, 261,    // Arrows
            338, 339,    // Page Up/Down
            58,          // Colon
            47,          // Slash
            97, 65,      // a, A
            48, 57,      // 0, 9
        ]

        for key in commonKeys {
            let category = InputPriority.classify(key)
            XCTAssertNotNil(category, "Common key \(key) should have a category")
        }
    }

    // MARK: - Performance Tests

    func testClassifyPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = InputPriority.classify(97)  // 'a'
                _ = InputPriority.classify(10)  // Enter
                _ = InputPriority.classify(258) // Down
                _ = InputPriority.classify(27)  // ESC
            }
        }
    }

    func testDescribePerformance() {
        measure {
            for _ in 0..<1000 {
                _ = InputPriority.describe(97)
                _ = InputPriority.describe(10)
                _ = InputPriority.describe(258)
                _ = InputPriority.describe(999)
            }
        }
    }

    // MARK: - Integration Tests

    func testTypicalInputFlow() {
        // Simulate typical user input flow

        // User presses ':'
        var category = InputPriority.classify(58)
        XCTAssertEqual(category, .command, "Should activate command mode")

        // User types 'servers'
        for char in "servers" {
            let keyCode = Int32(char.asciiValue!)
            category = InputPriority.classify(keyCode)
            XCTAssertEqual(category, .textInput, "Letters should be text input")
        }

        // User presses Enter
        category = InputPriority.classify(13)
        XCTAssertEqual(category, .navigation, "Enter should be navigation")
    }

    func testSearchInputFlow() {
        // User types search text
        for char in "test query" {
            let keyCode = Int32(char.asciiValue!)
            let category = InputPriority.classify(keyCode)

            if char == " " {
                XCTAssertEqual(category, .textInput, "Space should be text input")
            } else {
                XCTAssertEqual(category, .textInput, "Letters should be text input")
            }
        }

        // User navigates results
        let downCategory = InputPriority.classify(258)
        XCTAssertEqual(downCategory, .navigation, "Down should be navigation")

        // User selects result
        let enterCategory = InputPriority.classify(13)
        XCTAssertEqual(enterCategory, .navigation, "Enter should be navigation")
    }

    // MARK: - Documentation Tests

    func testAllNavigationKeysDescribed() {
        // All navigation keys should have meaningful descriptions
        for key in InputPriority.navigationKeys {
            let description = InputPriority.describe(key)
            XCTAssertFalse(
                description.contains("Unknown"),
                "Navigation key \(key) should have a proper description, not '\(description)'"
            )
        }
    }

    func testAllControlKeysDescribed() {
        // Common control keys should have descriptions
        let controlKeys: [Int32] = [27, 9, 127, 8, 32]

        for key in controlKeys {
            let description = InputPriority.describe(key)
            XCTAssertFalse(
                description.contains("Unknown"),
                "Control key \(key) should have a description, not '\(description)'"
            )
        }
    }
}
