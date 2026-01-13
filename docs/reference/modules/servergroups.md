# Server Groups Module

## Overview

**Service:** OpenStack Nova
**Identifier:** `servergroups`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/ServerGroups/`

The Server Groups module manages Nova server group scheduling policies for high availability and performance optimization. Server groups control the placement of instances on physical compute hosts through affinity and anti-affinity policies, ensuring instances are either co-located or distributed across hosts.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | List with policy and member count |
| **Detail View** | Yes | Full group info with member servers |
| **Create/Edit** | Yes | Create with policy selection |
| **Batch Operations** | Yes | Bulk delete operations |
| **Multi-Select** | Yes | Select multiple server groups |
| **Search/Filter** | Yes | Filter by name, policy |
| **Auto-Refresh** | Yes | 30 second refresh interval |
| **Health Monitoring** | Yes | Module health checks |

## Dependencies

### Required Modules

None - Server Groups is an independent module

### Optional Modules

- **Servers** - For viewing member servers in detail view

## Features

### Resource Management

- **Group Creation**: Create groups with scheduling policies
- **Policy Types**: Affinity, anti-affinity, soft variants
- **Member Tracking**: View which servers belong to each group
- **Scheduling Control**: Control instance placement across hosts

### List Operations

The list view displays all server groups with their policies and member counts.

**Available Actions:**

- `c` - Create new server group
- `d` - Delete selected server group
- `r` - Refresh list
- `Space` - Toggle multi-select

### Detail View

Comprehensive view showing server group with members:

- **Basic Info**: Name, ID, policy
- **Policies**: List of scheduling policies
- **Members**: Server IDs belonging to this group
- **Member Details**: Server names (from cache)

### Create/Edit Operations

Form for creating server groups with policy selection.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Server group name |
| Policy | Selector | Yes | Scheduling policy |

**Available Policies:**

- **affinity**: Place instances on same host
- **anti-affinity**: Place instances on different hosts
- **soft-affinity**: Prefer same host (best effort)
- **soft-anti-affinity**: Prefer different hosts (best effort)

### Batch Operations

Support for bulk operations on multiple server groups.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple server groups at once

## API Endpoints

### Primary Endpoints

- `GET /v2.1/os-server-groups` - List all server groups
- `POST /v2.1/os-server-groups` - Create a new server group
- `GET /v2.1/os-server-groups/{id}` - Get server group details
- `DELETE /v2.1/os-server-groups/{id}` - Delete server group

## Configuration

### Module Settings

```swift
let module = ServerGroupsModule(tui: tui)
// Module auto-configures with TUI context
// Registers with BatchOperationRegistry, ActionProviderRegistry, ViewRegistry
```

### Performance Tuning

- **Refresh Interval**: 30 seconds default
- **Cache Strategy**: Central cache manager

## Views

### Registered View Modes

#### Server Groups List (`serverGroups`)

**Purpose:** Browse all server groups

**Key Features:**

- Policy display
- Member count
- Multi-select support

**Navigation:**

- **Enter from:** Main menu
- **Exit to:** Main menu, Detail view

#### Server Group Detail (`serverGroupDetail`)

**Purpose:** View server group with members

**Key Features:**

- Full policy list
- Member server IDs
- Server name resolution from cache

**Navigation:**

- **Enter from:** List view (Enter)
- **Exit to:** List view (Esc)

#### Create Server Group (`serverGroupCreate`)

**Purpose:** Create new server group

**Key Features:**

- Name input
- Policy selector

**Navigation:**

- **Enter from:** List view (c)
- **Exit to:** List view (Esc/Submit)

#### Server Group Management (`serverGroupManagement`)

**Purpose:** Manage server group settings

**Key Features:**

- View current configuration
- Member management

**Navigation:**

- **Enter from:** Detail view actions
- **Exit to:** Detail view

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
| `c` | Create | List | Create new server group |
| `d` | Delete | List | Delete selected server group |
| `Space` | Toggle Select | List | Multi-select mode |

## Data Provider

**Provider Class:** `ServerGroupsDataProvider`

### Caching Strategy

Uses central cache manager with server group storage.

### Refresh Patterns

- **Periodic**: Auto-refresh every 30 seconds
- **On-demand**: Manual refresh with 'r' key
- **Post-operation**: Refresh after create/delete operations

### Performance Optimizations

- **Member Resolution**: Resolves member server names from server cache
- **Efficient Queries**: Minimal API calls for list operations

## Known Limitations

### Current Constraints

- **Immutable Policy**: Cannot change policy after creation
- **No Member Addition**: Members added only during server creation
- **Quota Limits**: Subject to server group quotas

### Planned Improvements

- Policy visualization
- Member statistics
- Placement recommendations

## Examples

### Common Usage Scenarios

#### Create High Availability Group

```
1. Navigate to Server Groups
2. Press 'c' to create
3. Name: "web-ha-group"
4. Policy: anti-affinity
5. Submit to create
(Servers in this group will be on different hosts)
```

#### Create Performance Group

```
1. Navigate to Server Groups
2. Press 'c' to create
3. Name: "cache-cluster"
4. Policy: affinity
5. Submit to create
(Servers in this group will be on same host for low latency)
```

#### Use Server Group When Creating Server

```
1. Create server group with desired policy
2. Navigate to Servers
3. Press 'c' to create server
4. In scheduler hints, select server group
5. Submit to create
(Server will be scheduled according to group policy)
```

#### Check Group Members

```
1. Navigate to Server Groups
2. Select target group
3. Press Enter to view details
4. View Members section for server IDs
5. Cross-reference with Servers module
```

## Troubleshooting

### Common Issues

#### Cannot Schedule with Anti-Affinity

**Symptoms:** Server creation fails with NoValidHost
**Cause:** Not enough distinct hosts for anti-affinity requirement
**Solution:** Use soft-anti-affinity or add more compute hosts

#### Cannot Schedule with Affinity

**Symptoms:** Server creation fails with NoValidHost
**Cause:** Target host does not have enough resources
**Solution:** Use soft-affinity or scale up the host

#### Server Not Added to Group

**Symptoms:** Created server not appearing in group members
**Cause:** Server group not specified during server creation
**Solution:** Server group must be specified as scheduler hint at creation time

#### Cannot Delete Server Group

**Symptoms:** Delete fails
**Cause:** Server group still has member servers
**Solution:** Delete all member servers first, then delete group

## Related Documentation

- [Module Catalog](./index.md)
- [Servers](./servers.md)
- [Flavors](./flavors.md)
- [OpenStack Nova Server Groups](https://docs.openstack.org/nova/latest/user/server-groups.html)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `servergroups` |
| **Display Name** | Server Groups |
| **Version** | 1.0.0 |
| **Service** | Nova |
| **Category** | Compute |
| **Deletion Priority** | Low (delete members first) |
| **Load Order** | Phase 1 (independent) |
