import XCTest
@testable import Substation

@MainActor
final class ResourceRegistryTests: XCTestCase {

    // MARK: - Setup

    let registry = ResourceRegistry.shared

    // MARK: - Exact Match Tests

    func testExactMatchServers() {
        let result = registry.resolve("servers")
        XCTAssertEqual(result, .servers, "Exact match 'servers' should resolve to .servers")
    }

    func testExactMatchNetworks() {
        let result = registry.resolve("networks")
        XCTAssertEqual(result, .networks, "Exact match 'networks' should resolve to .networks")
    }

    func testExactMatchVolumes() {
        let result = registry.resolve("volumes")
        XCTAssertEqual(result, .volumes, "Exact match 'volumes' should resolve to .volumes")
    }

    func testExactMatchFlavors() {
        let result = registry.resolve("flavors")
        XCTAssertEqual(result, .flavors, "Exact match 'flavors' should resolve to .flavors")
    }

    // MARK: - Alias Tests

    func testAliasMatchServers() {
        XCTAssertEqual(registry.resolve("server"), .servers, "Alias 'server' should resolve to .servers")
        XCTAssertEqual(registry.resolve("srv"), .servers, "Alias 'srv' should resolve to .servers")
        XCTAssertEqual(registry.resolve("s"), .servers, "Alias 's' should resolve to .servers")
        XCTAssertEqual(registry.resolve("nova"), .servers, "Alias 'nova' should resolve to .servers")
    }

    func testAliasMatchFlavors() {
        XCTAssertEqual(registry.resolve("flavor"), .flavors, "Alias 'flavor' should resolve to .flavors")
        XCTAssertEqual(registry.resolve("flv"), .flavors, "Alias 'flv' should resolve to .flavors")
        XCTAssertEqual(registry.resolve("f"), .flavors, "Alias 'f' should resolve to .flavors")
    }

    func testAliasMatchNetworks() {
        XCTAssertEqual(registry.resolve("network"), .networks, "Alias 'network' should resolve to .networks")
        XCTAssertEqual(registry.resolve("net"), .networks, "Alias 'net' should resolve to .networks")
        XCTAssertEqual(registry.resolve("n"), .networks, "Alias 'n' should resolve to .networks")
        XCTAssertEqual(registry.resolve("neutron"), .networks, "Alias 'neutron' should resolve to .networks")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitiveMatch() {
        XCTAssertEqual(registry.resolve("SERVERS"), .servers, "Uppercase 'SERVERS' should resolve")
        XCTAssertEqual(registry.resolve("Servers"), .servers, "Mixed case 'Servers' should resolve")
        XCTAssertEqual(registry.resolve("SeRvErS"), .servers, "Random case should resolve")
    }

    // MARK: - Invalid Match Tests

    func testInvalidCommand() {
        XCTAssertNil(registry.resolve("invalidcommand"), "Invalid command should return nil")
        XCTAssertNil(registry.resolve("xyz"), "Random string should return nil")
        XCTAssertNil(registry.resolve(""), "Empty string should return nil")
    }

    // MARK: - Fuzzy Match Tests

    func testFuzzyMatchTypo() {
        let result = registry.fuzzyMatch("servrs")
        XCTAssertEqual(result, "servers", "Typo 'servrs' should suggest 'servers'")
    }

    func testFuzzyMatchCloseMatch() {
        let result = registry.fuzzyMatch("flavr")
        XCTAssertNotNil(result, "Close match should return a suggestion")
        XCTAssertTrue(result == "flavor" || result == "flavors", "Should suggest flavor-related command")
    }

    func testFuzzyMatchNoSuggestion() {
        let result = registry.fuzzyMatch("zzzzzzz")
        XCTAssertNil(result, "Very different string should return nil")
    }

    // MARK: - Match Score Tests

    func testMatchScoreExact() {
        let score = registry.matchScore(command: "servers", query: "servers")
        XCTAssertEqual(score, 100, "Exact match should score 100")
    }

    func testMatchScorePrefix() {
        let score = registry.matchScore(command: "servers", query: "ser")
        XCTAssertGreaterThan(score, 80, "Prefix match should score > 80")
        XCTAssertLessThan(score, 100, "Prefix match should score < 100")
    }

    func testMatchScoreContains() {
        let score = registry.matchScore(command: "servers", query: "ver")
        XCTAssertGreaterThan(score, 30, "Contains match should score > 30")
        XCTAssertLessThan(score, 80, "Contains match should score < 80")
    }

    func testMatchScoreNoMatch() {
        let score = registry.matchScore(command: "servers", query: "xyz")
        XCTAssertEqual(score, 0, "No match should score 0")
    }

    // MARK: - Ranked Matches Tests

    func testRankedMatchesForPrefix() {
        let matches = registry.rankedMatches(for: "fla")
        XCTAssertFalse(matches.isEmpty, "Should return matches for 'fla'")

        if let firstMatch = matches.first {
            XCTAssertEqual(firstMatch.viewMode, .flavors, "First match should be flavors")
            XCTAssertGreaterThan(firstMatch.score, 80, "First match should have high score")
        }
    }

    func testRankedMatchesOrdering() {
        let matches = registry.rankedMatches(for: "ser")

        // Verify sorting: higher scores first
        for i in 0..<(matches.count - 1) {
            XCTAssertGreaterThanOrEqual(matches[i].score, matches[i + 1].score,
                                       "Matches should be sorted by score (descending)")
        }
    }

    func testRankedMatchesLimit() {
        let matches = registry.rankedMatches(for: "s", limit: 5)
        XCTAssertLessThanOrEqual(matches.count, 5, "Should respect limit parameter")
    }

    func testRankedMatchesEmptyQuery() {
        let matches = registry.rankedMatches(for: "")
        XCTAssertTrue(matches.isEmpty, "Empty query should return no matches")
    }

    // MARK: - All Commands Tests

    func testAllCommands() {
        let commands = registry.allCommands()
        XCTAssertFalse(commands.isEmpty, "Should return list of all commands")
        XCTAssertTrue(commands.contains("servers"), "Should include 'servers'")
        XCTAssertTrue(commands.contains("networks"), "Should include 'networks'")
        XCTAssertTrue(commands.contains("volumes"), "Should include 'volumes'")
    }

    func testAllCommandsAreSorted() {
        let commands = registry.allCommands()
        let sorted = commands.sorted()
        XCTAssertEqual(commands, sorted, "Commands should be sorted alphabetically")
    }

    // MARK: - Primary Commands Tests

    func testPrimaryCommands() {
        let primary = registry.primaryCommands()
        XCTAssertFalse(primary.isEmpty, "Should return primary commands")

        // Primary commands should be the longest aliases
        for command in primary {
            XCTAssertGreaterThan(command.count, 1, "Primary commands should not be single-letter")
        }
    }

    // MARK: - Aliases Tests

    func testAliasesForViewMode() {
        let serverAliases = registry.aliases(for: .servers)
        XCTAssertFalse(serverAliases.isEmpty, "Servers should have aliases")
        XCTAssertTrue(serverAliases.contains("servers"), "Should include full name")
        XCTAssertTrue(serverAliases.contains("server"), "Should include singular")
        XCTAssertTrue(serverAliases.contains("srv"), "Should include short form")
        XCTAssertTrue(serverAliases.contains("s"), "Should include single letter")
    }

    func testAliasesAreSorted() {
        let aliases = registry.aliases(for: .servers)
        let sorted = aliases.sorted()
        XCTAssertEqual(aliases, sorted, "Aliases should be sorted alphabetically")
    }

    // MARK: - Suggestions Tests

    func testSuggestionsForPartial() {
        let suggestions = registry.suggestions(for: "ser", limit: 5)
        XCTAssertFalse(suggestions.isEmpty, "Should return suggestions for 'ser'")
        XCTAssertLessThanOrEqual(suggestions.count, 5, "Should respect limit")

        // All suggestions should start with or contain the query
        for suggestion in suggestions {
            XCTAssertTrue(
                suggestion.hasPrefix("ser") || suggestion.contains("ser"),
                "Suggestion '\(suggestion)' should contain 'ser'"
            )
        }
    }

    func testSuggestionsEmpty() {
        let suggestions = registry.suggestions(for: "")
        XCTAssertTrue(suggestions.isEmpty, "Empty query should return no suggestions")
    }

    // MARK: - Help Text Tests

    func testHelpTextForCommand() {
        let help = registry.helpText(for: "servers")
        XCTAssertNotNil(help, "Should return help text for valid command")
        XCTAssertTrue(help?.contains("servers") ?? false, "Help text should mention command")
        XCTAssertTrue(help?.contains("Servers") ?? false, "Help text should mention view title")
    }

    func testHelpTextInvalid() {
        let help = registry.helpText(for: "invalidcommand")
        XCTAssertNil(help, "Should return nil for invalid command")
    }

    func testAllHelpText() {
        let help = registry.allHelpText()
        XCTAssertFalse(help.isEmpty, "Should return comprehensive help text")
        XCTAssertTrue(help.contains("Available Commands"), "Should have header")
        XCTAssertTrue(help.contains("servers"), "Should include server commands")
        XCTAssertTrue(help.contains("Tab"), "Should mention tab completion")
    }

    // MARK: - Commands by Category Tests

    func testCommandsByCategory() {
        let categories = registry.commandsByCategory()
        XCTAssertFalse(categories.isEmpty, "Should return categorized commands")

        // Check specific categories exist
        XCTAssertNotNil(categories[.compute], "Should have compute category")
        XCTAssertNotNil(categories[.networking], "Should have networking category")
        XCTAssertNotNil(categories[.storage], "Should have storage category")
        XCTAssertNotNil(categories[.services], "Should have services category")
        XCTAssertNotNil(categories[.utilities], "Should have utilities category")

        // Verify compute category contains expected commands
        if let compute = categories[.compute] {
            XCTAssertTrue(compute.contains("servers"), "Compute should include servers")
            XCTAssertTrue(compute.contains("flavors"), "Compute should include flavors")
        }
    }

    // MARK: - Performance Tests

    func testResolvePerformance() {
        measure {
            for _ in 0..<1000 {
                _ = registry.resolve("servers")
            }
        }
    }

    func testFuzzyMatchPerformance() {
        measure {
            for _ in 0..<100 {
                _ = registry.fuzzyMatch("servrs")
            }
        }
    }

    func testRankedMatchesPerformance() {
        measure {
            for _ in 0..<100 {
                _ = registry.rankedMatches(for: "ser", limit: 5)
            }
        }
    }

    // MARK: - Edge Cases

    func testSpecialCharacters() {
        XCTAssertNil(registry.resolve("@#$%"), "Special characters should return nil")
        XCTAssertNil(registry.resolve("test-command"), "Hyphenated command should return nil (unless defined)")
    }

    func testVeryLongString() {
        let longString = String(repeating: "a", count: 1000)
        XCTAssertNil(registry.resolve(longString), "Very long string should return nil")
    }

    func testWhitespace() {
        XCTAssertNil(registry.resolve("   "), "Whitespace should return nil")
    }

    // MARK: - Consistency Tests

    func testAllAliasesResolve() {
        let commands = registry.allCommands()

        for command in commands {
            // Check if it resolves as a navigation command, action command, config command, or discovery command
            let isNavigation = registry.resolve(command) != nil
            let isAction = registry.isActionCommand(command)
            let isConfig = registry.isConfigCommand(command)
            let isDiscovery = registry.isDiscoveryCommand(command)

            let resolves = isNavigation || isAction || isConfig || isDiscovery
            XCTAssertTrue(resolves, "All listed commands should resolve: '\(command)'")
        }
    }

    func testNoAliasConflicts() {
        // Verify navigation commands resolve to exactly one ViewMode
        let navigationCommands = registry.navigationCommands()
        var resolvedViews: [String: ViewMode] = [:]

        for command in navigationCommands {
            if let view = registry.resolve(command) {
                resolvedViews[command] = view
            }
        }

        // All navigation commands should have resolved
        XCTAssertEqual(resolvedViews.count, navigationCommands.count,
                      "All navigation commands should resolve to a view")
    }
}
