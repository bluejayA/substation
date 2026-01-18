import XCTest
@testable import Substation

/// Tests for shell completion script generation
final class ShellCompletionTests: XCTestCase {

    // MARK: - Bash Completion Tests

    func testBashCompletionScriptIsNotEmpty() {
        let script = Substation.bashCompletionScript()
        XCTAssertFalse(script.isEmpty, "Bash completion script should not be empty")
    }

    func testBashCompletionScriptContainsCompletionFunction() {
        let script = Substation.bashCompletionScript()
        XCTAssertTrue(
            script.contains("_substation_completions()"),
            "Bash script should define _substation_completions function"
        )
    }

    func testBashCompletionScriptContainsCloudDiscoveryFunction() {
        let script = Substation.bashCompletionScript()
        XCTAssertTrue(
            script.contains("_substation_get_clouds()"),
            "Bash script should define _substation_get_clouds function"
        )
    }

    func testBashCompletionScriptContainsCompleteDirective() {
        let script = Substation.bashCompletionScript()
        XCTAssertTrue(
            script.contains("complete -F _substation_completions substation"),
            "Bash script should register completion function"
        )
    }

    func testBashCompletionScriptContainsAllOptions() {
        let script = Substation.bashCompletionScript()
        let expectedOptions = ["--cloud", "-c", "--config", "--list-clouds", "--wiretap", "--help", "-h", "completion"]

        for option in expectedOptions {
            XCTAssertTrue(
                script.contains(option),
                "Bash script should include option: \(option)"
            )
        }
    }

    func testBashCompletionScriptHandlesCompletionSubcommand() {
        let script = Substation.bashCompletionScript()
        XCTAssertTrue(
            script.contains("bash zsh fish"),
            "Bash script should complete shell types for completion subcommand"
        )
    }

    func testBashCompletionScriptUsesConfigEnvVar() {
        let script = Substation.bashCompletionScript()
        XCTAssertTrue(
            script.contains("OS_CLIENT_CONFIG_FILE"),
            "Bash script should check OS_CLIENT_CONFIG_FILE environment variable"
        )
    }

    func testBashCompletionScriptUsesDefaultConfigPath() {
        let script = Substation.bashCompletionScript()
        XCTAssertTrue(
            script.contains(".config/openstack/clouds.yaml"),
            "Bash script should use default clouds.yaml path"
        )
    }

    // MARK: - Zsh Completion Tests

    func testZshCompletionScriptIsNotEmpty() {
        let script = Substation.zshCompletionScript()
        XCTAssertFalse(script.isEmpty, "Zsh completion script should not be empty")
    }

    func testZshCompletionScriptContainsCompdefDirective() {
        let script = Substation.zshCompletionScript()
        XCTAssertTrue(
            script.contains("#compdef substation"),
            "Zsh script should start with #compdef directive"
        )
    }

    func testZshCompletionScriptContainsCompletionFunction() {
        let script = Substation.zshCompletionScript()
        XCTAssertTrue(
            script.contains("_substation()"),
            "Zsh script should define _substation function"
        )
    }

    func testZshCompletionScriptContainsCloudDiscoveryFunction() {
        let script = Substation.zshCompletionScript()
        XCTAssertTrue(
            script.contains("_substation_get_clouds()"),
            "Zsh script should define _substation_get_clouds function"
        )
    }

    func testZshCompletionScriptContainsOptionDescriptions() {
        let script = Substation.zshCompletionScript()
        let expectedDescriptions = [
            "Specify cloud name from clouds.yaml",
            "Path to clouds.yaml file",
            "List available clouds in configuration",
            "Enable debug mode",
            "Show help message"
        ]

        for desc in expectedDescriptions {
            XCTAssertTrue(
                script.contains(desc),
                "Zsh script should include option description: \(desc)"
            )
        }
    }

    func testZshCompletionScriptContainsShellDescriptions() {
        let script = Substation.zshCompletionScript()
        let expectedShells = [
            "bash:Bash completion",
            "zsh:Zsh completion",
            "fish:Fish completion"
        ]

        for shell in expectedShells {
            XCTAssertTrue(
                script.contains(shell),
                "Zsh script should include shell type: \(shell)"
            )
        }
    }

    func testZshCompletionScriptUsesDescribeFunction() {
        let script = Substation.zshCompletionScript()
        XCTAssertTrue(
            script.contains("_describe"),
            "Zsh script should use _describe for completions"
        )
    }

    func testZshCompletionScriptUsesArgumentsFunction() {
        let script = Substation.zshCompletionScript()
        XCTAssertTrue(
            script.contains("_arguments"),
            "Zsh script should use _arguments for option parsing"
        )
    }

    // MARK: - Fish Completion Tests

    func testFishCompletionScriptIsNotEmpty() {
        let script = Substation.fishCompletionScript()
        XCTAssertFalse(script.isEmpty, "Fish completion script should not be empty")
    }

    func testFishCompletionScriptContainsCloudDiscoveryFunction() {
        let script = Substation.fishCompletionScript()
        XCTAssertTrue(
            script.contains("function __substation_get_clouds"),
            "Fish script should define __substation_get_clouds function"
        )
    }

    func testFishCompletionScriptContainsCompletionSubcommandCheck() {
        let script = Substation.fishCompletionScript()
        XCTAssertTrue(
            script.contains("function __substation_using_completion"),
            "Fish script should define __substation_using_completion function"
        )
    }

    func testFishCompletionScriptContainsNeedsCommandCheck() {
        let script = Substation.fishCompletionScript()
        XCTAssertTrue(
            script.contains("function __substation_needs_command"),
            "Fish script should define __substation_needs_command function"
        )
    }

    func testFishCompletionScriptUsesCompleteCommand() {
        let script = Substation.fishCompletionScript()
        XCTAssertTrue(
            script.contains("complete -c substation"),
            "Fish script should use complete command for substation"
        )
    }

    func testFishCompletionScriptContainsAllOptions() {
        let script = Substation.fishCompletionScript()
        let expectedPatterns = [
            "-s c -l cloud",
            "-l config",
            "-l list-clouds",
            "-l wiretap",
            "-s h -l help"
        ]

        for pattern in expectedPatterns {
            XCTAssertTrue(
                script.contains(pattern),
                "Fish script should include option pattern: \(pattern)"
            )
        }
    }

    func testFishCompletionScriptContainsShellTypes() {
        let script = Substation.fishCompletionScript()
        let expectedShells = ["bash", "zsh", "fish"]

        for shell in expectedShells {
            XCTAssertTrue(
                script.contains("-a '\(shell)'"),
                "Fish script should complete shell type: \(shell)"
            )
        }
    }

    func testFishCompletionScriptDisablesFileCompletions() {
        let script = Substation.fishCompletionScript()
        XCTAssertTrue(
            script.contains("complete -c substation -f"),
            "Fish script should disable file completions by default"
        )
    }

    func testFishCompletionScriptUsesConfigEnvVar() {
        let script = Substation.fishCompletionScript()
        XCTAssertTrue(
            script.contains("OS_CLIENT_CONFIG_FILE"),
            "Fish script should check OS_CLIENT_CONFIG_FILE environment variable"
        )
    }

    // MARK: - Cross-Shell Consistency Tests

    func testAllScriptsContainInstallationInstructions() {
        let scripts = [
            ("bash", Substation.bashCompletionScript()),
            ("zsh", Substation.zshCompletionScript()),
            ("fish", Substation.fishCompletionScript())
        ]

        for (name, script) in scripts {
            XCTAssertTrue(
                script.contains("Installation:") || script.contains("# Installation"),
                "\(name) script should contain installation instructions"
            )
        }
    }

    func testAllScriptsContainGeneratedByComment() {
        let scripts = [
            ("bash", Substation.bashCompletionScript()),
            ("zsh", Substation.zshCompletionScript()),
            ("fish", Substation.fishCompletionScript())
        ]

        for (name, script) in scripts {
            XCTAssertTrue(
                script.contains("Generated by: substation completion"),
                "\(name) script should contain generated-by comment"
            )
        }
    }

    func testAllScriptsUseCloudYamlPath() {
        let scripts = [
            ("bash", Substation.bashCompletionScript()),
            ("zsh", Substation.zshCompletionScript()),
            ("fish", Substation.fishCompletionScript())
        ]

        for (name, script) in scripts {
            XCTAssertTrue(
                script.contains("clouds.yaml"),
                "\(name) script should reference clouds.yaml"
            )
        }
    }

    func testAllScriptsParseCloudNamesWithGrep() {
        let scripts = [
            ("bash", Substation.bashCompletionScript()),
            ("zsh", Substation.zshCompletionScript()),
            ("fish", Substation.fishCompletionScript())
        ]

        for (name, script) in scripts {
            XCTAssertTrue(
                script.contains("grep"),
                "\(name) script should use grep to parse cloud names"
            )
        }
    }

    // MARK: - Script Content Validation Tests

    func testBashScriptIsValidShellSyntax() {
        let script = Substation.bashCompletionScript()

        // Check for balanced braces (shell scripts should have matching { })
        let openBraces = script.filter { $0 == "{" }.count
        let closeBraces = script.filter { $0 == "}" }.count
        XCTAssertEqual(openBraces, closeBraces, "Bash script should have balanced braces")

        // Check for required bash completion patterns
        XCTAssertTrue(script.contains("COMPREPLY="), "Bash script should set COMPREPLY")
        XCTAssertTrue(script.contains("compgen"), "Bash script should use compgen")
    }

    func testZshScriptIsValidShellSyntax() {
        let script = Substation.zshCompletionScript()

        // Check for balanced braces
        let openBraces = script.filter { $0 == "{" }.count
        let closeBraces = script.filter { $0 == "}" }.count
        XCTAssertEqual(openBraces, closeBraces, "Zsh script should have balanced braces")

        // Check for required zsh completion patterns
        XCTAssertTrue(script.contains("local -a"), "Zsh script should declare local arrays")
        XCTAssertTrue(script.contains("$@"), "Zsh script should pass arguments")
    }

    func testFishScriptIsValidShellSyntax() {
        let script = Substation.fishCompletionScript()

        // Check that functions are defined
        let functionCount = script.components(separatedBy: "function __substation").count - 1
        XCTAssertEqual(functionCount, 3, "Fish script should define 3 helper functions")

        // Check that script ends with completion commands (not inside a function)
        XCTAssertTrue(
            script.contains("complete -c substation"),
            "Fish script should have completion commands"
        )

        // Verify the script has proper structure (functions defined before completions)
        if let firstFunction = script.range(of: "function __substation"),
           let lastComplete = script.range(of: "complete -c substation", options: .backwards) {
            XCTAssertTrue(
                firstFunction.lowerBound < lastComplete.lowerBound,
                "Fish functions should be defined before completion commands"
            )
        }
    }

    // MARK: - Script Length Tests

    func testBashScriptHasReasonableLength() {
        let script = Substation.bashCompletionScript()
        let lines = script.components(separatedBy: "\n")

        XCTAssertGreaterThan(lines.count, 20, "Bash script should have more than 20 lines")
        XCTAssertLessThan(lines.count, 200, "Bash script should have less than 200 lines")
    }

    func testZshScriptHasReasonableLength() {
        let script = Substation.zshCompletionScript()
        let lines = script.components(separatedBy: "\n")

        XCTAssertGreaterThan(lines.count, 20, "Zsh script should have more than 20 lines")
        XCTAssertLessThan(lines.count, 200, "Zsh script should have less than 200 lines")
    }

    func testFishScriptHasReasonableLength() {
        let script = Substation.fishCompletionScript()
        let lines = script.components(separatedBy: "\n")

        XCTAssertGreaterThan(lines.count, 20, "Fish script should have more than 20 lines")
        XCTAssertLessThan(lines.count, 200, "Fish script should have less than 200 lines")
    }
}
