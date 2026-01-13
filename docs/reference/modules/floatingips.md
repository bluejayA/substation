# Floating IPs Module

## Overview

**Service:** OpenStack Neutron
**Identifier:** `floatingips`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/FloatingIPs/`

The Floating IPs module provides comprehensive management of external IP addresses that can be associated with servers for public network access. It enables allocation from external networks, association with servers or ports, and lifecycle management of floating IP resources.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Detailed list with status, IP, server associations |
| **Detail View** | Yes | Full floating IP attributes and associations |
| **Create/Edit** | Yes | Allocate from external networks |
| **Batch Operations** | Yes | Bulk delete operations |
| **Multi-Select** | Yes | Select multiple floating IPs for batch ops |
| **Search/Filter** | Yes | Filter by IP address, server name |
| **Auto-Refresh** | Yes | 30 second refresh interval |
| **Health Monitoring** | Yes | Module health checks with metrics |

## Dependencies

### Required Modules

- **Networks** - Required for accessing external networks for allocation

### Optional Modules

- **Servers** - For server association management
- **Ports** - For direct port association

## Features

### Resource Management

- **Allocation**: Allocate floating IPs from external networks
- **Association**: Associate with servers or ports for external access
- **Disassociation**: Remove associations while keeping the IP allocated
- **Release**: Return floating IPs to the pool

### List Operations

The list view displays all floating IPs with their allocation status, associated server names, fixed IP mappings, and network information.

**Available Actions:**

- `c` - Create new floating IP
- `d` - Delete selected floating IP
- `M` - Manage server assignment
- `P` - Manage port assignment
- `r` - Refresh list
- `Space` - Toggle multi-select

### Detail View

Comprehensive view showing all floating IP attributes including:

- **Basic Info**: Floating IP address, ID, tenant
- **Association**: Associated server, port, fixed IP
- **Network**: External network, router information
- **Status**: Current allocation and association status

### Create/Edit Operations

Form for allocating new floating IPs with network selection.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Network | Selector | Yes | External network to allocate from |
| Subnet | Selector | No | Specific subnet within network |
| Description | Text | No | Optional description |

### Batch Operations

Support for bulk operations on multiple floating IPs.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple floating IPs at once

## API Endpoints

### Primary Endpoints

- `GET /v2.0/floatingips` - List all floating IPs
- `POST /v2.0/floatingips` - Allocate a new floating IP
- `GET /v2.0/floatingips/{id}` - Get floating IP details
- `PUT /v2.0/floatingips/{id}` - Update floating IP (association)
- `DELETE /v2.0/floatingips/{id}` - Release floating IP

## Configuration

### Module Settings

```swift
let module = FloatingIPsModule(tui: tui)
// Module auto-configures with TUI context
// Registers with BatchOperationRegistry, ActionProviderRegistry, ViewRegistry
```

### Performance Tuning

- **Refresh Interval**: 30 seconds default
- **Cache Strategy**: Leverages central cache manager

## Views

### Registered View Modes

#### Floating IPs List (`floatingIPs`)

**Purpose:** Browse all allocated floating IPs

**Key Features:**

- Status-colored IP addresses
- Server name associations
- Network information
- Multi-select support

**Navigation:**

- **Enter from:** Main menu, Networks
- **Exit to:** Main menu, Detail view

#### Floating IP Detail (`floatingIPDetail`)

**Purpose:** View complete floating IP information

**Key Features:**

- Full attribute display
- Association details
- Router information

**Navigation:**

- **Enter from:** List view (Enter)
- **Exit to:** List view (Esc)

#### Create Floating IP (`floatingIPCreate`)

**Purpose:** Allocate new floating IP

**Key Features:**

- External network selection
- Subnet filtering
- Description field

**Navigation:**

- **Enter from:** List view (c)
- **Exit to:** List view (Esc/Submit)

#### Server Management (`floatingIPServerManagement`)

**Purpose:** Associate/disassociate with servers

**Key Features:**

- Server selector
- Current association display
- Quick disassociate option

**Navigation:**

- **Enter from:** List view (M)
- **Exit to:** List view

#### Port Management (`floatingIPPortManagement`)

**Purpose:** Direct port association

**Key Features:**

- Port selector
- Network-aware filtering

**Navigation:**

- **Enter from:** List view (P)
- **Exit to:** List view

#### Server Select (`floatingIPServerSelect`)

**Purpose:** Select a server to associate with a floating IP

**Key Features:**

- Server list with filtering
- Instance status display
- Network interface selection
- Quick search capability

**Navigation:**

- **Enter from:** Floating IP list or detail view
- **Exit to:** Floating IP list

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
| `c` | Create | List | Allocate new floating IP |
| `d` | Delete | List | Delete selected floating IP |
| `M` | Manage Server | List | Manage server association |
| `P` | Manage Port | List | Manage port association |
| `Space` | Toggle Select | List | Multi-select mode |

## Data Provider

**Provider Class:** `FloatingIPsDataProvider`

### Caching Strategy

Uses central cache manager for floating IP storage with automatic refresh on data changes.

### Refresh Patterns

- **Periodic**: Auto-refresh every 30 seconds
- **On-demand**: Manual refresh with 'r' key
- **Post-operation**: Refresh after create/delete/associate operations

### Performance Optimizations

- **Lazy Loading**: Loads server/port names on demand
- **Filtered Queries**: Only fetches external networks for allocation

## Known Limitations

### Current Constraints

- **Single Association**: A floating IP can only be associated with one server/port at a time
- **External Networks Only**: Can only allocate from networks marked as external
- **No DNS**: Floating IP DNS names not supported in this module

### Planned Improvements

- Port forwardings support
- DNS integration
- Quota display

## Examples

### Common Usage Scenarios

#### Allocate and Associate Floating IP

```
1. Navigate to Floating IPs from main menu
2. Press 'c' to create new floating IP
3. Select external network
4. Submit form to allocate
5. Select the new floating IP
6. Press 'M' to manage server
7. Select target server
8. Submit to associate
```

#### Disassociate Floating IP

```
1. Navigate to Floating IPs
2. Select floating IP to disassociate
3. Press 'M' for server management
4. Select "None" or disassociate option
5. Confirm disassociation
```

#### Bulk Delete Floating IPs

```
1. Navigate to Floating IPs
2. Press Space to enter multi-select mode
3. Select multiple floating IPs
4. Press 'd' for bulk delete
5. Confirm deletion
```

## Troubleshooting

### Common Issues

#### No External Networks Available

**Symptoms:** Cannot create floating IP, no networks in selector
**Cause:** No networks marked as external in the project
**Solution:** Contact admin to configure external network access

#### Association Fails

**Symptoms:** Error when associating with server
**Cause:** Server may not have a port on a network with router to external
**Solution:** Ensure server has network connectivity through router to external network

#### Floating IP Not Accessible

**Symptoms:** Cannot reach server via floating IP
**Cause:** Security group rules may block traffic
**Solution:** Check security group allows ingress on required ports

## Related Documentation

- [Module Catalog](./index.md)
- [Networks](./networks.md)
- [Servers](./servers.md)
- [Ports](./ports.md)
- [OpenStack Neutron Documentation](https://docs.openstack.org/neutron/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `floatingips` |
| **Display Name** | Floating IPs |
| **Version** | 1.0.0 |
| **Service** | Neutron |
| **Category** | Network |
| **Deletion Priority** | Medium |
| **Load Order** | Phase 2 (network-dependent) |

---

*Last Updated: January 2025*
*Documentation Version: 1.1.0*
