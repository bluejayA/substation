# Networks Module

## Overview

**Service:** OpenStack Neutron
**Identifier:** `networks`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Networks/`

The Networks module provides comprehensive network management capabilities serving as the foundation for all Neutron networking resources. It handles virtual network creation, configuration, and lifecycle management with support for multiple network types including VLAN, VXLAN, Flat, GRE, and Geneve. As a base module with no dependencies, Networks enables other modules like Subnets, Routers, and Ports to build upon its functionality.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Full network listing with provider details, admin state, and shared status |
| **Detail View** | Yes | Comprehensive network details including provider attributes and segments |
| **Create/Edit** | Yes | Multi-step creation wizard with provider network configuration |
| **Batch Operations** | Yes | Bulk delete operations with confirmation |
| **Multi-Select** | Yes | Select multiple networks for batch operations with 'm' key |
| **Search/Filter** | Yes | Filter by name, status, external, shared, or project |
| **Auto-Refresh** | Yes | 60-second refresh interval with manual refresh option |
| **Health Monitoring** | Yes | Tracks network availability and error states |

## Dependencies

### Required Modules

None - Networks is a base module with no dependencies

### Optional Modules

- **qos** - Used for Quality of Service policy assignment
- **availability_zones** - Used for network availability zone placement

## Features

### Resource Management

- **Network Creation**: Create networks with provider attributes and advanced options
- **Provider Networks**: Configure VLAN, VXLAN, Flat, GRE, and Geneve network types
- **Multi-Segment Support**: Create networks with multiple provider segments
- **MTU Configuration**: Set and validate Maximum Transmission Unit values
- **Port Security**: Enable/disable port security at network level
- **External Networks**: Mark networks as external for floating IP pools
- **Shared Networks**: Configure network visibility across projects
- **QoS Integration**: Apply Quality of Service policies to networks
- **Admin State**: Control network administrative state (up/down)
- **Server Attachment**: Attach networks directly to server instances
- **Interface Management**: Manage network interfaces on existing servers

### List Operations

The networks list view provides a comprehensive overview of all networks with real-time status updates, provider information, and quick access to common operations. Virtual scrolling handles large network deployments efficiently.

**List Columns:**

- NAME (29 chars)
- STATUS (11 chars) - Color-coded: active=green, down=red, build/building=yellow
- SHARED (7 chars) - Yes/No indicator
- EXTERNAL (8 chars) - Yes/No indicator

**Available Actions:**

- `Enter` - View detailed network information
- `c` - Create new network
- `d` - Delete selected network
- `a` - Manage server attachments for selected network
- `m` - Toggle multi-select mode
- `M` - Select all networks
- `/` - Search networks by name
- `r` - Refresh network list
- `Esc` or `q` - Back to previous view/main menu

### Detail View

The network detail view provides comprehensive information about a single network including all provider attributes, segments, associated subnets, and configuration details.

**Displayed Information:**

- **Basic Info**: Name, ID, project, description, status
- **Provider Attributes**: Network type, physical network, segmentation ID
- **Network Segments**: Multi-segment configuration with provider details
- **Configuration**: MTU, port security, admin state, external, shared
- **QoS Policy**: Associated quality of service policy if configured
- **Availability Zones**: Network availability zone hints
- **Associated Resources**: Subnets, ports count, and router interfaces
- **Timestamps**: Created and updated times
- **Tags**: User-defined tags and metadata

### Create/Edit Operations

The network creation form provides a comprehensive wizard for configuring new networks with proper validation at each step.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Network Name | Text | Yes | Unique name for the network (letters, numbers, spaces, @._- allowed) |
| Description | Text | No | Human-readable description |
| MTU | Text | Yes | Maximum transmission unit (68-9000, default: 1500) |
| Port Security | Toggle | Yes | Enable/disable port security (default: enabled) |

**Validation Rules:**

- Network name is required and cannot be empty
- Network name can only contain letters, numbers, spaces, and @._- characters
- MTU is required and must be between 68 and 9000

### Batch Operations

The Networks module supports efficient batch operations for managing multiple networks simultaneously.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple networks with single confirmation

**Deletion Priority:** 7 (late deletion) - Networks must be deleted after their dependent resources:
- Subnets (priority 6)
- Ports (priority 5)
- Routers (priority 4)
- Floating IPs (priority 3)

**Idempotent Behavior:** HTTP 404 errors are treated as success to allow retry operations.

## API Endpoints

### Primary Endpoints

- `GET /networks` - List all networks with detailed information
- `GET /networks/{id}` - Get detailed network information
- `POST /networks` - Create new network
- `PUT /networks/{id}` - Update network configuration
- `DELETE /networks/{id}` - Delete network

### Secondary Endpoints

- `GET /qos/policies` - List available QoS policies
- `GET /availability_zones` - List network availability zones
- `POST /servers/{id}/os-interface` - Attach network to server
- `DELETE /servers/{id}/os-interface/{port_id}` - Detach network from server

## Configuration

### Module Settings

```swift
// NetworksModule Configuration
let networksConfig = NetworksModuleConfig(
    identifier: "networks",
    displayName: "Networks (Neutron)",
    version: "1.0.0",
    dependencies: [],
    refreshInterval: 60.0,  // 60 seconds
    maxBulkOperations: 50,  // Maximum networks for batch operations
    enableHealthChecks: true,
    supportedNetworkTypes: ["vlan", "vxlan", "flat", "gre", "geneve"]
)
```

### Environment Variables

- `NEUTRON_ENDPOINT` - Neutron service endpoint URL (Default: from service catalog)
- `NETWORKS_REFRESH_INTERVAL` - Refresh interval in seconds (Default: `60`)
- `MAX_BULK_NETWORKS` - Maximum networks for batch operations (Default: `50`)
- `DEFAULT_MTU` - Default MTU for new networks (Default: `1500`)

### Performance Tuning

- **Virtual Scrolling**: Handles lists of 1,000+ networks efficiently
- **Lazy Loading**: Network details loaded on-demand
- **Batch Fetching**: Fetches networks in batches of 100
- **Cache TTL**: 60-second cache with manual refresh option
- **Diff Updates**: Only updates changed network attributes

## Views

### Registered View Modes

#### Networks List (`.networks`)

**Purpose:** Display all networks with filtering, search, and batch operations

**Key Features:**

- Virtual scrolling for large datasets
- Provider network type indicators
- External and shared network badges
- Quick action buttons
- Search and filter capabilities

**Navigation:**

- **Enter from:** Main menu or any module
- **Exit to:** Network detail, create form, or main menu

#### Network Detail (`.networkDetail`)

**Purpose:** Display comprehensive information about a single network

**Key Features:**

- Full network configuration and provider attributes
- Associated subnets and ports count
- Multi-segment display
- Action buttons for network operations
- Real-time status updates

**Navigation:**

- **Enter from:** Networks list
- **Exit to:** Networks list or related resource views

#### Network Create (`.networkCreate`)

**Purpose:** Multi-step wizard for creating new networks

**Key Features:**

- Step-by-step configuration
- Provider network configuration
- Field validation and help text
- QoS policy selection
- Preview before creation

**Navigation:**

- **Enter from:** Networks list via 'c' key
- **Exit to:** Networks list after creation or cancel

#### Network Server Attachment (`.networkServerAttachment`)

**Purpose:** Attach network to server instances

**Key Features:**

- Server selection interface
- Available networks display
- Fixed IP configuration
- Security group selection

**Navigation:**

- **Enter from:** Networks list via 'A' key
- **Exit to:** Networks list after attachment

#### Network Interface Management (`.networkServerManagement`)

**Purpose:** Manage network interfaces on servers

**Key Features:**

- Current interfaces display
- Add/remove interfaces
- Port configuration
- IP address management

**Navigation:**

- **Enter from:** Networks list via 'I' key
- **Exit to:** Networks list

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
| `c` | Create Network | List | Open network creation form |
| `d` | Delete Network | List | Delete selected network with confirmation |
| `a` | Manage Servers | List | Open server management interface (attach/detach) |
| `m` | Multi-Select | List | Toggle multi-select mode |
| `M` | Select All | List | Select all visible networks |
| `TAB` | Switch Mode | Server Management | Toggle between ATTACH and DETACH modes |
| `SPACE` | Toggle Selection | Server Management | Select/deselect server for operation |

## Data Provider

**Provider Class:** `NetworksDataProvider`

### Caching Strategy

The NetworksDataProvider implements intelligent caching that balances performance with data freshness. Network lists are cached for 60 seconds with automatic invalidation on create/update/delete operations. Provider attributes and segments are cached separately.

### Refresh Patterns

- **Periodic Refresh**: Automatic refresh every 60 seconds for list views
- **On-Demand Refresh**: Manual refresh with 'r' key clears cache
- **Differential Updates**: Only changed attributes updated on refresh
- **Cascade Refresh**: Updates trigger refresh of dependent resources

### Performance Optimizations

- **Virtual Scrolling**: Renders only visible networks in list view
- **Lazy Detail Loading**: Network details fetched only when accessed
- **Batch API Calls**: Groups multiple network fetches into single requests
- **Resource Pooling**: Reuses view components for memory efficiency
- **Segment Caching**: Provider segments cached independently

## Known Limitations

### Current Constraints

- **RBAC Policies**: Role-based access control for network sharing not exposed
- **Service Insertion**: Service function chaining not implemented
- **IPv6 Prefix Delegation**: Not configurable through UI
- **BGP Integration**: BGP dynamic routing not supported
- **Trunk Ports**: Trunk port creation not available
- **Network Segments**: Limited to single segment in creation form

### Planned Improvements

- Add RBAC policy management for network sharing
- Implement service insertion chain configuration
- Support IPv6 prefix delegation options
- Add BGP speaker integration
- Enable trunk port creation and management
- Support multi-segment network creation in UI
- Add network topology visualization
- Implement bandwidth limit configuration

## Examples

### Common Usage Scenarios

#### Creating a Provider Network

```
1. Press 'c' in networks list to open creation form
2. Enter network name (e.g., "provider-vlan-100")
3. Select "VLAN" as provider network type
4. Enter physical network name (e.g., "physnet1")
5. Enter VLAN ID (e.g., 100)
6. Set MTU if needed (e.g., 9000 for jumbo frames)
7. Enable "External" for floating IP pool
8. Press Enter to create
9. Monitor status in list view
```

#### Attaching Network to Server

```
1. Select network in list view
2. Press 'A' to open attachment interface
3. Select target server from list
4. Optionally specify fixed IP address
5. Select security groups to apply
6. Press Enter to attach
7. Verify attachment in server detail view
```

#### Managing Network Interfaces

```
1. Press 'I' in networks list
2. Select server to manage
3. View current network attachments
4. Press 'a' to add new interface
5. Select network and configure port
6. Press 'd' to detach interface
7. Confirm changes
```

### Code Examples

#### Programmatic Access

```swift
// Access networks through the module
let networksModule = tui.moduleRegistry.module(for: "networks") as? NetworksModule
let networks = networksModule?.networks ?? []

// Filter external networks
let externalNetworks = networks.filter { $0.external == true }

// Get network by name
let publicNetwork = networks.first { $0.name == "public" }
```

#### Custom Integration

```swift
// Implement custom network action
extension NetworksModule {
    func createProviderNetwork(
        name: String,
        vlanId: Int,
        physicalNetwork: String
    ) async throws {
        guard let tui = tui else { return }

        let network = Network(
            name: name,
            providerNetworkType: "vlan",
            providerPhysicalNetwork: physicalNetwork,
            providerSegmentationId: vlanId,
            adminStateUp: true
        )

        try await tui.client.createNetwork(network)
        await tui.dataManager.refreshNetworks()
    }
}
```

## Troubleshooting

### Common Issues

#### Network Creation Fails

**Symptoms:** Network creation returns error about provider attributes
**Cause:** Insufficient permissions or invalid provider configuration
**Solution:** Verify admin permissions, check physical network mapping in neutron.conf

#### Cannot Delete Network

**Symptoms:** Delete operation fails with "Network in use" error
**Cause:** Network has active ports or subnets
**Solution:** Delete all subnets and detach all ports before deleting network

#### External Network Not Available for Floating IPs

**Symptoms:** Network marked as external but not available in floating IP creation
**Cause:** Network not configured with external router gateway
**Solution:** Ensure network has router with external gateway configured

#### MTU Mismatch Issues

**Symptoms:** Connectivity problems, packet fragmentation
**Cause:** MTU not properly configured across network path
**Solution:** Set consistent MTU values, verify physical network MTU support

### Debug Commands

- `openstack network show --debug {network-id}` - Detailed network information
- `openstack network segment list {network-id}` - Show network segments
- `openstack port list --network {network-id}` - List all ports on network
- `neutron net-list-on-dhcp-agent {agent-id}` - Show networks on DHCP agent

## Related Documentation

- [Module Catalog](./index.md)
- [Subnets Module](./subnets.md)
- [Routers Module](./routers.md)
- [Ports Module](./ports.md)
- [OpenStack Neutron Documentation](https://docs.openstack.org/neutron/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `networks` |
| **Display Name** | Networks (Neutron) |
| **Version** | 1.0.0 |
| **Service** | OpenStack Neutron |
| **Category** | Networking |
| **Deletion Priority** | 7 (Late) |
| **Load Order** | 20 |
| **Typical Memory Usage** | 5-20 MB |
| **CPU Impact** | Low |
