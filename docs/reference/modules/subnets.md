# Subnets Module

## Overview

**Service:** OpenStack Neutron
**Identifier:** `subnets`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Subnets/`

The Subnets module provides comprehensive subnet management capabilities including IPv4 and IPv6 subnet creation, CIDR network analysis, DHCP configuration, and router connectivity management. Subnets define IP address ranges within networks and control how IP addresses are allocated to ports. The module depends on the Networks module as subnets are always associated with a parent network.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Full subnet listing with CIDR, gateway, and DHCP status |
| **Detail View** | Yes | Comprehensive subnet details with allocation pools and host routes |
| **Create/Edit** | Yes | Creation wizard with CIDR validation and DHCP configuration |
| **Batch Operations** | Yes | Bulk delete operations with confirmation |
| **Multi-Select** | Yes | Select multiple subnets for batch operations |
| **Search/Filter** | Yes | Filter by name, CIDR, network, or enable state |
| **Auto-Refresh** | Yes | 60-second refresh interval with manual refresh option |
| **Health Monitoring** | Yes | Tracks IP allocation usage and DHCP agent status |

## Dependencies

### Required Modules

- **networks** - Required for parent network association and network lookups

### Optional Modules

- **routers** - Used for router interface attachment and gateway configuration

## Features

### Resource Management

- **Subnet Creation**: Create IPv4 and IPv6 subnets with CIDR notation
- **IP Version Support**: Full support for IPv4 and IPv6 addressing
- **DHCP Configuration**: Enable/disable DHCP with options configuration
- **Allocation Pools**: Define custom IP allocation ranges
- **Gateway Management**: Configure gateway IP or disable gateway
- **DNS Configuration**: Set DNS nameservers and domain name
- **Host Routes**: Configure static routes for subnet routing
- **Router Attachment**: Attach subnets to router interfaces
- **IP Allocation Tracking**: Monitor IP usage and availability
- **Subnet Pools**: Integration with subnet pool allocation

### List Operations

The subnets list view provides a comprehensive overview of all subnets with CIDR information, DHCP status, and allocation statistics. The view supports filtering by parent network and IP version.

**Available Actions:**

- `Enter` - View detailed subnet information
- `c` - Create new subnet
- `d` - Delete selected subnet
- `R` - Manage router attachments
- `m` - Toggle multi-select mode
- `M` - Select all subnets
- `/` - Search subnets by name or CIDR
- `r` - Refresh subnet list
- `q` - Back to main menu

### Detail View

The subnet detail view provides comprehensive information about IP allocation, DHCP configuration, and routing settings.

**Displayed Information:**

- **Basic Info**: Name, ID, network ID, project
- **IP Configuration**: CIDR, IP version, gateway IP
- **Allocation Pools**: Start and end IP ranges for allocation
- **DHCP Settings**: DHCP enabled status and options
- **DNS Configuration**: Nameservers and DNS domain
- **Host Routes**: Static routes with destination and nexthop
- **IP Usage**: Total IPs, used IPs, available IPs
- **Router Interfaces**: Attached router interfaces
- **Service Types**: Network service types for subnet
- **Timestamps**: Created and updated times

### Create/Edit Operations

The subnet creation form provides comprehensive configuration for IP addressing and DHCP settings.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Subnet Name | Text | No | Display name for the subnet |
| Network | Select | Yes | Parent network for the subnet |
| IP Version | Select | Yes | IPv4 or IPv6 |
| CIDR | Text | Yes | Network address in CIDR notation |
| Gateway IP | Text | No | Gateway IP address (auto if blank) |
| No Gateway | Toggle | No | Disable gateway for isolated subnet |
| Enable DHCP | Toggle | Yes | Enable DHCP service (default: true) |
| Allocation Pools | List | No | Custom IP allocation ranges |
| DNS Nameservers | List | No | DNS server IP addresses |
| Host Routes | List | No | Static routes for the subnet |
| IPv6 Address Mode | Select | No | SLAAC, DHCPv6-stateful, DHCPv6-stateless |
| IPv6 RA Mode | Select | No | Router advertisement mode |

### Batch Operations

The Subnets module supports batch operations for managing multiple subnets efficiently.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple subnets with single confirmation
- **Bulk DHCP Toggle**: Enable/disable DHCP on multiple subnets

## API Endpoints

### Primary Endpoints

- `GET /subnets` - List all subnets with details
- `GET /subnets/{id}` - Get detailed subnet information
- `POST /subnets` - Create new subnet
- `PUT /subnets/{id}` - Update subnet configuration
- `DELETE /subnets/{id}` - Delete subnet

### Secondary Endpoints

- `GET /networks/{id}` - Get parent network information
- `PUT /routers/{id}/add_router_interface` - Attach subnet to router
- `PUT /routers/{id}/remove_router_interface` - Detach subnet from router
- `GET /ports?fixed_ips=subnet_id={id}` - List ports using subnet

## Configuration

### Module Settings

```swift
// SubnetsModule Configuration
let subnetsConfig = SubnetsModuleConfig(
    identifier: "subnets",
    displayName: "Subnets (Neutron)",
    version: "1.0.0",
    dependencies: ["networks"],
    refreshInterval: 60.0,  // 60 seconds
    maxBulkOperations: 50,  // Maximum subnets for batch operations
    enableHealthChecks: true,
    defaultEnableDHCP: true,
    defaultIPVersion: 4
)
```

### Environment Variables

- `NEUTRON_ENDPOINT` - Neutron service endpoint URL (Default: from service catalog)
- `SUBNETS_REFRESH_INTERVAL` - Refresh interval in seconds (Default: `60`)
- `MAX_BULK_SUBNETS` - Maximum subnets for batch operations (Default: `50`)
- `DEFAULT_DNS_NAMESERVERS` - Default DNS servers for new subnets (Default: `8.8.8.8,8.8.4.4`)

### Performance Tuning

- **Virtual Scrolling**: Handles lists of 1,000+ subnets efficiently
- **Lazy Loading**: Subnet details and allocation pools loaded on-demand
- **Batch Fetching**: Fetches subnets in batches of 100
- **Cache TTL**: 60-second cache with manual refresh option
- **IP Calculation Caching**: CIDR calculations cached for performance

## Views

### Registered View Modes

#### Subnets List (`.subnets`)

**Purpose:** Display all subnets with CIDR information and management options

**Key Features:**

- Virtual scrolling for large datasets
- CIDR and gateway display
- DHCP status indicators
- IP allocation usage bars
- Quick action buttons

**Navigation:**

- **Enter from:** Main menu or Networks module
- **Exit to:** Subnet detail, create form, or main menu

#### Subnet Detail (`.subnetDetail`)

**Purpose:** Display comprehensive subnet configuration and allocation details

**Key Features:**

- Full IP configuration display
- Allocation pool visualization
- Host routes and DNS settings
- Router interface information
- IP usage statistics

**Navigation:**

- **Enter from:** Subnets list
- **Exit to:** Subnets list or router management

#### Subnet Create (`.subnetCreate`)

**Purpose:** Wizard for creating new subnets with validation

**Key Features:**

- CIDR notation validation
- Automatic gateway calculation
- Allocation pool configuration
- DHCP options setup
- IPv6 configuration modes

**Navigation:**

- **Enter from:** Subnets list via 'c' key
- **Exit to:** Subnets list after creation

#### Router Management (`.subnetRouterManagement`)

**Purpose:** Manage subnet attachment to router interfaces

**Key Features:**

- Available routers list
- Current attachments display
- Interface IP configuration
- Attach/detach operations

**Navigation:**

- **Enter from:** Subnets list via 'R' key
- **Exit to:** Subnets list

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
| `c` | Create Subnet | List | Open subnet creation form |
| `d` | Delete Subnet | List | Delete selected subnet |
| `R` | Router Management | List | Manage router attachments |
| `D` | Toggle DHCP | List/Detail | Enable/disable DHCP service |
| `m` | Multi-Select | List | Toggle multi-select mode |
| `M` | Select All | List | Select all visible subnets |
| `A` | Add Allocation Pool | Create/Edit | Add IP allocation range |
| `N` | Add Nameserver | Create/Edit | Add DNS nameserver |
| `H` | Add Host Route | Create/Edit | Add static route |

## Data Provider

**Provider Class:** `SubnetsDataProvider`

### Caching Strategy

The SubnetsDataProvider implements intelligent caching for subnet data and IP calculations. Subnet lists are cached for 60 seconds with automatic invalidation on modifications. CIDR calculations and IP usage statistics are cached separately.

### Refresh Patterns

- **Periodic Refresh**: Automatic refresh every 60 seconds
- **On-Demand Refresh**: Manual refresh with 'r' key
- **Parent Network Sync**: Refreshes when parent network changes
- **Router Interface Updates**: Refreshes on attachment changes

### Performance Optimizations

- **Virtual Scrolling**: Renders only visible subnets
- **Lazy IP Calculation**: IP statistics calculated on-demand
- **Batch API Calls**: Groups multiple subnet fetches
- **CIDR Caching**: Network calculations cached
- **Allocation Pool Optimization**: Efficient range calculations

## Known Limitations

### Current Constraints

- **Subnet Pool Integration**: Limited subnet pool allocation UI
- **Service Types**: Cannot configure service types through UI
- **Segment Support**: No support for network segment association
- **IPv6 Prefix Delegation**: Not configurable in creation form
- **DHCP Options**: Advanced DHCP options not exposed
- **Subnet Resize**: Cannot modify CIDR after creation

### Planned Improvements

- Add subnet pool allocation interface
- Implement service type configuration
- Support network segment association
- Add IPv6 prefix delegation options
- Expose advanced DHCP configuration
- Add subnet usage visualization graphs
- Implement IP address calculator tool
- Add subnet splitting/merging utilities

## Examples

### Common Usage Scenarios

#### Creating a Private Subnet

```
1. Press 'c' in subnets list
2. Select parent network (e.g., "private")
3. Enter subnet name (e.g., "private-subnet-10.0.1.0")
4. Select IP version (4)
5. Enter CIDR (e.g., "10.0.1.0/24")
6. Leave gateway blank for automatic assignment
7. Keep DHCP enabled
8. Add DNS nameservers (8.8.8.8, 8.8.4.4)
9. Press Enter to create
```

#### Attaching Subnet to Router

```
1. Select subnet in list view
2. Press 'R' for router management
3. Select target router from list
4. Optionally specify interface IP
5. Press Enter to attach
6. Verify in router interfaces view
```

#### Configuring Custom Allocation Pools

```
1. During subnet creation, press 'A'
2. Enter start IP (e.g., "10.0.1.100")
3. Enter end IP (e.g., "10.0.1.200")
4. Add additional pools as needed
5. Continue with subnet creation
```

### Code Examples

#### Programmatic Access

```swift
// Access subnets through the module
let subnetsModule = tui.moduleRegistry.module(for: "subnets") as? SubnetsModule
let subnets = subnetsModule?.subnets ?? []

// Filter subnets by network
let networkSubnets = subnets.filter { $0.networkId == networkId }

// Calculate IP usage
let usage = subnet.calculateIPUsage()
print("Used: \(usage.used)/\(usage.total)")
```

#### Custom Integration

```swift
// Create subnet with custom configuration
extension SubnetsModule {
    func createSubnetWithPools(
        networkId: String,
        cidr: String,
        pools: [(String, String)]
    ) async throws {
        guard let tui = tui else { return }

        let allocationPools = pools.map {
            AllocationPool(start: $0.0, end: $0.1)
        }

        let subnet = Subnet(
            networkId: networkId,
            cidr: cidr,
            ipVersion: 4,
            enableDHCP: true,
            allocationPools: allocationPools
        )

        try await tui.client.createSubnet(subnet)
        await tui.dataManager.refreshSubnets()
    }
}
```

## Troubleshooting

### Common Issues

#### Subnet Creation Fails with Overlap Error

**Symptoms:** Creation fails with "overlapping CIDR" error
**Cause:** CIDR range overlaps with existing subnet
**Solution:** Check existing subnets, use non-overlapping CIDR

#### Cannot Delete Subnet

**Symptoms:** Delete fails with "subnet in use" error
**Cause:** Subnet has active ports or router interface
**Solution:** Delete ports and detach from router first

#### DHCP Not Working

**Symptoms:** Instances not receiving IP addresses
**Cause:** DHCP agent down or network misconfiguration
**Solution:** Check DHCP agent status, verify network configuration

#### IP Allocation Exhausted

**Symptoms:** Port creation fails with "no more IP addresses"
**Cause:** All IPs in allocation pools used
**Solution:** Expand allocation pools or create additional subnet

### Debug Commands

- `openstack subnet show --debug {subnet-id}` - Detailed subnet information
- `openstack port list --fixed-ip subnet={subnet-id}` - List ports using subnet
- `neutron dhcp-agent-list-hosting-net {network-id}` - Show DHCP agents
- `openstack subnet pool list` - List available subnet pools

## Related Documentation

- [Module Catalog](./index.md)
- [Networks Module](./networks.md)
- [Routers Module](./routers.md)
- [Ports Module](./ports.md)
- [OpenStack Neutron Documentation](https://docs.openstack.org/neutron/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `subnets` |
| **Display Name** | Subnets (Neutron) |
| **Version** | 1.0.0 |
| **Service** | OpenStack Neutron |
| **Category** | Networking |
| **Deletion Priority** | 4 (Medium-Low) |
| **Load Order** | 21 |
| **Typical Memory Usage** | 5-15 MB |
| **CPU Impact** | Low |

---

*Last Updated: January 2025*
*Documentation Version: 1.1*
