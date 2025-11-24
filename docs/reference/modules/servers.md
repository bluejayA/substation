# Servers Module

## Overview

**Service:** OpenStack Nova (Compute)
**Identifier:** `servers`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Servers/`

The Servers module provides comprehensive server (instance) management capabilities, serving as the most complex and feature-rich module in Substation. It handles the full lifecycle of compute instances from creation through deletion, including advanced operations like resizing, snapshots, console access, and network management. The module integrates with multiple OpenStack services to provide a unified interface for server operations.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Full server listing with status indicators, filtering, and search |
| **Detail View** | Yes | Comprehensive server details including flavor, image, networks, and volumes |
| **Create/Edit** | Yes | Multi-step creation wizard with validation and bulk creation support |
| **Batch Operations** | Yes | Bulk delete, start, stop, and reboot operations |
| **Multi-Select** | Yes | Select multiple servers for batch operations with 'm' key |
| **Search/Filter** | Yes | Filter by name, status, IP address, or metadata |
| **Auto-Refresh** | Yes | 60-second refresh interval with accelerated refresh after operations |
| **Health Monitoring** | Yes | Tracks server health percentage and error rates |

## Dependencies

### Required Modules

- **networks** - Required for network interface management and IP allocation
- **images** - Required for selecting boot images during server creation
- **flavors** - Required for hardware profile selection and resize operations
- **keypairs** - Required for SSH key injection during server creation
- **volumes** - Required for block storage attachment and boot-from-volume
- **securitygroups** - Required for firewall rule management and security configuration

### Optional Modules

- **floatingips** - Used for associating public IP addresses with servers
- **servergroups** - Used for anti-affinity and affinity scheduling policies
- **ports** - Used for advanced network port configuration

## Features

### Resource Management

- **Lifecycle Management**: Complete control over server states (create, start, stop, reboot, delete)
- **Console Access**: Remote console access via noVNC with browser integration
- **Resize Operations**: Change server flavors with confirmation/revert workflow
- **Snapshot Creation**: Create image snapshots of running servers with metadata
- **Network Management**: Attach/detach network interfaces dynamically
- **Volume Operations**: Attach/detach block storage volumes
- **Security Groups**: Manage firewall rules and security group assignments
- **Metadata Management**: Set and update server metadata and tags
- **User Data**: Inject cloud-init scripts and configuration
- **Scheduling**: Control placement with availability zones and server groups

### List Operations

The servers list view provides a comprehensive overview of all instances with real-time status updates, resource usage indicators, and quick access to common operations. The view supports virtual scrolling for handling thousands of servers efficiently.

**Available Actions:**

- `Enter` - View detailed server information
- `s` - Start server
- `S` - Stop server (uppercase = destructive)
- `r` - Soft reboot server
- `R` - Resize server (uppercase = significant change)
- `c` - Open console
- `l` - View console logs
- `n` - Create snapshot
- `Ctrl-X` - Toggle multi-select mode
- `Space` - Toggle selection (in multi-select mode)
- `/` - Search servers
- `Del` - Delete selected server
- `q` - Back to main menu

**Note**: Use `:create` command to create new servers (no keyboard shortcut).

### Detail View

The server detail view provides comprehensive information about a single server instance, including all configuration details, current state, attached resources, and available actions.

**Displayed Information:**

- **Basic Info**: Name, ID, status, power state, task state
- **Hardware**: Flavor details (vCPUs, RAM, disk), current usage
- **Operating System**: Image name, kernel ID, ramdisk ID
- **Network Configuration**: All network interfaces with IP addresses, MAC addresses, and security groups
- **Storage**: Attached volumes with mount points and device names
- **Metadata**: User metadata, system metadata, and tags
- **Timestamps**: Created, updated, launched times
- **Fault Information**: Error messages and fault details if applicable
- **Host Information**: Hypervisor hostname, availability zone

### Create/Edit Operations

The server creation form is a comprehensive multi-step wizard that guides users through configuring a new instance with proper validation at each step.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Server Name | Text | Yes | Unique name for the server instance |
| Boot Source | Select | Yes | Choose between Image or Volume boot |
| Image/Volume | Select | Yes | Select boot image or bootable volume |
| Flavor | Select | Yes | Hardware profile defining vCPUs, RAM, disk |
| Networks | Multi-Select | No | Networks to attach (auto-allocate if empty) |
| Security Groups | Multi-Select | No | Security groups to apply |
| Key Pair | Select | No | SSH key pair for authentication |
| Availability Zone | Select | No | Placement zone for the server |
| Server Group | Select | No | Scheduling group for affinity rules |
| User Data | Text | No | Cloud-init script or configuration |
| Max Servers | Number | Yes | Number of servers to create (1-100) |
| Configuration Drive | Toggle | No | Attach metadata drive |
| Description | Text | No | Human-readable description |

### Batch Operations

The Servers module supports efficient batch operations for managing multiple instances simultaneously, with progress tracking and error handling.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple servers with single confirmation
- **Bulk Start**: Start multiple stopped servers
- **Bulk Stop**: Stop multiple running servers
- **Bulk Reboot**: Reboot multiple servers
- **Bulk Snapshot**: Create snapshots of multiple servers

## API Endpoints

### Primary Endpoints

- `GET /servers` - List all servers with detailed information
- `GET /servers/{id}` - Get detailed server information
- `POST /servers` - Create new server instance
- `DELETE /servers/{id}` - Delete server
- `POST /servers/{id}/action` - Perform server actions (start, stop, reboot, resize)
- `GET /servers/{id}/os-console-output` - Get console output logs
- `POST /servers/{id}/remote-consoles` - Get remote console URL

### Secondary Endpoints

- `GET /flavors` - List available flavors for resize
- `GET /images` - List bootable images
- `POST /servers/{id}/os-interface` - Attach network interface
- `DELETE /servers/{id}/os-interface/{port_id}` - Detach network interface
- `POST /servers/{id}/os-volume_attachments` - Attach volume
- `DELETE /servers/{id}/os-volume_attachments/{id}` - Detach volume
- `PUT /servers/{id}/metadata` - Update server metadata
- `POST /servers/{id}/createImage` - Create server snapshot

## Configuration

### Module Settings

```swift
// ServersModule Configuration
let serversConfig = ServersModuleConfig(
    identifier: "servers",
    displayName: "Servers (Nova)",
    version: "1.0.0",
    dependencies: ["networks", "images", "flavors", "keypairs", "volumes", "securitygroups"],
    refreshInterval: 60.0,  // 60 seconds
    maxBulkOperations: 50,  // Maximum servers for batch operations
    consoleProtocol: .novnc,  // Default console protocol
    enableHealthChecks: true
)
```

### Environment Variables

- `NOVA_ENDPOINT` - Nova service endpoint URL (Default: from service catalog)
- `SERVERS_REFRESH_INTERVAL` - Refresh interval in seconds (Default: `60`)
- `MAX_BULK_SERVERS` - Maximum servers for batch operations (Default: `50`)
- `CONSOLE_TIMEOUT` - Console connection timeout in seconds (Default: `30`)

### Performance Tuning

- **Virtual Scrolling**: Handles lists of 10,000+ servers efficiently
- **Lazy Loading**: Server details loaded on-demand
- **Batch Fetching**: Fetches servers in batches of 100
- **Cache TTL**: 60-second cache with manual refresh option
- **Diff Updates**: Only updates changed server attributes

## Views

### Registered View Modes

#### Servers List (`.servers`)

**Purpose:** Display all servers with filtering, search, and batch operations

**Key Features:**

- Virtual scrolling for large datasets
- Real-time status indicators
- Multi-column layout with resource usage
- Quick action buttons
- Search and filter capabilities

**Navigation:**

- **Enter from:** Main menu, dashboard, or any module
- **Exit to:** Server detail, create form, or main menu

#### Server Detail (`.serverDetail`)

**Purpose:** Display comprehensive information about a single server

**Key Features:**

- Full server configuration and state
- Attached resources (networks, volumes, security groups)
- Action buttons for server operations
- Scrollable content for long details
- Real-time status updates

**Navigation:**

- **Enter from:** Servers list or direct navigation
- **Exit to:** Servers list or related resource views

#### Server Create (`.serverCreate`)

**Purpose:** Multi-step wizard for creating new server instances

**Key Features:**

- Step-by-step configuration
- Field validation and help text
- Resource selection (images, flavors, networks)
- Bulk creation support
- Preview before creation

**Navigation:**

- **Enter from:** Servers list via 'c' key
- **Exit to:** Servers list after creation or cancel

#### Server Console (`.serverConsole`)

**Purpose:** Display remote console access information

**Key Features:**

- Console URL display
- Protocol information (noVNC, SPICE, etc.)
- Browser launch capability
- Connection status

**Navigation:**

- **Enter from:** Servers list via 'O' key
- **Exit to:** Servers list

#### Server Resize (`.serverResize`)

**Purpose:** Manage server resize operations

**Key Features:**

- Flavor selection with comparison
- Resource change preview
- Confirm/revert workflow for pending resizes
- Validation of resize compatibility

**Navigation:**

- **Enter from:** Servers list via 'Z' key
- **Exit to:** Servers list after resize

#### Snapshot Management (`.serverSnapshotManagement`)

**Purpose:** Create and manage server snapshots

**Key Features:**

- Snapshot naming and description
- Metadata configuration
- Progress tracking
- Error handling

**Navigation:**

- **Enter from:** Servers list via 'P' key
- **Exit to:** Servers list after creation

#### Server Security Groups (`.serverSecurityGroups`)

**Purpose:** Manage security group assignments for a server

**Key Features:**

- View current security groups attached to server
- Add/remove security groups dynamically
- Multi-select for batch operations
- Real-time validation

**Navigation:**

- **Enter from:** Server detail view
- **Exit to:** Server detail view

#### Server Network Interfaces (`.serverNetworkInterfaces`)

**Purpose:** Manage network interfaces attached to a server

**Key Features:**

- View all network interfaces with IP addresses
- Attach new network interfaces
- Detach existing interfaces
- Port security configuration
- MAC address information

**Navigation:**

- **Enter from:** Server detail view
- **Exit to:** Server detail view

#### Server Group Management (`.serverGroupManagement`)

**Purpose:** Manage server group membership for scheduling policies

**Key Features:**

- View current server group assignment
- Add server to server groups
- Remove from server groups
- Affinity/anti-affinity policy display

**Navigation:**

- **Enter from:** Server detail view or server list
- **Exit to:** Server list or detail view

## Keyboard Shortcuts

### Global Shortcuts (Available in all module views)

| Key | Action | Context |
|-----|--------|---------|
| `Enter` | Select/View Details | List views |
| `Esc` | Go Back | Any view |
| `q` | Quit to Main Menu | Any view |
| `/` | Search | List views |
| `r` | Refresh | List views |

### Module-Specific Shortcuts

| Key | Action | View | Description |
|-----|--------|------|-------------|
| `s` | Start Server | List | Start selected stopped server |
| `S` | Stop Server | List | Stop selected running server (uppercase = destructive) |
| `r` | Reboot Server | List | Soft reboot selected server |
| `R` | Resize Server | List | Change server flavor/size (uppercase = significant change) |
| `l` | View Logs | List | Display console output logs |
| `c` | Open Console | List | Open remote console |
| `n` | Create Snapshot | List | Create snapshot of selected server |
| `Ctrl-X` | Multi-Select | List | Toggle multi-select mode |
| `Space` | Select Item | List | In multi-select mode: toggle selection of current item |

**Note**: Create and delete operations use command mode (`:create`, `:delete`) or `Del` key, not letter shortcuts.

## Data Provider

**Provider Class:** `ServersDataProvider`

### Caching Strategy

The ServersDataProvider implements an intelligent caching strategy that balances performance with data freshness. Server lists are cached for 60 seconds with automatic invalidation on create/update/delete operations. Individual server details are cached separately with shorter TTLs for dynamic attributes like status.

### Refresh Patterns

- **Periodic Refresh**: Automatic refresh every 60 seconds for list views
- **Accelerated Refresh**: 5-second refresh after state-changing operations
- **On-Demand Refresh**: Manual refresh with 'r' key clears cache
- **Differential Updates**: Only changed attributes updated on refresh
- **State Transition Monitoring**: Increased refresh rate during BUILD/RESIZE states

### Performance Optimizations

- **Virtual Scrolling**: Renders only visible servers in list view
- **Lazy Detail Loading**: Server details fetched only when accessed
- **Batch API Calls**: Groups multiple server fetches into single requests
- **Resource Pooling**: Reuses view components for memory efficiency
- **Background Prefetch**: Preloads likely-to-be-accessed server details

## Known Limitations

### Current Constraints

- **Console Support**: Only noVNC console protocol currently supported for browser launch
- **Live Migration**: Live migration operations not yet exposed in UI
- **Shelving**: Server shelve/unshelve operations not implemented
- **Rescue Mode**: Rescue mode operations not available
- **Host Aggregates**: Cannot view or manage host aggregate membership
- **Quotas**: No quota information displayed during creation
- **Metrics**: No integration with Ceilometer/Gnocchi for metrics

### Planned Improvements

- Add support for SPICE and RDP console protocols
- Implement live migration interface
- Add shelve/unshelve operations
- Support rescue mode operations
- Display quota usage during server creation
- Integrate metrics and monitoring data
- Add server group management interface
- Implement server backup scheduling

## Examples

### Common Usage Scenarios

#### Creating a Server from an Image

```
1. Press 'c' in servers list to open creation form
2. Enter server name
3. Select "Image" as boot source
4. Choose an image (e.g., Ubuntu 22.04)
5. Select a flavor (e.g., m1.small)
6. Select network(s) or leave empty for auto-allocation
7. Optionally select security groups
8. Optionally select SSH key pair
9. Press Enter to create
10. Monitor status in list view
```

#### Resizing a Server

```
1. Select server in list view
2. Press 'Z' to open resize dialog
3. Select new flavor from list
4. Review resource changes
5. Press Enter to initiate resize
6. Wait for VERIFY_RESIZE status
7. Press 'Z' again on server
8. Choose "Confirm" or "Revert"
9. Press Enter to complete
```

#### Bulk Server Management

```
1. Press 'm' to enable multi-select mode
2. Use j/k to navigate and Space to select servers
3. Or press 'M' to select all
4. Press 'd' for bulk delete
5. Confirm operation
6. Monitor background operation progress
```

### Code Examples

#### Programmatic Access

```swift
// Access servers through the module
let serversModule = tui.moduleRegistry.module(for: "servers") as? ServersModule
let servers = serversModule?.servers ?? []

// Filter active servers
let activeServers = servers.filter { $0.status == .active }

// Get server by name
let webServer = servers.first { $0.name == "web-server-01" }
```

#### Custom Integration

```swift
// Implement custom server action
extension ServersModule {
    func customServerAction(serverId: String) async throws {
        guard let tui = tui else { return }

        // Perform custom API call
        let response = try await tui.client.performAction(
            serverId: serverId,
            action: "custom-action"
        )

        // Refresh server data
        await tui.dataManager.refreshServers()

        // Update status
        tui.statusMessage = "Custom action completed"
    }
}
```

## Troubleshooting

### Common Issues

#### Server Stuck in BUILD State

**Symptoms:** Server remains in BUILD state for extended period
**Cause:** Resource constraints, image issues, or network problems
**Solution:** Check compute node logs, verify image availability, check quotas

#### Console Connection Failed

**Symptoms:** Cannot open console, connection times out
**Cause:** Console proxy service down, firewall blocking ports
**Solution:** Verify nova-consoleauth and nova-novncproxy services, check port 6080

#### Resize Operation Fails

**Symptoms:** Resize fails with "No valid host" error
**Cause:** No compute node has sufficient resources for new flavor
**Solution:** Check available resources, consider smaller flavor or free up resources

#### Network Attachment Fails

**Symptoms:** Cannot attach network to server
**Cause:** Port limit reached, network not available in AZ
**Solution:** Check port quotas, verify network availability in server's AZ

### Debug Commands

- `openstack server show --debug {server-id}` - Detailed server information with debug output
- `openstack console log show {server-id}` - View full console output
- `openstack server event list {server-id}` - Show server event history
- `nova diagnostics {server-id}` - Get server diagnostics (admin only)

## Related Documentation

- [Module Catalog](./index.md)
- [Networks Module](./networks.md)
- [Volumes Module](./volumes.md)
- [OpenStack Nova Documentation](https://docs.openstack.org/nova/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `servers` |
| **Display Name** | Servers (Nova) |
| **Version** | 1.0.0 |
| **Service** | OpenStack Nova (Compute) |
| **Category** | Compute |
| **Deletion Priority** | 1 (Highest) |
| **Load Order** | 10 |
| **Typical Memory Usage** | 10-50 MB |
| **CPU Impact** | Low to Medium |

---

*Last Updated: November 2024*
*Documentation Version: 1.0*
