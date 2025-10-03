import Foundation
import OSClient
import SwiftTUI

// Utility function to wrap text for display
func wrapText(_ text: String, maxWidth: Int) -> [String] {
    guard maxWidth > 0 else { return [text] }

    var lines: [String] = []
    var currentLine = ""

    for char in text {
        if char == "\n" {
            lines.append(currentLine)
            currentLine = ""
        } else if currentLine.count >= maxWidth {
            lines.append(currentLine)
            currentLine = String(char)
        } else {
            currentLine.append(char)
        }
    }

    if !currentLine.isEmpty {
        lines.append(currentLine)
    }

    return lines.isEmpty ? [""] : lines
}

struct MiscViews {
    @MainActor
    static func drawHelp(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                        width: Int32, height: Int32, scrollOffset: Int = 0,
                        currentView: ViewMode = .help) async {

        // Clear the area behind the window to prevent artifacts
        await BaseViewComponents.clearArea(screen: screen, startRow: startRow - 1, startCol: startCol,
                                     width: width, height: height)

        // Enhanced title with border - make it context-aware
        let helpTitle = getContextualHelpTitle(for: currentView)
        await BaseViewComponents.drawEnhancedTitle(screen: screen, startRow: startRow, startCol: startCol,
                                            width: width, title: helpTitle)

        let initialRow = startRow + 2

        // Get contextual help content based on current view
        let helpText = getContextualHelpContent(for: currentView)

        // Calculate total lines and visible area
        // Account for header (2 lines) and footer (2 lines)
        let availableHeight = Int(height - 4)

        // For two-column layout, we can show approximately twice as many items
        // in the same vertical space as a single column layout
        let maxRowsPerColumn = availableHeight
        let maxVisibleLines = maxRowsPerColumn * 2  // Two columns worth of content

        var allLines: [(String, Bool)] = [] // (text, isHeader)

        // Build all lines with section markers
        for (section, items) in helpText {
            allLines.append((section, true)) // Section header
            for item in items {
                allLines.append((item, false)) // Item
            }
            allLines.append(("", false)) // Spacing
        }

        // Remove last empty line
        if !allLines.isEmpty && allLines.last?.0 == "" {
            allLines.removeLast()
        }

        // Apply scroll offset with bounds checking
        let maxPossibleScroll = max(allLines.count - maxVisibleLines, 0)
        let actualScrollOffset = min(scrollOffset, maxPossibleScroll)
        let startIndex = actualScrollOffset
        let endIndex = min(startIndex + maxVisibleLines, allLines.count)

        // Single column layout - use full available width
        let contentWidth = Int(width - 4) // Leave margin on both sides
        let colStart = startCol + 2

        // Render single column using SwiftTUI
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        for i in startIndex..<endIndex {
            let (text, isHeader) = allLines[i]

            if text.isEmpty {
                components.append(Text(""))
                continue
            }

            let truncatedText = String(text.prefix(contentWidth - (isHeader ? 2 : 4)))
            if isHeader {
                components.append(Text(truncatedText).primary().bold())
            } else {
                components.append(Text("  \(truncatedText)").secondary())
            }
        }

        let singleColumn = VStack(spacing: 0, children: components)
        let columnBounds = Rect(x: colStart, y: initialRow, width: Int32(contentWidth), height: Int32(components.count))
        await SwiftTUI.render(singleColumn, on: surface, in: columnBounds)

        // Enhanced scroll indicator using SwiftTUI
        if allLines.count > maxVisibleLines {
            let scrollInfo = "(\(startIndex + 1)-\(endIndex) of \(allLines.count)) Use UP/DOWN to scroll"
            let scrollBounds = Rect(x: startCol + 2, y: startRow + height - 3, width: width - 4, height: 1)
            await SwiftTUI.render(Text(scrollInfo).info(), on: surface, in: scrollBounds)
        }

        await BaseViewComponents.drawContextHelp(screen: screen, startRow: startRow + height - 2, startCol: startCol,
                                          helpText: "Press ESC to return to previous view")
    }

    // MARK: - Contextual Help System

    private static func getContextualHelpTitle(for view: ViewMode) -> String {
        switch view {
        case .servers:
            return "Help - Server Management"
        case .networks:
            return "Help - Network Management"
        case .volumes:
            return "Help - Volume Management"
        case .images:
            return "Help - Image Management"
        case .flavors:
            return "Help - Flavor Management"
        case .keyPairs:
            return "Help - SSH Key Pair Management"
        case .subnets:
            return "Help - Subnet Management"
        case .ports:
            return "Help - Port Management"
        case .routers:
            return "Help - Router Management"
        case .floatingIPs:
            return "Help - Floating IP Management"
        case .securityGroups:
            return "Help - Security Group Management"
        case .serverGroups:
            return "Help - Server Group Management"
        case .topology:
            return "Help - Topology View"
        case .healthDashboard:
            return "Help - Health Dashboard"
        case .dashboard:
            return "Help - Main Dashboard"
        case .serverCreate, .networkCreate, .volumeCreate, .keyPairCreate, .subnetCreate, .portCreate, .routerCreate, .floatingIPCreate, .serverGroupCreate, .securityGroupCreate:
            return "Help - Resource Creation"
        case .serverDetail, .networkDetail, .volumeDetail, .imageDetail, .flavorDetail, .keyPairDetail, .subnetDetail, .portDetail, .routerDetail, .floatingIPDetail, .securityGroupDetail, .serverGroupDetail, .healthDashboardServiceDetail:
            return "Help - Resource Details"
        case .serverSecurityGroups:
            return "Help - Security Group Management"
        case .serverNetworkInterfaces:
            return "Help - Network Interface Management"
        case .volumeManagement:
            return "Help - Volume Management"
        case .serverGroupManagement:
            return "Help - Server Group Management"
        case .serverSnapshotManagement:
            return "Help - Snapshot Creation"
        case .volumeSnapshotManagement:
            return "Help - Snapshot Management"
        case .serverResize:
            return "Help - Server Resize"
        case .floatingIPServerSelect:
            return "Help - Server Selection"
        case .securityGroupRuleManagement:
            return "Help - Security Rule Management"
        case .advancedSearch:
            return "Help - Advanced Search"
        default:
            return "Help - Keyboard Shortcuts"
        }
    }

    private static func getContextualHelpContent(for view: ViewMode) -> [(String, [String])] {
        let generalNavigation = ("Navigation", [
            "UP/DOWN: Navigate up/down in lists",
            "PAGE UP/DOWN: Fast scroll in long lists",
            "LEFT/RIGHT: Navigate in forms and select options",
            "SPACE: View details or edit field",
            "ENTER: Create/edit/confirm action",
            "ESC: Return to previous view or cancel",
            "TAB: Navigate fields in forms",
        ])

        let generalActions = ("General Actions", [
            "/: Search/filter current list",
            "a: Toggle auto-refresh (ON/OFF)",
            "c: Manual refresh",
            "q/Q: Quit application",
            "?: Show help for current view",
            "@: Show about page",
        ])

        switch view {
        case .servers:
            return [
                generalNavigation,
                ("Server Management", [
                    "C: Create new server",
                    "S: Start server",
                    "R: Restart server",
                    "T: Stop server",
                    "P: Create snapshot",
                    "G: Manage security groups",
                    "I: Manage network interfaces",
                    "L: View server logs",
                    "Z: Resize server",
                    "DELETE: Delete selected server",
                    "Server States: ACTIVE, SHUTOFF, ERROR, BUILD",
                ]),
                generalActions
            ]

        case .volumes:
            return [
                generalNavigation,
                ("Volume Management", [
                    "C: Create new volume",
                    "A: Attach volume to server",
                    "D: Detach volume from server",
                    "P: Create volume snapshot",
                    "DELETE: Delete selected volume",
                    "Volume States: Available, In-use, Creating, Deleting",
                ]),
                generalActions
            ]

        case .networks:
            return [
                generalNavigation,
                ("Network Management", [
                    "C: Create new network",
                    "DELETE: Delete selected network",
                    "Network States: ACTIVE, DOWN, BUILD, ERROR",
                ]),
                generalActions
            ]

        case .securityGroups:
            return [
                generalNavigation,
                ("Security Group Management", [
                    "C: Create new security group",
                    "M: Manage security group rules",
                    "DELETE: Delete selected security group",
                    "Rules control network access to resources",
                ]),
                generalActions
            ]

        case .serverCreate, .networkCreate, .volumeCreate, .keyPairCreate, .subnetCreate, .portCreate, .routerCreate, .floatingIPCreate, .serverGroupCreate, .securityGroupCreate:
            return [
                ("Form Navigation", [
                    "TAB: Move to next field",
                    "SHIFT+TAB: Move to previous field",
                    "LEFT/RIGHT: Change dropdown selection",
                    "SPACE: Edit text fields",
                    "ENTER: Create resource",
                    "ESC: Cancel and return",
                    "Type: Enter text for name fields",
                ]),
                ("Field Types", [
                    "Text fields: Type directly",
                    "Dropdowns: Use LEFT/RIGHT arrows",
                    "Active field: Highlighted in red",
                    "Required fields: Must be completed",
                ]),
                generalActions
            ]

        case .healthDashboard:
            return [
                generalNavigation,
                ("Health Dashboard", [
                    "SPACE: View service details",
                    "Displays unified health monitoring view",
                    "Auto-refresh keeps status current",
                    "Service status updates in real-time",
                ]),
                generalActions
            ]

        case .topology:
            return [
                generalNavigation,
                ("Topology View", [
                    "W: Export topology as ASCII diagram",
                    "View shows resource relationships",
                    "Network connections and dependencies",
                ]),
                generalActions
            ]

        case .advancedSearch:
            return [
                generalNavigation,
                ("Advanced Search", [
                    "TAB: Navigate search fields",
                    "ENTER: Execute search",
                    "/: Quick filter results",
                    "Search across all resource types",
                    "Use filters to narrow results",
                ]),
                generalActions
            ]

        case .images:
            return [
                generalNavigation,
                ("Image Management", [
                    "DELETE: Delete selected image",
                    "Image States: ACTIVE, DEACTIVATED, ERROR, QUEUED",
                    "View details to see image properties and metadata",
                    "Images are templates for server creation",
                ]),
                generalActions
            ]

        case .flavors:
            return [
                generalNavigation,
                ("Flavor Management", [
                    "Read-only view of compute flavors",
                    "Shows CPU, RAM, and disk specifications",
                    "Use for server creation and resizing",
                    "Filter by resource requirements",
                ]),
                generalActions
            ]

        case .keyPairs:
            return [
                generalNavigation,
                ("SSH Key Pair Management", [
                    "C: Create new key pair",
                    "DELETE: Delete selected key pair",
                    "Used for secure server access",
                    "Import existing or generate new keys",
                ]),
                generalActions
            ]

        case .subnets:
            return [
                generalNavigation,
                ("Subnet Management", [
                    "C: Create new subnet",
                    "DELETE: Delete selected subnet",
                    "Subnets define IP address ranges within networks",
                    "Configure DHCP and gateway settings",
                ]),
                generalActions
            ]

        case .ports:
            return [
                generalNavigation,
                ("Port Management", [
                    "C: Create new port",
                    "DELETE: Delete selected port",
                    "Ports connect resources to networks",
                    "Manage IP assignments and security groups",
                ]),
                generalActions
            ]

        case .routers:
            return [
                generalNavigation,
                ("Router Management", [
                    "C: Create new router",
                    "DELETE: Delete selected router",
                    "Routers connect networks and provide internet access",
                    "Configure external gateways and routes",
                ]),
                generalActions
            ]

        case .floatingIPs:
            return [
                generalNavigation,
                ("Floating IP Management", [
                    "C: Create new floating IP",
                    "A: Attach to server",
                    "D: Detach from server",
                    "DELETE: Release floating IP",
                    "Provides external network access for servers",
                ]),
                generalActions
            ]

        case .serverGroups:
            return [
                generalNavigation,
                ("Server Group Management", [
                    "C: Create new server group",
                    "M: Manage group membership",
                    "DELETE: Delete selected server group",
                    "Groups define server placement policies",
                    "Anti-affinity and affinity rules",
                ]),
                generalActions
            ]

        case .serverSecurityGroups:
            return [
                generalNavigation,
                ("Server Security Group Management", [
                    "SPACE: Toggle security group assignment",
                    "ENTER: Apply changes",
                    "Manage which security groups are assigned to server",
                    "Multiple security groups can be assigned",
                ]),
                generalActions
            ]

        case .serverNetworkInterfaces:
            return [
                generalNavigation,
                ("Server Network Interface Management", [
                    "TAB: Switch between attach/detach modes",
                    "SPACE: Toggle interface selection",
                    "ENTER: Apply interface changes",
                    "Manage server network connections",
                ]),
                generalActions
            ]

        case .volumeSnapshotManagement:
            return [
                generalNavigation,
                ("Volume Snapshot Management", [
                    "TAB: Navigate snapshot fields",
                    "ENTER: Create snapshot",
                    "Snapshots preserve volume state",
                    "Used for backups and recovery",
                ]),
                generalActions
            ]

        case .serverResize:
            return [
                generalNavigation,
                ("Server Resize", [
                    "LEFT/RIGHT: Change flavor selection",
                    "ENTER: Confirm resize operation",
                    "Server will be temporarily shut down",
                    "Choose new CPU, RAM, and disk configuration",
                ]),
                generalActions
            ]

        case .volumeManagement:
            return [
                generalNavigation,
                ("Volume Attachment Management", [
                    "TAB: Switch between attach/detach operations",
                    "SPACE: Toggle volume/server selection",
                    "ENTER: Apply attachment changes",
                    "Manage volume-to-server connections",
                ]),
                generalActions
            ]

        case .serverSnapshotManagement:
            return [
                generalNavigation,
                ("Server Snapshot Creation", [
                    "ENTER: Create server snapshot",
                    "Snapshots capture server state for recovery",
                    "Server remains running during snapshot",
                ]),
                generalActions
            ]

        case .floatingIPServerSelect:
            return [
                generalNavigation,
                ("Floating IP Server Selection", [
                    "ENTER: Attach floating IP to selected server",
                    "Choose which server gets external access",
                    "Only one server per floating IP",
                ]),
                generalActions
            ]

        case .serverGroupManagement:
            return [
                generalNavigation,
                ("Server Group Management", [
                    "TAB: Switch between operations",
                    "SPACE: Toggle server selection",
                    "ENTER: Apply group membership changes",
                    "Add or remove servers from groups",
                ]),
                generalActions
            ]

        case .securityGroupRuleManagement:
            return [
                generalNavigation,
                ("Security Group Rules", [
                    "TAB: Switch between rule management modes",
                    "SPACE: Toggle rule selection",
                    "C: Create new rule",
                    "E: Edit existing rule",
                    "DELETE: Delete selected rules",
                    "ENTER: Apply rule changes",
                ]),
                generalActions
            ]

        default:
            // General help for all other views
            return [
                generalNavigation,
                ("View Navigation", [
                    "d: Dashboard view",
                    "h: Health Dashboard view",
                    "k: SSH Key Pairs view",
                    "s: Servers view",
                    "g: Server Groups view",
                    "r: Routers view",
                    "n: Networks view",
                    "u: Subnets view",
                    "e: Security Groups view",
                    "l: Floating IPs view",
                    "p: Ports view",
                    "v: Volumes view",
                    "i: Images view",
                    "f: Flavors view",
                    "t: Topology view",
                    "z: Advanced Search view",
                ]),
                ("Features", [
                    "Auto-refresh: Data updates every 30 seconds",
                    "Smart caching: Reduces API calls",
                    "UUID resolution: Shows friendly names",
                    "Color coding: Visual status indicators",
                    "Search and filtering: Quick resource location",
                    "Keyboard-driven: Full functionality without mouse",
                ]),
                generalActions
            ]
        }
    }

    // MARK: - About Page

    @MainActor
    static func drawAbout(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                         width: Int32, height: Int32, scrollOffset: Int = 0) async {

        // Clear the area behind the window to prevent artifacts
        await BaseViewComponents.clearArea(screen: screen, startRow: startRow - 1, startCol: startCol,
                                     width: width, height: height)

        // Enhanced title with border
        await BaseViewComponents.drawEnhancedTitle(screen: screen, startRow: startRow, startCol: startCol,
                                            width: width, title: "About Substation")

        let initialRow = startRow + 2
        let surface = SwiftTUI.surface(from: screen)

        // Build about information
        let aboutInfo = getAboutInformation()

        var components: [any Component] = []

        for (section, items) in aboutInfo {
            // Section header
            components.append(Text(section).primary().bold())

            // Section items
            for item in items {
                components.append(Text("  \(item)").secondary())
            }

            // Add spacing between sections
            components.append(Text(""))
        }

        // Remove last empty line if it exists
        if !components.isEmpty {
            // For simplicity, just keep all components as they contain the section data
            // The empty Text components provide necessary spacing between sections
        }

        // Calculate available height for content
        let availableHeight = Int(height - 4)
        let maxVisibleLines = availableHeight

        // Apply scroll offset with bounds checking
        let maxPossibleScroll = max(components.count - maxVisibleLines, 0)
        let actualScrollOffset = min(scrollOffset, maxPossibleScroll)
        let startIndex = actualScrollOffset
        let endIndex = min(startIndex + maxVisibleLines, components.count)

        // Get visible components
        let visibleComponents = Array(components[startIndex..<endIndex])

        // Render the content
        if !visibleComponents.isEmpty {
            let aboutComponent = VStack(spacing: 0, children: visibleComponents)
                .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))

            let contentBounds = Rect(x: startCol, y: initialRow, width: width - 4, height: Int32(min(maxVisibleLines, visibleComponents.count)))
            await SwiftTUI.render(aboutComponent, on: surface, in: contentBounds)
        }

        // Enhanced scroll indicator
        if components.count > maxVisibleLines {
            let scrollInfo = "(\(startIndex + 1)-\(endIndex) of \(components.count)) Use UP/DOWN to scroll"
            let scrollBounds = Rect(x: startCol + 2, y: startRow + height - 3, width: width - 4, height: 1)
            await SwiftTUI.render(Text(scrollInfo).info(), on: surface, in: scrollBounds)
        }

        await BaseViewComponents.drawContextHelp(screen: screen, startRow: startRow + height - 2, startCol: startCol,
                                          helpText: "Press ESC to return to previous view")
    }

    private static func getAboutInformation() -> [(String, [String])] {
        let buildInfo = getBuildInformation()

        let platform: String
        #if os(Linux)
        platform = "Linux"
        #elseif os(macOS)
        platform = "macOS"
        #else
        platform = "Unknown"
        #endif

        return [
            ("Application", [
                "Name: Substation",
                "Description: OpenStack Terminal User Interface Client",
                "Platform: \(platform)",
                "Swift Version: 6.1",
            ]),
            ("Version Information", [
                "Version: \(buildInfo.version)",
                "Build Date: \(buildInfo.buildDate)",
                "Git Commit: \(buildInfo.gitCommit)",
                "Build Configuration: \(buildInfo.configuration)",
            ]),
            ("Features", [
                "OpenStack cloud management via terminal interface",
                "Complete resource lifecycle management",
                "Advanced search and filtering capabilities",
                "Real-time health monitoring and alerts",
                "Intelligent caching and performance optimization",
                "Comprehensive keyboard navigation",
                "Support for multiple authentication methods",
                "Export capabilities for topology and configurations",
            ]),
            ("Supported OpenStack Services", [
                "Nova: Compute service (servers, flavors, server groups)",
                "Neutron: Network service (networks, subnets, ports, routers, security groups, floating IPs)",
                "Cinder: Block storage service (volumes, volume snapshots, volume types)",
                "Glance: Image service (images and image management)",
                "Keystone: Identity service (authentication, key pair management)",
                "Barbican: Key management service (secrets, containers)",
                "Octavia: Load balancing service (load balancers, listeners, pools)",
                "Swift: Object storage service (containers, objects)",
            ]),
            ("Authors & Contributors", [
                "Kevin Carter @Cloudnull",
            ]),
            ("License", [
                "Open Source Software",
                "Licensed under terms specified in project repository",
                "Built with Swift and SwiftTUI framework",
                "Uses NCurses for terminal interface",
            ]),
            ("Support & Documentation", [
                "Built-in contextual help system (Press ? in any view)",
                "Comprehensive keyboard shortcuts",
                "Dynamic help based on current context",
                "Configuration examples and templates",
            ])
        ]
    }

    private static func getBuildInformation() -> (version: String, buildDate: String, gitCommit: String, configuration: String) {
        // Get dynamic version from git tag or commit
        let version = getGitVersion()

        // Get dynamic build date - current compilation time
        let buildDate = ISO8601DateFormatter().string(from: Date())

        // Get configuration
        #if DEBUG
        let configuration = "Debug"
        #else
        let configuration = "Release"
        #endif

        // Get git commit hash dynamically
        let gitCommit = getGitCommitHash()

        return (version: version, buildDate: buildDate, gitCommit: gitCommit, configuration: configuration)
    }

    private static func getGitVersion() -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", "git describe --tags --always 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo '0.0.1'"]
        task.executableURL = URL(fileURLWithPath: "/bin/sh")

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "unknown" : trimmed
            }
        } catch {
            // If git command fails, return fallback
        }

        return "unknown"
    }

    private static func getGitCommitHash() -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", "git rev-parse --short HEAD 2>/dev/null || echo 'Unknown'"]
        task.executableURL = URL(fileURLWithPath: "/bin/sh")

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "Unknown" : trimmed
            }
        } catch {
            // If git command fails, return a fallback
        }

        return "Unknown"
    }

    // MARK: - Simple Message Display
    @MainActor
    static func drawSimpleCenteredMessage(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        message: String
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let messageY = startRow + height / 2
        let messageX = startCol + (width - Int32(message.count)) / 2
        let bounds = Rect(x: messageX, y: messageY, width: Int32(message.count), height: 1)
        await SwiftTUI.render(Text(message).info(), on: surface, in: bounds)
    }

    // NOTE: Old drawServerCreate function removed - ServerCreateForm now uses FormBuilder
    // See ServerCreateView.drawServerCreateForm for the current implementation
}
