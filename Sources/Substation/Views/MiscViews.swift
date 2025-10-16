import Foundation
import OSClient
import SwiftTUI

struct MiscViews {
    @MainActor
    static func drawHelp(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                        width: Int32, height: Int32, scrollOffset: Int = 0,
                        currentView: ViewMode = .help) async {

        // Get contextual help title and content
        let helpTitle = getContextualHelpTitle(for: currentView)
        let helpContent = getContextualHelpContent(for: currentView)

        // Build sections for DetailView
        var sections: [DetailSection] = []

        for (sectionTitle, items) in helpContent {
            var detailItems: [DetailItem] = []
            for item in items {
                detailItems.append(.field(label: "", value: item, style: .secondary))
            }
            sections.append(DetailSection(title: sectionTitle, items: detailItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: helpTitle,
            sections: sections,
            helpText: "Press ESC to return to previous view",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
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
        case .volumeArchives:
            return "Help - Volume Archive Management"
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
        case .healthDashboard:
            return "Help - Health Dashboard"
        case .dashboard:
            return "Help - Main Dashboard"
        case .serverCreate, .networkCreate, .volumeCreate, .keyPairCreate, .subnetCreate, .portCreate, .routerCreate, .floatingIPCreate, .serverGroupCreate, .securityGroupCreate:
            return "Help - Resource Creation"
        case .serverDetail, .networkDetail, .volumeDetail, .volumeArchiveDetail, .imageDetail, .flavorDetail, .keyPairDetail, .subnetDetail, .portDetail, .routerDetail, .floatingIPDetail, .securityGroupDetail, .serverGroupDetail, .healthDashboardServiceDetail, .barbicanSecretDetail, .barbicanContainerDetail:
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
            return "Help - Search"
        case .barbican, .barbicanSecrets:
            return "Help - Secret Management"
        case .barbicanContainers:
            return "Help - Secret Container Management"
        case .barbicanSecretCreate:
            return "Help - Secret Creation"
        case .barbicanContainerCreate:
            return "Help - Container Creation"
        case .swift:
            return "Help - Object Storage Management"
        case .swiftContainerDetail:
            return "Help - Object Storage Container Contents"
        case .swiftObjectDetail:
            return "Help - Object Details"
        case .swiftContainerCreate:
            return "Help - Create Storage Container"
        case .swiftObjectUpload:
            return "Help - Upload Object"
        case .swiftContainerDownload:
            return "Help - Download Container"
        case .swiftObjectDownload:
            return "Help - Download Object"
        case .swiftDirectoryDownload:
            return "Help - Download Directory"
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

        let commandNavigation = ("Command Mode Navigation", [
            ":: Enter command mode for navigation",
            "Type partial command and press ENTER to navigate",
            "Example: ':fla' navigates to Flavors",
            "Example: ':net' navigates to Networks",
            "TAB: Cycle through command completions",
            "Sidebar shows filtered results while typing",
            "Supports fuzzy matching for quick access",
        ])

        let generalActions = ("General Actions", [
            "/: Search/filter current list",
            "a: Toggle auto-refresh (ON/OFF)",
            "c: Manual refresh",
            "CTRL-X: Toggle multi-select mode (bulk operations)",
            "q/Q: Quit application",
            "?: Show help for current view",
            "@: Show about page",
        ])

        switch view {
        case .servers:
            return [
                generalNavigation,
                ("Server Management", [
                    "SHIFT-C: Create new server",
                    "SHIFT-S: Start server",
                    "SHIFT-R: Restart server",
                    "SHIFT-T: Stop server",
                    "SHIFT-P: Create snapshot",
                    "SHIFT-L: View server logs",
                    "SHIFT-O: View server console (opens noVNC in browser)",
                    "SHIFT-Z: Resize server",
                    "DELETE: Delete selected server",
                    "Server States: ACTIVE, SHUTOFF, ERROR, BUILD",
                ]),
                ("Multi-Select Mode (CTRL-X)", [
                    "CTRL-X: Toggle multi-select mode",
                    "SPACE: Select/deselect items (in multi-select mode)",
                    "DELETE: Bulk delete selected servers",
                    "ESC: Exit multi-select mode",
                    "Status icons show [ ] or [X] when in multi-select",
                ]),
                generalActions
            ]

        case .volumes:
            return [
                generalNavigation,
                ("Volume Management", [
                    "SHIFT-C: Create new volume",
                    "SHIFT-M: Manage volume attachments",
                    "SHIFT-P: Create volume snapshot",
                    "DELETE: Delete selected volume",
                    "Volume States: Available, In-use, Creating, Deleting",
                ]),
                ("Multi-Select Mode (CTRL-X)", [
                    "CTRL-X: Toggle multi-select mode",
                    "SPACE: Select/deselect items (in multi-select mode)",
                    "DELETE: Bulk delete selected volumes",
                    "ESC: Exit multi-select mode",
                    "Status icons show [ ] or [X] when in multi-select",
                ]),
                generalActions
            ]

        case .volumeArchives:
            return [
                generalNavigation,
                ("Volume Archive Management", [
                    "SPACE: View archive details",
                    "DELETE: Delete selected archive",
                    "Archives are backups of volumes",
                    "Can be used to restore volumes",
                ]),
                ("Multi-Select Mode (CTRL-X)", [
                    "CTRL-X: Toggle multi-select mode",
                    "SPACE: Select/deselect items (in multi-select mode)",
                    "DELETE: Bulk delete selected archives",
                    "ESC: Exit multi-select mode",
                    "Status icons show [ ] or [X] when in multi-select",
                ]),
                generalActions
            ]

        case .networks:
            return [
                generalNavigation,
                ("Network Management", [
                    "SHIFT-C: Create new network",
                    "SHIFT-M: Manage network interfaces attachments",
                    "DELETE: Delete selected network",
                    "Network States: ACTIVE, DOWN, BUILD, ERROR",
                ]),
                generalActions
            ]

        case .securityGroups:
            return [
                generalNavigation,
                ("Security Group Management", [
                    "SHIFT-C: Create new security group",
                    "SHIFT-M: Manage security group rules",
                    "DELETE: Delete selected security group",
                    "Rules control network access to resources",
                ]),
                generalActions
            ]

        case .serverCreate, .networkCreate, .volumeCreate, .keyPairCreate, .subnetCreate, .portCreate, .routerCreate, .floatingIPCreate, .serverGroupCreate, .securityGroupCreate:
            return [
                ("Form Navigation", [
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

        case .advancedSearch:
            return [
                generalNavigation,
                ("Search", [
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
                    "SHIFT-C: Create new key pair",
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
                    "SHIFT-C: Create new subnet",
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
                    "SHIFT-C: Create new port",
                    "SHIFT-M: Manage server attachment",
                    "SHIFT-E: Manage allowed address pairs",
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
                    "SHIFT-C: Create new router",
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
                    "SHIFT-C: Create new floating IP",
                    "SHIFT-M: Manage server attachment",
                    "SHIFT-P: Manage port attachment",
                    "DELETE: Release floating IP",
                    "Provides external network access for servers",
                ]),
                generalActions
            ]

        case .serverGroups:
            return [
                generalNavigation,
                ("Server Group Management", [
                    "SHIFT-C: Create new server group",
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
                    "SHIFT-C: Create new rule",
                    "SHIFT-E: Edit existing rule",
                    "TAB: Switch between rule management modes",
                    "SPACE: Toggle rule selection",
                    "DELETE: Delete selected rules",
                    "ENTER: Apply rule changes",
                ]),
                generalActions
            ]

        case .barbican, .barbicanSecrets:
            return [
                generalNavigation,
                ("Secret Management", [
                    "SHIFT-C: Create new secret",
                    "SPACE: View secret details",
                    "DELETE: Delete selected secret",
                    "Secrets store sensitive data securely",
                    "Supports passphrases, certificates, and keys",
                ]),
                ("Multi-Select Mode (CTRL-X)", [
                    "CTRL-X: Toggle multi-select mode",
                    "SPACE: Select/deselect items (in multi-select mode)",
                    "DELETE: Bulk delete selected secrets",
                    "ESC: Exit multi-select mode",
                    "Status icons show [ ] or [X] when in multi-select",
                ]),
                generalActions
            ]

        case .barbicanContainers:
            return [
                generalNavigation,
                ("Secret Container Management", [
                    "SHIFT-C: Create new container",
                    "SPACE: View container details",
                    "DELETE: Delete selected container",
                    "Containers organize multiple secrets",
                    "Used for certificate bundles and key pairs",
                ]),
                ("Multi-Select Mode (CTRL-X)", [
                    "CTRL-X: Toggle multi-select mode",
                    "SPACE: Select/deselect items (in multi-select mode)",
                    "DELETE: Bulk delete selected containers",
                    "ESC: Exit multi-select mode",
                    "Status icons show [ ] or [X] when in multi-select",
                ]),
                generalActions
            ]

        case .barbicanSecretCreate:
            return [
                ("Secret Creation Form", [
                    "TAB: Move to next field",
                    "SHIFT+TAB: Move to previous field",
                    "UP/DOWN: Navigate fields",
                    "SPACE: Edit text fields",
                    "ENTER: Create secret",
                    "ESC: Cancel and return",
                ]),
                ("Secret Types", [
                    "Passphrase: Text passwords and credentials",
                    "Certificate: TLS/SSL certificates",
                    "Private Key: RSA/EC private keys",
                    "Public Key: RSA/EC public keys",
                    "Opaque: Generic binary data",
                ]),
                generalActions
            ]

        case .barbicanContainerCreate:
            return [
                ("Container Creation Form", [
                    "TAB: Move to next field",
                    "SHIFT+TAB: Move to previous field",
                    "SPACE: Edit text fields and select secrets",
                    "ENTER: Create container",
                    "ESC: Cancel and return",
                ]),
                ("Container Types", [
                    "Generic: General purpose container",
                    "Certificate: For certificate bundles",
                    "RSA: For RSA key pairs",
                ]),
                generalActions
            ]

        case .swift:
            return [
                generalNavigation,
                ("Object Storage Container Management", [
                    "SHIFT-C: Create new container",
                    "SHIFT-U: Upload objects to selected container",
                    "SHIFT-D: Download all objects from selected container",
                    "SHIFT-M: Set metadata and access policies",
                    "SHIFT-W: Enable/disable static website hosting",
                    "SPACE: Open container and view objects",
                    "DELETE: Delete selected container",
                ]),
                ("Multi-Select Mode (CTRL-X)", [
                    "CTRL-X: Toggle multi-select mode",
                    "SPACE: Select/deselect items (in multi-select mode)",
                    "DELETE: Bulk delete selected containers",
                    "ESC: Exit multi-select mode",
                    "Status icons show [ ] or [X] when in multi-select",
                ]),
                generalActions
            ]

        case .swiftContainerDetail:
            return [
                generalNavigation,
                ("Object Management", [
                    "SHIFT-U: Upload objects within the container",
                    "SHIFT-D: Download selected object or directory",
                    "SHIFT-M: Set metadata on selected object or directory",
                    "SPACE: View object details or navigate into directory",
                    "DELETE: Delete selected object",
                    "ESC: Return to container list",
                ]),
                ("Multi-Select Mode (CTRL-X)", [
                    "CTRL-X: Toggle multi-select mode",
                    "SPACE: Select/deselect items (in multi-select mode)",
                    "DELETE: Bulk delete selected objects",
                    "ESC: Exit multi-select mode",
                    "Status icons show [ ] or [X] when in multi-select",
                ]),
                generalActions
            ]

        case .swiftObjectDetail:
            return [
                generalNavigation,
                ("Object Details View", [
                    "SHIFT-M: Set metadata on this object",
                    "View object metadata and properties",
                    "See file size, content type, and ETag",
                    "Last modified timestamp shown",
                    "ESC: Return to object list",
                ]),
                generalActions
            ]

        case .swiftContainerCreate:
            return [
                ("Container Creation Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text fields",
                    "ENTER: Create container",
                    "ESC: Cancel and return",
                    "Container names must be unique",
                ]),
                ("Container Options", [
                    "Name: Required, unique identifier",
                    "Metadata: Optional key-value pairs",
                    "Read ACL: Control read access",
                    "Write ACL: Control write access",
                ]),
                generalActions
            ]

        case .swiftObjectUpload:
            return [
                ("Object Upload Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text fields or toggle checkbox",
                    "ENTER: Upload object(s) to container",
                    "ESC: Cancel and return",
                ]),
                ("Upload Modes", [
                    "Single File: Enter path to a file",
                    "Directory: Enter path to a directory",
                    "Form fields adapt based on path type",
                    "Progress shown during directory uploads",
                ]),
                ("Single File Options", [
                    "File Path: Local file to upload",
                    "Object Name: Optional name override",
                    "Content Type: MIME type (auto-detected)",
                    "Default object name uses filename",
                ]),
                ("Directory Upload Options", [
                    "Directory Path: Local directory to upload",
                    "Prefix: Optional prefix for all object names",
                    "Recursive: Upload subdirectories (checkbox)",
                    "Directory structure preserved in object names",
                    "Hidden files (starting with .) are skipped",
                    "Progress: Shows 'Uploading file X of Y'",
                ]),
                generalActions
            ]

        case .swiftContainerDownload:
            return [
                ("Container Download Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text fields or toggle checkboxes",
                    "ENTER: Download all objects from container",
                    "ESC: Cancel and return",
                ]),
                ("Download Options", [
                    "Destination Path: Directory where objects will be saved",
                    "Preserve Directory Structure: Maintains object paths with slashes",
                    "Creates subdirectories automatically if needed",
                    "Shows progress during multi-object download",
                    "Reports success/failure counts at completion",
                ]),
                generalActions
            ]

        case .swiftObjectDownload:
            return [
                ("Object Download Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text field",
                    "ENTER: Download single object",
                    "ESC: Cancel and return",
                ]),
                ("Download Options", [
                    "Destination Path: File path where object will be saved",
                    "Default destination: ./{objectName}",
                    "Validates parent directory exists and is writable",
                    "Prompts for confirmation if file exists",
                    "Downloads object data and writes to disk",
                ]),
                generalActions
            ]

        case .swiftDirectoryDownload:
            return [
                ("Directory Download Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text field or toggle checkbox",
                    "ENTER: Download all objects in directory",
                    "ESC: Cancel and return",
                ]),
                ("Download Options", [
                    "Destination Path: Directory where objects will be saved",
                    "Default destination: ./{directoryName}/",
                    "Preserve Structure: Maintains subdirectory paths (checked)",
                    "If unchecked, all files are flattened to root directory",
                    "Shows progress: 'Downloading object X of Y'",
                    "Reports success/failure counts at completion",
                ]),
                generalActions
            ]

        case .swiftContainerMetadata:
            return [
                ("Container Metadata Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text fields",
                    "ENTER: Save metadata changes",
                    "ESC: Cancel and return",
                ]),
                ("Metadata Options", [
                    "Read ACL: Control who can read objects",
                    "Write ACL: Control who can write objects",
                    "ACL Examples:",
                    "  .r:* - Public read access",
                    "  .rlistings - Public listings",
                    "  account:user - Specific user access",
                    "Custom metadata displayed as read-only",
                ]),
                generalActions
            ]

        case .swiftObjectMetadata:
            return [
                ("Object Metadata Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text fields",
                    "ENTER: Save metadata changes",
                    "ESC: Cancel and return",
                ]),
                ("Metadata Options", [
                    "Content-Type: MIME type of the object",
                    "Common types: text/plain, image/jpeg, etc.",
                    "Custom metadata displayed as read-only",
                ]),
                generalActions
            ]

        case .swiftDirectoryMetadata:
            return [
                ("Directory Metadata Form", [
                    "TAB: Move to next field",
                    "SPACE: Edit text / Toggle checkbox",
                    "ENTER: Apply metadata to all objects",
                    "ESC: Cancel and return",
                ]),
                ("Metadata Options", [
                    "Content-Type: MIME type to apply to ALL objects",
                    "Recursive: Include subdirectories",
                    "Updates all objects in the directory",
                    "Progress displayed during bulk update",
                ]),
                ("Warning", [
                    "This operation updates MANY objects at once",
                    "Cannot be undone",
                    "Review directory path carefully before applying",
                ]),
                generalActions
            ]

        default:
            // General help for all other views
            return [
                generalNavigation,
                commandNavigation,
                ("View Navigation (Single Key)", [
                    "d: Dashboard view",
                    "h: Health Dashboard view",
                    "k: Key Pairs view",
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
                    "j: Object Storage view",
                    "t: Topology view",
                    "z: Search view",
                ]),
                ("Command Mode Available Commands", [
                    ":servers, :srv, :s - Navigate to Servers",
                    ":networks, :net, :n - Navigate to Networks",
                    ":volumes, :vol, :v - Navigate to Volumes",
                    ":flavors, :flv, :f - Navigate to Flavors",
                    ":images, :img, :i - Navigate to Images",
                    ":routers, :rtr, :r - Navigate to Routers",
                    ":subnets, :sub, :u - Navigate to Subnets",
                    ":ports, :p - Navigate to Ports",
                    ":floatingips, :fip, :l - Navigate to Floating IPs",
                    ":securitygroups, :sec, :e - Navigate to Security Groups",
                    ":servergroups, :sg, :g - Navigate to Server Groups",
                    ":keypairs, :keys, :k - Navigate to Key Pairs",
                    ":swift, :object, :obj, :j - Navigate to Object Storage",
                    ":topology, :topo, :t - Navigate to Topology",
                    ":search, :find, :z - Navigate to Search",
                    ":dashboard, :dash, :d - Navigate to Dashboard",
                    ":health, :h - Navigate to Health Dashboard",
                    ":help, :? - Show help",
                    ":quit, :q - Quit application",
                ]),
                ("Features", [
                    "Auto-refresh: Data updates every 30 seconds",
                    "Smart caching: Reduces API calls",
                    "UUID resolution: Shows friendly names",
                    "Color coding: Visual status indicators",
                    "Search and filtering: Quick resource location",
                    "Keyboard-driven: Full functionality without mouse",
                    "Multi-select mode: Bulk operations (CTRL-X)",
                    "Command mode: Type ':' for smart navigation",
                    "Fuzzy matching: Partial commands auto-complete",
                ]),
                generalActions
            ]
        }
    }

    // MARK: - About Page

    @MainActor
    static func drawAbout(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                         width: Int32, height: Int32, scrollOffset: Int = 0) async {

        // Build about information
        let aboutInfo = getAboutInformation()

        // Build sections for DetailView
        var sections: [DetailSection] = []

        for (sectionTitle, items) in aboutInfo {
            var detailItems: [DetailItem] = []
            for item in items {
                detailItems.append(.field(label: "", value: item, style: .secondary))
            }
            sections.append(DetailSection(title: sectionTitle, items: detailItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "About Substation",
            sections: sections,
            helpText: "Press ESC to return to previous view",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }

    // Cache build information - computed once at first access
    private static let cachedBuildInfo: (version: String, buildDate: String, gitCommit: String, configuration: String) = {
        return getBuildInformation()
    }()

    private static func getAboutInformation() -> [(String, [String])] {
        let buildInfo = cachedBuildInfo

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

        // Get actual build date from executable modification time
        let buildDate = getExecutableBuildDate()

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

    private static func getExecutableBuildDate() -> String {
        // Try to get the modification date of the current executable
        if let executablePath = ProcessInfo.processInfo.arguments.first,
           let attributes = try? FileManager.default.attributesOfItem(atPath: executablePath),
           let modificationDate = attributes[.modificationDate] as? Date {
            return modificationDate.iso8601Formatted()
        }

        // Fallback to current date if we can't read the executable
        return Date().iso8601Formatted()
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

}
