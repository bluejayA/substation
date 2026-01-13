# Ports Module

## Overview

**Service:** OpenStack Neutron
**Identifier:** `ports`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Ports/`

The Ports module provides comprehensive management of Neutron ports - the virtual network interfaces that connect instances, routers, and other network devices to networks. It offers deep visibility into port bindings, fixed IPs, security configurations, and device attachments critical for network troubleshooting.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Detailed list with status, network, device info |
| **Detail View** | Yes | Full port attributes including bindings |
| **Create/Edit** | Yes | Create ports with network and security config |
| **Batch Operations** | Yes | Bulk delete operations |
| **Multi-Select** | Yes | Select multiple ports for batch ops |
| **Search/Filter** | Yes | Filter by name, MAC, IP, device |
| **Auto-Refresh** | Yes | 60 second refresh interval |
| **Health Monitoring** | Yes | Comprehensive health metrics |

## Dependencies

### Required Modules

- **Networks** - Required for network selection during port creation

### Optional Modules

- **Subnets** - For fixed IP subnet information
- **SecurityGroups** - For security group assignments
- **Servers** - For device attachment information

## Features

### Resource Management

- **Port Creation**: Create ports with network, security, and QoS configuration
- **Binding Information**: View host bindings, VNIC types, VIF details
- **Fixed IPs**: Manage IP address assignments with subnet associations
- **Security Configuration**: Port security and security group assignments
- **Allowed Address Pairs**: Configure for VRRP and similar protocols
- **Device Tracking**: Monitor compute, router, DHCP device attachments

### List Operations

The list view displays all ports with status indicators, network associations, device owners, and IP information.

**Available Actions:**

- `c` - Create new port
- `d` - Delete selected port
- `M` - Manage server assignment
- `E` - Manage allowed address pairs
- `r` - Refresh list
- `Space` - Toggle multi-select

### Detail View

Comprehensive view showing all port attributes including:

- **Basic Info**: Name, ID, MAC address, status
- **Network**: Network ID, subnet associations
- **Binding**: Host ID, VNIC type, VIF type, profile
- **Fixed IPs**: All assigned IP addresses with subnets
- **Security**: Port security enabled, security groups
- **Device**: Device ID, owner, QoS policy
- **Allowed Address Pairs**: Additional allowed MACs/IPs

### Create/Edit Operations

Form for creating new ports with comprehensive configuration options.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | No | Port display name |
| Network | Selector | Yes | Network to attach port to |
| MAC Address | Text | No | Custom MAC (auto-generated if empty) |
| Security Groups | Multi-select | No | Security groups to apply |
| Port Security | Toggle | No | Enable/disable port security |
| QoS Policy | Selector | No | Quality of service policy |

### Batch Operations

Support for bulk operations on multiple ports.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple ports at once

## API Endpoints

### Primary Endpoints

- `GET /v2.0/ports` - List all ports
- `POST /v2.0/ports` - Create a new port
- `GET /v2.0/ports/{id}` - Get port details
- `PUT /v2.0/ports/{id}` - Update port
- `DELETE /v2.0/ports/{id}` - Delete port

## Configuration

### Module Settings

```swift
let module = PortsModule(tui: tui)
// Module auto-configures with TUI context
// Registers with BatchOperationRegistry, ActionProviderRegistry, ViewRegistry
```

### Performance Tuning

- **Refresh Interval**: 60 seconds default
- **Cache Strategy**: Central cache with port statistics tracking

## Views

### Registered View Modes

#### Ports List (`ports`)

**Purpose:** Browse all Neutron ports

**Key Features:**

- Status-colored indicators (ACTIVE, DOWN, BUILD, ERROR)
- Network and device owner display
- MAC address and fixed IP information
- Multi-select support

**Navigation:**

- **Enter from:** Main menu, Networks
- **Exit to:** Main menu, Detail view

#### Port Detail (`portDetail`)

**Purpose:** View complete port information

**Key Features:**

- Full binding attributes
- Fixed IP list with subnet names
- Security group details
- Allowed address pairs

**Navigation:**

- **Enter from:** List view (Enter)
- **Exit to:** List view (Esc)

#### Create Port (`portCreate`)

**Purpose:** Create new network port

**Key Features:**

- Network selector
- Security group multi-select
- MAC address configuration
- QoS policy assignment

**Navigation:**

- **Enter from:** List view (c)
- **Exit to:** List view (Esc/Submit)

#### Server Management (`portServerManagement`)

**Purpose:** Attach/detach port to server

**Key Features:**

- Server selector
- Current attachment display

**Navigation:**

- **Enter from:** List view (M)
- **Exit to:** List view

#### Allowed Address Pairs (`portAllowedAddressPairManagement`)

**Purpose:** Configure allowed address pairs

**Key Features:**

- Add/remove address pairs
- MAC and IP configuration

**Navigation:**

- **Enter from:** List view (E)
- **Exit to:** List view

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
| `c` | Create | List | Create new port |
| `d` | Delete | List | Delete selected port |
| `M` | Manage Server | List | Manage server attachment |
| `E` | Edit Pairs | List | Manage allowed address pairs |
| `Space` | Toggle Select | List | Multi-select mode |

## Data Provider

**Provider Class:** `PortsDataProvider`

### Caching Strategy

Uses central cache manager with comprehensive port statistics tracking for health monitoring.

### Refresh Patterns

- **Periodic**: Auto-refresh every 60 seconds
- **On-demand**: Manual refresh with 'r' key
- **Post-operation**: Refresh after create/delete operations

### Performance Optimizations

- **Port Statistics**: Tracks active/down/bound counts
- **Device Distribution**: Monitors device owner types
- **VNIC Distribution**: Tracks VNIC type usage

## Known Limitations

### Current Constraints

- **No Trunk Ports**: Trunk port management not yet implemented
- **No Port Forwarding**: Port forwarding rules managed separately
- **Binding Profiles**: Cannot edit binding profiles directly

### Planned Improvements

- Trunk port support
- Port forwarding management
- Binding profile editing

## Examples

### Common Usage Scenarios

#### Create Port for Server

```
1. Navigate to Ports from main menu
2. Press 'c' to create new port
3. Select target network
4. Configure security groups
5. Submit form
6. Use port ID when creating server
```

#### Diagnose Port Connectivity

```
1. Navigate to Ports
2. Search for port by server name or IP
3. Press Enter to view details
4. Check:
   - Status is ACTIVE
   - Binding host is set
   - Fixed IPs assigned
   - Security groups configured
```

#### Configure VRRP with Allowed Address Pairs

```
1. Navigate to Ports
2. Select port for VRRP
3. Press 'E' for allowed address pairs
4. Add virtual IP address
5. Add virtual MAC (if needed)
6. Submit changes
```

## Troubleshooting

### Common Issues

#### Port Status DOWN

**Symptoms:** Port shows DOWN status
**Cause:** No device attached or device is powered off
**Solution:** Attach port to running instance or check device status

#### Port Not Binding

**Symptoms:** Port created but no binding_host_id
**Cause:** Scheduler cannot find suitable host
**Solution:** Check host availability and network agent status

#### Security Group Changes Not Applied

**Symptoms:** Traffic still blocked after security group update
**Cause:** Security group rules may need time to propagate
**Solution:** Wait for agent sync or restart neutron-openvswitch-agent

#### MAC Address Conflict

**Symptoms:** Port creation fails with MAC conflict
**Cause:** Custom MAC already in use
**Solution:** Use different MAC or let system auto-generate

## Related Documentation

- [Module Catalog](./index.md)
- [Networks](./networks.md)
- [Subnets](./subnets.md)
- [SecurityGroups](./securitygroups.md)
- [Servers](./servers.md)
- [OpenStack Neutron Documentation](https://docs.openstack.org/neutron/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `ports` |
| **Display Name** | Ports (Neutron) |
| **Version** | 1.0.0 |
| **Service** | Neutron |
| **Category** | Network |
| **Deletion Priority** | High (check for attachments) |
| **Load Order** | Phase 2 (network-dependent) |
