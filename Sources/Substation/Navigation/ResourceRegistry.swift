import Foundation

@MainActor
final class ResourceRegistry: @unchecked Sendable {
    static let shared = ResourceRegistry()

    private init() {}

    // MARK: - Resource Command Mapping

    private let resourceMap: [ViewMode: [String]] = [
        // Dashboard
        .dashboard: ["dashboard", "dash", "d"],

        // Compute - Servers
        .flavors: ["flavors", "flavor", "flv", "f", "novaflavors", "novaflavor"],
        .keyPairs: ["keypairs", "keypair", "keys", "key", "kp", "k", "novakeypairs", "novakeypair"],
        .serverGroups: ["servergroups", "servergroup", "srvgrp", "sg", "g", "novaservergroups", "novaservergroup"],
        .servers: ["servers", "server", "srv", "s", "nova"],

        // Networking
        .floatingIPs: ["floatingips", "floatingip", "fips", "fip", "floating", "l", "neutronfloatingips", "neutronfloatingip"],
        .networks: ["networks", "network", "net", "n", "neutron"],
        .ports: ["ports", "port", "p", "neutronports", "neutronport"],
        .routers: ["routers", "router", "rtr", "r", "neutronrouters", "neutronrouter"],
        .securityGroups: ["securitygroups", "securitygroup", "secgroups", "secgroup", "sec", "e", "neutronsecuritygroups", "neutronsecuritygroup"],
        .subnets: ["subnets", "subnet", "sub", "u", "neutronsubnets", "neutronsubnet"],

        // Storage
        .images: ["images", "image", "img", "i", "glance"],
        .volumeArchives: ["archives", "archive", "arch", "m", "volumearchives", "volumearchive", "cinderbackups", "cinderbackup"],
        .volumes: ["volumes", "volume", "vol", "v", "cinder"],

        // Services
        .barbicanSecrets: ["secrets", "secret", "barbican", "b"],
        .octavia: ["loadbalancers", "loadbalancer", "lb", "octavia", "o"],
        .swift: ["swift", "objectstorage", "objects", "obj", "j"],

        // Utilities
        .about: ["about"],
        .advancedSearch: ["search", "find", "z"],
        .healthDashboard: ["health", "healthdashboard", "h"],
        .help: ["help", "?"],
        .topology: ["topology", "topo", "t"],
    ]

    // Reverse lookup cache for fast command resolution
    private lazy var commandLookup: [String: ViewMode] = {
        var lookup: [String: ViewMode] = [:]
        for (viewMode, aliases) in resourceMap {
            for alias in aliases {
                lookup[alias.lowercased()] = viewMode
            }
        }
        return lookup
    }()

    // MARK: - Command Resolution

    /// Resolve a command to a ViewMode
    func resolve(_ command: String) -> ViewMode? {
        return commandLookup[command.lowercased()]
    }

    /// Get all available commands
    func allCommands() -> [String] {
        return Array(commandLookup.keys).sorted()
    }

    /// Get primary commands (exclude single-letter aliases for display)
    func primaryCommands() -> [String] {
        var primary: [String] = []
        for (_, aliases) in resourceMap {
            // Use the longest alias as the primary command for each ViewMode
            if let longestAlias = aliases.max(by: { $0.count < $1.count }) {
                primary.append(longestAlias)
            }
        }
        return primary.sorted()
    }

    /// Get aliases for a view mode
    func aliases(for viewMode: ViewMode) -> [String] {
        return resourceMap[viewMode]?.sorted() ?? []
    }

    /// Fuzzy match a command (for typo correction)
    func fuzzyMatch(_ command: String, threshold: Int = 2) -> String? {
        let matches = commandLookup.keys
            .map { (key: $0, distance: levenshteinDistance(command, $0)) }
            .filter { $0.distance <= threshold && $0.distance > 0 }
            .sorted { $0.distance < $1.distance }

        return matches.first?.key
    }

    // MARK: - Fuzzy Match Scoring

    /// Calculate a match score for a command against a query (higher is better)
    /// - Parameters:
    ///   - command: The command to score
    ///   - query: The search query
    /// - Returns: A score from 0-100, where 100 is a perfect match
    func matchScore(command: String, query: String) -> Int {
        guard !query.isEmpty else { return 0 }

        let cmdLower = command.lowercased()
        let queryLower = query.lowercased()

        // Exact match
        if cmdLower == queryLower {
            return 100
        }

        // Prefix match (very high score)
        if cmdLower.hasPrefix(queryLower) {
            // Longer prefix matches score higher
            let prefixRatio = Double(queryLower.count) / Double(cmdLower.count)
            return 80 + Int(prefixRatio * 19)
        }

        // Contains match (medium score)
        if cmdLower.contains(queryLower) {
            // Earlier position scores higher
            if let range = cmdLower.range(of: queryLower) {
                let position = cmdLower.distance(from: cmdLower.startIndex, to: range.lowerBound)
                let positionPenalty = min(position * 5, 30)
                return 60 - positionPenalty
            }
            return 50
        }

        // Levenshtein distance for fuzzy matching (low score)
        let distance = levenshteinDistance(queryLower, cmdLower)
        if distance <= 2 {
            return 30 - (distance * 10)
        }

        return 0
    }

    /// Get all commands with their match scores for a query, sorted by score
    /// Optimized to reduce unnecessary scoring when limit is specified
    func rankedMatches(for query: String, limit: Int? = nil) -> [(command: String, score: Int, viewMode: ViewMode)] {
        var matches: [(command: String, score: Int, viewMode: ViewMode)] = []
        var perfectMatches = 0

        // Performance optimization: Track if we have enough high-quality matches
        let targetLimit = limit ?? Int.max
        // Prevent overflow: if no limit, don't use early exit threshold
        let earlyExitThreshold = limit != nil ? targetLimit * 2 : Int.max

        // Score all aliases for all ViewModes
        for (viewMode, aliases) in resourceMap {
            for alias in aliases {
                let score = matchScore(command: alias, query: query)
                if score > 0 {
                    matches.append((command: alias, score: score, viewMode: viewMode))

                    // Track perfect matches for early exit
                    if score == 100 {
                        perfectMatches += 1
                        // If we have enough perfect matches, we can stop
                        if perfectMatches >= targetLimit {
                            break
                        }
                    }
                }
            }

            // Early exit if we have plenty of good matches
            if matches.count >= earlyExitThreshold && perfectMatches > 0 {
                break
            }
        }

        // Sort by score, then by command length, then alphabetically
        matches.sort { match1, match2 in
            if match1.score != match2.score {
                return match1.score > match2.score
            }
            // Tie-breaker: shorter commands first, then alphabetical
            if match1.command.count != match2.command.count {
                return match1.command.count < match2.command.count
            }
            return match1.command < match2.command
        }

        if let limit = limit {
            return Array(matches.prefix(limit))
        }
        return matches
    }

    // MARK: - Levenshtein Distance (for fuzzy matching)

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var last = Array(0...s2.count)

        for (i, char1) in s1.enumerated() {
            var current = [i + 1]
            for (j, char2) in s2.enumerated() {
                let cost = char1 == char2 ? 0 : 1
                current.append(min(last[j + 1] + 1, current[j] + 1, last[j] + cost))
            }
            last = current
        }

        return last.last ?? 0
    }

    // MARK: - Command Suggestions

    /// Get command suggestions based on partial input
    func suggestions(for partial: String, limit: Int = 5) -> [String] {
        guard !partial.isEmpty else { return [] }

        let partialLower = partial.lowercased()

        // Exact prefix matches first
        let prefixMatches = commandLookup.keys
            .filter { $0.hasPrefix(partialLower) }
            .sorted()

        // Contains matches second
        let containsMatches = commandLookup.keys
            .filter { !$0.hasPrefix(partialLower) && $0.contains(partialLower) }
            .sorted()

        return Array((prefixMatches + containsMatches).prefix(limit))
    }

    // MARK: - Command Categories

    enum CommandCategory: String, CaseIterable {
        case compute = "Compute"
        case networking = "Networking"
        case storage = "Storage"
        case services = "Services"
        case utilities = "Utilities"
    }

    /// Get commands grouped by category
    func commandsByCategory() -> [CommandCategory: [String]] {
        return [
            .compute: ["servers", "servergroups", "flavors", "keypairs"],
            .networking: ["networks", "subnets", "routers", "ports", "floatingips", "securitygroups"],
            .storage: ["volumes", "images", "archives"],
            .services: ["secrets", "loadbalancers", "swift"],
            .utilities: ["dashboard", "topology", "search", "health", "help", "about"]
        ]
    }

    // MARK: - Help Text Generation

    /// Generate help text for a command
    func helpText(for command: String) -> String? {
        guard let viewMode = resolve(command) else { return nil }

        let aliasesText = aliases(for: viewMode)
            .filter { $0 != command }
            .prefix(3)
            .joined(separator: ", ")

        var help = ":\(command) - Navigate to \(viewMode.title)"
        if !aliasesText.isEmpty {
            help += " (aliases: \(aliasesText))"
        }

        return help
    }

    /// Generate complete help text for all commands
    func allHelpText() -> String {
        var lines: [String] = ["Available Commands:", ""]

        for category in CommandCategory.allCases {
            if let commands = commandsByCategory()[category] {
                lines.append("[\(category.rawValue)]")
                for cmd in commands {
                    if let help = helpText(for: cmd) {
                        lines.append("  \(help)")
                    }
                }
                lines.append("")
            }
        }

        lines.append("Tip: Use Tab for auto-completion")
        return lines.joined(separator: "\n")
    }
}
