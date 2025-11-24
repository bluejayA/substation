# Routers Module

## Overview

**Service:** OpenStack Neutron
**Identifier:** `routers`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Routers/`

The Routers module provides comprehensive router management capabilities for connecting networks and enabling external connectivity in OpenStack environments. Routers serve as the gateway between internal networks and external networks, providing NAT, floating IP support, and inter-subnet routing. The module supports advanced features including Distributed Virtual Routers (DVR) and High Availability (HA) configurations.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Full router listing with gateway status and HA indicators |
| **Detail View** | Yes | Comprehensive router details with interfaces and routes |
| **Create/Edit** | Yes | Creation wizard with external gateway and HA configuration |
| **Batch Operations** | Yes | Bulk delete and admin state changes |
| **Multi-Select** | Yes | Select multiple routers for batch operations |
| **Search/Filter** | Yes | Filter by name, status, or external gateway |
| **Auto-Refresh** | Yes | 60-second refresh interval with manual refresh option |
| **Health Monitoring** | Yes | Tracks router status and HA failover states |

## Dependencies

### Required Modules

- **networks** - Required for external gateway network selection

### Optional Modules

- **subnets** - Used for subnet interface attachment
- **floatingips** - Used for floating IP allocation through router

## Features

### Resource Management

- **Router Creation**: Create routers with external gateway configuration
- **External Gateway**: Configure SNAT and external network connectivity
- **Interface Management**: Attach/detach subnet interfaces
- **Static Routes**: Configure static routes for custom routing
- **High Availability**: Enable HA with automatic failover
- **Distributed Routing**: Configure DVR for optimized east-west traffic
- **Admin State**: Control router operational state
- **Floating IP Gateway**: Provide NAT gateway for floating IPs
- **Port Forwarding**: Configure port forwarding rules (where supported)
- **Extra Routes**: Add static routes beyond connected subnets

### List Operations

The routers list view provides a comprehensive overview of all routers with external gateway information, HA status, and interface counts.

**Available Actions:**

- `Enter` - View detailed router information
- `c` - Create new router
- `d` - Delete selected router
- `E` - Set/clear external gateway
- `I` - Manage router interfaces
- `m` - Toggle multi-select mode
- `M` - Select all routers
- `/` - Search routers by name
- `r` - Refresh router list
- `q` - Back to main menu

### Detail View

The router detail view provides comprehensive information about router configuration, interfaces, and routing table.

**Displayed Information:**

- **Basic Info**: Name, ID, project, description
- **External Gateway**: External network, SNAT status, external IPs
- **Admin State**: Administrative status (up/down)
- **HA Configuration**: HA enabled, active/standby status
- **DVR Settings**: Distributed mode configuration
- **Router Interfaces**: Attached subnet interfaces with IPs
- **Static Routes**: Configured static routes
- **Floating IPs**: Associated floating IP addresses
- **Availability Zones**: Router availability zone hints
- **Timestamps**: Created and updated times

### Create/Edit Operations

The router creation form provides configuration options for external connectivity and high availability.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Router Name | Text | Yes | Unique name for the router |
| Description | Text | No | Human-readable description |
| Admin State | Toggle | Yes | Enable/disable router (default: up) |
| External Network | Select | No | External network for gateway |
| Enable SNAT | Toggle | Yes | Enable source NAT (default: true) |
| High Availability | Toggle | No | Enable HA mode (admin only) |
| Distributed | Toggle | No | Enable DVR mode (admin only) |
| Availability Zones | Multi-Select | No | AZ hints for placement |

### Batch Operations

The Routers module supports efficient batch operations for managing multiple routers.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple routers with confirmation
- **Bulk Admin State**: Enable/disable multiple routers
- **Bulk Gateway Clear**: Remove external gateways from multiple routers

## API Endpoints

### Primary Endpoints

- `GET /routers` - List all routers with details
- `GET /routers/{id}` - Get detailed router information
- `POST /routers` - Create new router
- `PUT /routers/{id}` - Update router configuration
- `DELETE /routers/{id}` - Delete router
- `PUT /routers/{id}/add_router_interface` - Add subnet interface
- `PUT /routers/{id}/remove_router_interface` - Remove subnet interface

### Secondary Endpoints

- `PUT /routers/{id}/add_extraroutes` - Add static routes
- `PUT /routers/{id}/remove_extraroutes` - Remove static routes
- `GET /ports?device_id={router-id}` - List router ports
- `GET /floatingips?router_id={id}` - List associated floating IPs

## Configuration

### Module Settings

```swift
// RoutersModule Configuration
let routersConfig = RoutersModuleConfig(
    identifier: "routers",
    displayName: "Routers (Neutron)",
    version: "1.0.0",
    dependencies: ["networks"],
    refreshInterval: 60.0,  // 60 seconds
    maxBulkOperations: 25,  // Maximum routers for batch operations
    enableHealthChecks: true,
    defaultEnableSNAT: true,
    supportHA: true,
    supportDVR: true
)
```

### Environment Variables

- `NEUTRON_ENDPOINT` - Neutron service endpoint URL (Default: from service catalog)
- `ROUTERS_REFRESH_INTERVAL` - Refresh interval in seconds (Default: `60`)
- `MAX_BULK_ROUTERS` - Maximum routers for batch operations (Default: `25`)
- `ENABLE_HA_BY_DEFAULT` - Enable HA for new routers (Default: `false`)

### Performance Tuning

- **Virtual Scrolling**: Handles lists of 500+ routers efficiently
- **Lazy Loading**: Router interfaces loaded on-demand
- **Batch Fetching**: Fetches routers in batches of 50
- **Cache TTL**: 60-second cache with manual refresh
- **Interface Caching**: Router interfaces cached separately

## Views

### Registered View Modes

#### Routers List (`.routers`)

**Purpose:** Display all routers with gateway and status information

**Key Features:**

- Virtual scrolling for large datasets
- External gateway indicators
- HA status display
- Interface count badges
- Quick action buttons

**Navigation:**

- **Enter from:** Main menu or Networks module
- **Exit to:** Router detail, create form, or main menu

#### Router Detail (`.routerDetail`)

**Purpose:** Display comprehensive router configuration and interfaces

**Key Features:**

- Full router configuration
- Interface list with subnet details
- Static routes display
- External gateway information
- HA/DVR status indicators

**Navigation:**

- **Enter from:** Routers list
- **Exit to:** Routers list or interface management

#### Router Create (`.routerCreate`)

**Purpose:** Wizard for creating new routers

**Key Features:**

- External network selection
- SNAT configuration
- HA/DVR options (admin)
- Field validation
- Preview before creation

**Navigation:**

- **Enter from:** Routers list via 'c' key
- **Exit to:** Routers list after creation

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
| `c` | Create Router | List | Open router creation form |
| `d` | Delete Router | List | Delete selected router |
| `E` | External Gateway | List/Detail | Set or clear external gateway |
| `I` | Interface Management | List/Detail | Manage subnet interfaces |
| `S` | Toggle SNAT | Detail | Enable/disable SNAT |
| `A` | Admin State | List/Detail | Toggle admin state up/down |
| `m` | Multi-Select | List | Toggle multi-select mode |
| `M` | Select All | List | Select all visible routers |
| `R` | Static Routes | Detail | Manage static routes |

## Data Provider

**Provider Class:** `RoutersDataProvider`

### Caching Strategy

The RoutersDataProvider implements intelligent caching for router data and interface information. Router lists are cached for 60 seconds with automatic invalidation on modifications. Interface data is cached separately with shorter TTL.

### Refresh Patterns

- **Periodic Refresh**: Automatic refresh every 60 seconds
- **On-Demand Refresh**: Manual refresh with 'r' key
- **Interface Updates**: Refreshes when interfaces change
- **HA State Monitoring**: Increased refresh during HA failover

### Performance Optimizations

- **Virtual Scrolling**: Renders only visible routers
- **Lazy Interface Loading**: Interfaces loaded on-demand
- **Batch API Calls**: Groups multiple router fetches
- **Route Caching**: Static routes cached separately
- **Floating IP Association**: Efficient floating IP lookups

## Known Limitations

### Current Constraints

- **L3 Agent Management**: Cannot view or manage L3 agent assignments
- **ECMP Routes**: Equal-cost multi-path routing not configurable
- **BGP Speaker**: BGP dynamic routing not integrated
- **VPN Services**: IPSec/VPN configuration not available
- **QoS Policies**: Cannot apply QoS to router interfaces
- **FWaaS Integration**: Firewall-as-a-Service not exposed

### Planned Improvements

- Add L3 agent failover management
- Implement ECMP route configuration
- Add BGP speaker integration
- Support VPN service configuration
- Enable QoS policy application
- Integrate FWaaS v2 management
- Add router performance metrics
- Implement route table visualization

## Examples

### Common Usage Scenarios

#### Creating a Router with External Gateway

```
1. Press 'c' in routers list
2. Enter router name (e.g., "main-router")
3. Select external network (e.g., "public")
4. Keep SNAT enabled for NAT
5. Enable HA if required
6. Press Enter to create
7. Attach internal subnets via interface management
```

#### Attaching Subnet to Router

```
1. Select router in list view
2. Press 'I' for interface management
3. Select subnet to attach
4. Optionally specify interface IP
5. Press Enter to attach
6. Verify in router detail view
```

#### Configuring Static Routes

```
1. Enter router detail view
2. Press 'R' for static routes
3. Add destination CIDR (e.g., "192.168.0.0/24")
4. Add nexthop IP (e.g., "10.0.0.100")
5. Save route configuration
```

### Code Examples

#### Programmatic Access

```swift
// Access routers through the module
let routersModule = tui.moduleRegistry.module(for: "routers") as? RoutersModule
let routers = routersModule?.routers ?? []

// Filter routers with external gateway
let gatewayRouters = routers.filter { $0.externalGatewayInfo != nil }

// Get router by name
let mainRouter = routers.first { $0.name == "main-router" }
```

#### Custom Integration

```swift
// Create HA router with interfaces
extension RoutersModule {
    func createHARouter(
        name: String,
        externalNetwork: String,
        subnets: [String]
    ) async throws {
        guard let tui = tui else { return }

        // Create router
        let router = Router(
            name: name,
            externalGatewayInfo: ExternalGatewayInfo(
                networkId: externalNetwork,
                enableSNAT: true
            ),
            ha: true,
            adminStateUp: true
        )

        let created = try await tui.client.createRouter(router)

        // Attach interfaces
        for subnetId in subnets {
            try await tui.client.addRouterInterface(
                routerId: created.id,
                subnetId: subnetId
            )
        }

        await tui.dataManager.refreshRouters()
    }
}
```

## Troubleshooting

### Common Issues

#### Router Creation Fails

**Symptoms:** Router creation returns permission error
**Cause:** Insufficient quota or missing permissions
**Solution:** Check router quota, verify tenant permissions

#### Cannot Set External Gateway

**Symptoms:** External network not available for selection
**Cause:** Network not marked as external or no permission
**Solution:** Verify network is external, check RBAC policies

#### Interface Attachment Fails

**Symptoms:** Cannot attach subnet to router
**Cause:** Subnet already attached or IP conflict
**Solution:** Check existing attachments, verify IP availability

#### HA Router Not Failing Over

**Symptoms:** HA router stays on failed node
**Cause:** L3 agent issues or VRRP misconfiguration
**Solution:** Check L3 agent status, verify VRRP keepalived

### Debug Commands

- `openstack router show --debug {router-id}` - Detailed router information
- `openstack port list --router {router-id}` - List router ports
- `neutron l3-agent-list-hosting-router {router-id}` - Show L3 agents
- `ip netns exec qrouter-{router-id} ip route` - View router routes (on node)

## Related Documentation

- [Module Catalog](./index.md)
- [Networks Module](./networks.md)
- [Subnets Module](./subnets.md)
- [Floating IPs Module](./floatingips.md)
- [OpenStack Neutron Documentation](https://docs.openstack.org/neutron/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `routers` |
| **Display Name** | Routers (Neutron) |
| **Version** | 1.0.0 |
| **Service** | OpenStack Neutron |
| **Category** | Networking |
| **Deletion Priority** | 3 (Medium) |
| **Load Order** | 22 |
| **Typical Memory Usage** | 5-15 MB |
| **CPU Impact** | Low |

---

*Last Updated: November 2024*
*Documentation Version: 1.0*
