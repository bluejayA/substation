import XCTest
@testable import Substation

@MainActor
final class CommandModeTests: XCTestCase {

    // MARK: - Setup

    // Helper to create fresh CommandMode for each test
    func makeCommandMode() -> CommandMode {
        let commandMode = CommandMode()
        // Clear any persisted history to ensure clean test state
        commandMode.clearHistory()
        return commandMode
    }

    // MARK: - Command Execution Tests

    func testExecuteValidCommand() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("servers")

        if case .navigateToView(let view) = result {
            XCTAssertEqual(view, .servers, "Should navigate to servers view")
        } else {
            XCTFail("Should return navigateToView result")
        }
    }

    func testExecuteCommandWithAlias() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("srv")

        if case .navigateToView(let view) = result {
            XCTAssertEqual(view, .servers, "Alias 'srv' should navigate to servers")
        } else {
            XCTFail("Should return navigateToView result")
        }
    }

    func testExecuteMultipleCommands() {
        let commandMode = makeCommandMode()
        let commands = ["servers", "networks", "volumes", "images"]

        for command in commands {
            let result = commandMode.executeCommand(command)

            switch result {
            case .navigateToView:
                // Success
                break
            default:
                XCTFail("Command '\(command)' should navigate to view")
            }
        }
    }

    // MARK: - Special Commands Tests

    func testQuitCommand() {
        let commandMode = makeCommandMode()
        let quitCommands = ["q", "quit", "exit"]

        for command in quitCommands {
            let result = commandMode.executeCommand(command)

            if case .quit = result {
                // Success
            } else {
                XCTFail("'\(command)' should return .quit")
            }
        }
    }

    func testHelpCommand() {
        let commandMode = makeCommandMode()
        let helpCommands = ["help", "?"]

        for command in helpCommands {
            let result = commandMode.executeCommand(command)

            if case .showHelp = result {
                // Success
            } else {
                XCTFail("'\(command)' should return .showHelp")
            }
        }
    }

    func testCommandsListCommand() {
        let commandMode = makeCommandMode()
        let listCommands = ["commands", "list"]

        for command in listCommands {
            let result = commandMode.executeCommand(command)

            if case .showCommands = result {
                // Success
            } else {
                XCTFail("'\(command)' should return .showCommands")
            }
        }
    }

    func testEmptyCommand() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("")

        if case .showCommands = result {
            // Success - empty command shows command list
        } else {
            XCTFail("Empty command should return .showCommands")
        }
    }

    // MARK: - Invalid Command Tests

    func testInvalidCommand() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("invalidcommand")

        if case .error(let message) = result {
            XCTAssertTrue(message.contains("Unknown command"), "Should indicate unknown command")
        } else {
            XCTFail("Invalid command should return .error")
        }
    }

    // MARK: - Prefix Matching Tests

    func testPrefixMatch() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("ser")

        if case .navigateToView(let view) = result {
            XCTAssertEqual(view, .servers, "Prefix 'ser' should match 'servers'")
        } else {
            XCTFail("Prefix match should work")
        }
    }

    func testPrefixMatchFlavors() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("fla")

        if case .navigateToView(let view) = result {
            XCTAssertEqual(view, .flavors, "Prefix 'fla' should match 'flavors'")
        } else {
            XCTFail("Prefix match should work for flavors")
        }
    }

    // MARK: - Fuzzy Match Tests

    func testFuzzyMatchSuggestion() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("servrs")

        if case .suggestion(let original, let suggested) = result {
            XCTAssertEqual(original, "servrs", "Should preserve original input")
            XCTAssertEqual(suggested, "servers", "Should suggest 'servers'")
        } else {
            XCTFail("Typo should return suggestion")
        }
    }

    // MARK: - Command History Tests

    func testCommandHistory() {
        let commandMode = makeCommandMode()
        // Execute some commands
        _ = commandMode.executeCommand("servers")
        _ = commandMode.executeCommand("networks")
        _ = commandMode.executeCommand("volumes")

        // Navigate backward
        let prev1 = commandMode.previousCommand()
        XCTAssertEqual(prev1, "volumes", "Should get most recent command")

        let prev2 = commandMode.previousCommand()
        XCTAssertEqual(prev2, "networks", "Should get second most recent")

        let prev3 = commandMode.previousCommand()
        XCTAssertEqual(prev3, "servers", "Should get third most recent")
    }

    func testCommandHistoryForward() {
        let commandMode = makeCommandMode()
        // Execute commands
        _ = commandMode.executeCommand("servers")
        _ = commandMode.executeCommand("networks")

        // Go back
        _ = commandMode.previousCommand()
        _ = commandMode.previousCommand()

        // Go forward
        let next1 = commandMode.nextCommand()
        XCTAssertEqual(next1, "networks", "Should go forward in history")
    }

    func testCommandHistoryBounds() {
        let commandMode = makeCommandMode()
        // Empty history
        let prev = commandMode.previousCommand()
        XCTAssertNil(prev, "Should return nil when no history")

        let next = commandMode.nextCommand()
        XCTAssertEqual(next, "", "Should return empty string at end of history")
    }

    func testCommandHistoryNoDuplicates() {
        let commandMode = makeCommandMode()
        // Execute same command twice
        _ = commandMode.executeCommand("servers")
        _ = commandMode.executeCommand("servers")

        // Should only have one entry
        let prev1 = commandMode.previousCommand()
        XCTAssertEqual(prev1, "servers")

        let prev2 = commandMode.previousCommand()
        XCTAssertNil(prev2, "Should not duplicate consecutive commands")
    }

    func testCommandHistoryReset() {
        let commandMode = makeCommandMode()
        _ = commandMode.executeCommand("servers")
        _ = commandMode.previousCommand()

        commandMode.resetHistoryPosition()

        let prev = commandMode.previousCommand()
        XCTAssertEqual(prev, "servers", "Reset should allow re-navigation")
    }

    // MARK: - Tab Completion Tests

    func testTabCompletionSingleMatch() async {
        let commandMode = makeCommandMode()
        let completion = await commandMode.completeCommand("dashb")
        XCTAssertNotNil(completion, "Should complete 'dashb'")
        XCTAssertEqual(completion, "dashboard", "Should complete to 'dashboard'")
    }

    func testTabCompletionMultipleMatches() async {
        let commandMode = makeCommandMode()
        let completion1 = await commandMode.completeCommand("se")
        XCTAssertNotNil(completion1, "Should return first match")

        // Tab again with the completion result should cycle to next match
        if let c1 = completion1 {
            let completion2 = await commandMode.completeCommand(c1)
            XCTAssertNotNil(completion2, "Should return second match")

            // Second completion should be different from first (cycling)
            if let c2 = completion2 {
                XCTAssertNotEqual(c1, c2, "Should cycle to different completion")
            }
        }
    }

    func testTabCompletionNoMatch() async {
        let commandMode = makeCommandMode()
        let completion = await commandMode.completeCommand("xyz")
        XCTAssertNil(completion, "Should return nil for no matches")
    }

    func testTabCompletionReset() async {
        let commandMode = makeCommandMode()
        _ = await commandMode.completeCommand("ser")

        commandMode.resetTabCompletion()

        let matches = commandMode.getCompletionMatches()
        XCTAssertTrue(matches.isEmpty, "Reset should clear matches")
    }

    func testTabCompletionState() async {
        let commandMode = makeCommandMode()
        _ = await commandMode.completeCommand("ser")

        let inCompletion = commandMode.isInTabCompletion()
        XCTAssertTrue(inCompletion, "Should be in tab completion mode")

        let matches = commandMode.getCompletionMatches()
        XCTAssertFalse(matches.isEmpty, "Should have completion matches")

        let index = commandMode.getCompletionIndex()
        XCTAssertGreaterThanOrEqual(index, 0, "Should have valid completion index")
    }

    func testTabCompletionHint() async {
        let commandMode = makeCommandMode()
        _ = await commandMode.completeCommand("ser")

        let hint = commandMode.getTabCompletionHint()
        XCTAssertFalse(hint.isEmpty, "Should provide completion hint")
        XCTAssertTrue(hint.contains("Tab"), "Hint should mention Tab key")
    }

    // MARK: - Command Parsing Tests

    func testParseSimpleCommand() {
        let commandMode = makeCommandMode()
        let parsed = commandMode.parseCommand("servers")
        XCTAssertEqual(parsed.command, "servers", "Should parse command")
        XCTAssertTrue(parsed.args.isEmpty, "Should have no arguments")
    }

    func testParseCommandWithArgs() {
        let commandMode = makeCommandMode()
        let parsed = commandMode.parseCommand("create server arg1 arg2")
        XCTAssertEqual(parsed.command, "create", "Should parse command")
        XCTAssertEqual(parsed.args, ["server", "arg1", "arg2"], "Should parse arguments")
    }

    // MARK: - Validation Tests

    func testIsValidCommand() {
        let commandMode = makeCommandMode()
        XCTAssertTrue(commandMode.isValidCommand("servers"), "'servers' should be valid")
        XCTAssertTrue(commandMode.isValidCommand("networks"), "'networks' should be valid")
        XCTAssertTrue(commandMode.isValidCommand("q"), "'q' should be valid (quit)")
        XCTAssertTrue(commandMode.isValidCommand("help"), "'help' should be valid")

        XCTAssertFalse(commandMode.isValidCommand("invalid"), "'invalid' should not be valid")
        XCTAssertFalse(commandMode.isValidCommand("xyz"), "'xyz' should not be valid")
    }

    // MARK: - Help Generation Tests

    func testGetQuickHelp() {
        let commandMode = makeCommandMode()
        let help = commandMode.getQuickHelp()
        XCTAssertFalse(help.isEmpty, "Should return quick help text")
        XCTAssertTrue(help.contains("help"), "Should mention help command")
    }

    func testGetCommandList() {
        let commandMode = makeCommandMode()
        let list = commandMode.getCommandList()
        XCTAssertFalse(list.isEmpty, "Should return command list")
        XCTAssertTrue(list.contains("servers") || list.contains("command"), "Should mention commands")
    }

    func testGetDetailedHelp() {
        let commandMode = makeCommandMode()
        let help = commandMode.getDetailedHelp()
        XCTAssertFalse(help.isEmpty, "Should return detailed help")
        XCTAssertTrue(help.contains("servers"), "Should include server commands")
        XCTAssertTrue(help.contains("Tab"), "Should mention tab completion")
    }

    // MARK: - Contextual Suggestions Tests

    func testContextualSuggestionsFromServers() {
        let commandMode = makeCommandMode()
        let suggestions = commandMode.getContextualSuggestions(currentView: .servers)
        XCTAssertFalse(suggestions.isEmpty, "Should return suggestions")
        XCTAssertTrue(suggestions.contains("flavors"), "Should suggest flavors from servers")
        XCTAssertTrue(suggestions.contains("images"), "Should suggest images from servers")
    }

    func testContextualSuggestionsFromNetworks() {
        let commandMode = makeCommandMode()
        let suggestions = commandMode.getContextualSuggestions(currentView: .networks)
        XCTAssertFalse(suggestions.isEmpty, "Should return suggestions")
        XCTAssertTrue(suggestions.contains("subnets"), "Should suggest subnets from networks")
        XCTAssertTrue(suggestions.contains("ports"), "Should suggest ports from networks")
    }

    func testContextualSuggestionsFromDashboard() {
        let commandMode = makeCommandMode()
        let suggestions = commandMode.getContextualSuggestions(currentView: .dashboard)
        XCTAssertFalse(suggestions.isEmpty, "Should return suggestions")
        XCTAssertTrue(suggestions.contains("servers"), "Should suggest servers from dashboard")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitiveExecution() {
        let commandMode = makeCommandMode()
        let results = [
            commandMode.executeCommand("SERVERS"),
            commandMode.executeCommand("Servers"),
            commandMode.executeCommand("SeRvErS")
        ]

        for result in results {
            if case .navigateToView(let view) = result {
                XCTAssertEqual(view, .servers, "Case should not matter")
            } else {
                XCTFail("Case insensitive command should work")
            }
        }
    }

    // MARK: - Whitespace Handling Tests

    func testTrimWhitespace() {
        let commandMode = makeCommandMode()
        let results = [
            commandMode.executeCommand(" servers "),
            commandMode.executeCommand("  servers  "),
            commandMode.executeCommand("\tservers\t")
        ]

        for result in results {
            if case .navigateToView(let view) = result {
                XCTAssertEqual(view, .servers, "Whitespace should be trimmed")
            } else {
                XCTFail("Whitespace trimming should work")
            }
        }
    }

    // MARK: - Performance Tests

    func testExecuteCommandPerformance() {
        let commandMode = makeCommandMode()
        measure {
            for _ in 0..<1000 {
                _ = commandMode.executeCommand("servers")
            }
        }
    }

    func testTabCompletionPerformance() async {
        let commandMode = makeCommandMode()
        // Performance test for tab completion
        for _ in 0..<100 {
            _ = await commandMode.completeCommand("ser")
            commandMode.resetTabCompletion()
        }
    }

    // MARK: - Edge Cases

    func testVeryLongCommand() {
        let commandMode = makeCommandMode()
        let longCommand = String(repeating: "a", count: 1000)
        let result = commandMode.executeCommand(longCommand)

        if case .error = result {
            // Expected - long command should error
        } else if case .suggestion = result {
            // Also acceptable - might suggest something
        } else {
            XCTFail("Very long command should error or suggest")
        }
    }

    func testSpecialCharactersInCommand() {
        let commandMode = makeCommandMode()
        let result = commandMode.executeCommand("@#$%")

        if case .error = result {
            // Expected
        } else {
            XCTFail("Special characters should error")
        }
    }

    // MARK: - Integration Tests

    func testCompleteWorkflow() async {
        let commandMode = makeCommandMode()
        // Typical user workflow
        _ = commandMode.executeCommand("servers")
        _ = commandMode.executeCommand("networks")

        // Use history
        let prev = commandMode.previousCommand()
        XCTAssertEqual(prev, "networks")

        // Use tab completion
        let completion = await commandMode.completeCommand("fla")
        XCTAssertNotNil(completion, "Should complete 'fla'")

        // Execute suggested command
        let result = commandMode.executeCommand("flavors")
        if case .navigateToView(let view) = result {
            XCTAssertEqual(view, .flavors)
        } else {
            XCTFail("Should navigate to flavors")
        }
    }

    func testSuggestionWorkflow() {
        let commandMode = makeCommandMode()
        // User makes typo
        let result = commandMode.executeCommand("servrs")

        if case .suggestion(_, let suggested) = result {
            // User accepts suggestion
            let retry = commandMode.executeCommand(suggested)
            if case .navigateToView(let view) = retry {
                XCTAssertEqual(view, .servers, "Suggested command should work")
            } else {
                XCTFail("Suggested command should navigate")
            }
        } else {
            XCTFail("Should get suggestion for typo")
        }
    }
}
