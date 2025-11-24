# Security Groups Module

## Overview

**Service:** OpenStack Neutron
**Identifier:** `securitygroups`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/SecurityGroups/`

The Security Groups module provides comprehensive management of network security rules that act as virtual firewalls for servers. It enables creation and management of security groups and their rules, controlling ingress and egress traffic based on protocols, ports, and IP ranges.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Detailed list with rule counts |
| **Detail View** | Yes | Full security group with all rules |
| **Create/Edit** | Yes | Create groups and manage rules |
| **Batch Operations** | Yes | Bulk delete operations |
| **Multi-Select** | Yes | Select multiple security groups |
| **Search/Filter** | Yes | Filter by name, description |
| **Auto-Refresh** | Yes | 30 second refresh interval |
| **Health Monitoring** | Yes | Module health checks |

## Dependencies

### Required Modules

None - Security Groups is an independent module

### Optional Modules

- **Servers** - For viewing/managing server attachments
- **Ports** - For port security group assignments

## Features

### Resource Management

- **Security Group Creation**: Create groups with name and description
- **Rule Management**: Add, edit, and delete security rules
- **Server Attachment**: Attach/detach groups to servers
- **Rule Analysis**: View all rules with direction, protocol, port ranges
- **Remote Group References**: Rules referencing other security groups

### List Operations

The list view displays all security groups with rule counts and descriptions.

**Available Actions:**

- `c` - Create new security group
- `d` - Delete selected security group
- `M` - Manage security group rules
- `r` - Refresh list
- `Space` - Toggle multi-select

### Detail View

Comprehensive view showing security group with all rules:

- **Basic Info**: Name, ID, description, tenant
- **Rules Table**: All rules with direction, protocol, ports, remote
- **Ingress Rules**: Incoming traffic rules
- **Egress Rules**: Outgoing traffic rules

### Create/Edit Operations

Forms for creating security groups and managing rules.

**Security Group Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Security group name |
| Description | Text | No | Optional description |

**Rule Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Direction | Selector | Yes | ingress or egress |
| Ether Type | Selector | Yes | IPv4 or IPv6 |
| Protocol | Selector | No | TCP, UDP, ICMP, or any |
| Port Range Min | Number | No | Start of port range |
| Port Range Max | Number | No | End of port range |
| Remote IP Prefix | Text | No | CIDR for remote IP |
| Remote Group | Selector | No | Reference another security group |

### Batch Operations

Support for bulk operations on multiple security groups.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple security groups at once

## API Endpoints

### Primary Endpoints

- `GET /v2.0/security-groups` - List all security groups
- `POST /v2.0/security-groups` - Create a new security group
- `GET /v2.0/security-groups/{id}` - Get security group details
- `PUT /v2.0/security-groups/{id}` - Update security group
- `DELETE /v2.0/security-groups/{id}` - Delete security group

### Secondary Endpoints

- `POST /v2.0/security-group-rules` - Create a rule
- `DELETE /v2.0/security-group-rules/{id}` - Delete a rule

## Configuration

### Module Settings

```swift
let module = SecurityGroupsModule(tui: tui)
// Module auto-configures with TUI context
// Registers with BatchOperationRegistry, ActionProviderRegistry, ViewRegistry
```

### Performance Tuning

- **Refresh Interval**: 30 seconds default
- **Cache Strategy**: Central cache manager

## Views

### Registered View Modes

#### Security Groups List (`securityGroups`)

**Purpose:** Browse all security groups

**Key Features:**

- Rule count display
- Description preview
- Multi-select support

**Navigation:**

- **Enter from:** Main menu
- **Exit to:** Main menu, Detail view

#### Security Group Detail (`securityGroupDetail`)

**Purpose:** View security group with all rules

**Key Features:**

- Complete rule table
- Direction and protocol display
- Port range information
- Remote IP/group references

**Navigation:**

- **Enter from:** List view (Enter)
- **Exit to:** List view (Esc)

#### Create Security Group (`securityGroupCreate`)

**Purpose:** Create new security group

**Key Features:**

- Name input
- Description field

**Navigation:**

- **Enter from:** List view (c)
- **Exit to:** List view (Esc/Submit)

#### Rule Management (`securityGroupRuleManagement`)

**Purpose:** Add/edit/delete rules

**Key Features:**

- Rule list with selection
- Create rule form
- Edit existing rules
- Delete rules

**Navigation:**

- **Enter from:** List view (M)
- **Exit to:** List view (Esc)

#### Server Attachment (`securityGroupServerAttachment`)

**Purpose:** Attach security group to servers

**Key Features:**

- Server multi-select
- Current attachments display

**Navigation:**

- **Enter from:** Actions menu
- **Exit to:** List view

#### Server Management (`securityGroupServerManagement`)

**Purpose:** Manage which servers use this group

**Key Features:**

- View all attached servers
- Add/remove servers

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
| `c` | Create | List | Create new security group |
| `d` | Delete | List | Delete selected security group |
| `M` | Manage | List | Manage security group rules |
| `Space` | Toggle Select | List | Multi-select mode |

## Data Provider

**Provider Class:** `SecurityGroupsDataProvider`

### Caching Strategy

Uses central cache manager with security group storage.

### Refresh Patterns

- **Periodic**: Auto-refresh every 30 seconds
- **On-demand**: Manual refresh with 'r' key
- **Post-operation**: Refresh after create/delete/rule changes

### Performance Optimizations

- **Inline Rules**: Rules embedded in security group response
- **Reference Caching**: Caches remote group references

## Known Limitations

### Current Constraints

- **No Stateful Rules**: All rules are stateful (return traffic auto-allowed)
- **No Custom Protocols**: Limited to TCP, UDP, ICMP, and any
- **Default Group**: Cannot delete default security group

### Planned Improvements

- Rule import/export
- Template security groups
- Rule conflict detection

## Examples

### Common Usage Scenarios

#### Create Web Server Security Group

```
1. Navigate to Security Groups
2. Press 'c' to create
3. Name: "web-servers"
4. Description: "Allow HTTP/HTTPS traffic"
5. Submit to create
6. Select the new group
7. Press 'M' to manage rules
8. Add rule: ingress, TCP, port 80
9. Add rule: ingress, TCP, port 443
10. Exit rule management
```

#### Allow SSH from Specific Network

```
1. Navigate to Security Groups
2. Select target security group
3. Press 'M' to manage rules
4. Create new rule:
   - Direction: ingress
   - Protocol: TCP
   - Port: 22
   - Remote IP Prefix: 10.0.0.0/8
5. Submit rule
```

#### Reference Another Security Group

```
1. Navigate to Security Groups
2. Select target security group
3. Press 'M' to manage rules
4. Create new rule:
   - Direction: ingress
   - Protocol: TCP
   - Port: 3306
   - Remote Group: "app-servers"
5. Submit rule
(This allows MySQL from any server in app-servers group)
```

## Troubleshooting

### Common Issues

#### Cannot Delete Security Group

**Symptoms:** Delete fails with "in use" error
**Cause:** Security group is attached to ports
**Solution:** Remove security group from all servers/ports first

#### Rules Not Taking Effect

**Symptoms:** Traffic still blocked after adding rule
**Cause:** Rule may be too restrictive or wrong direction
**Solution:** Verify direction (ingress for incoming), protocol, and port range

#### Cannot Connect Between Instances

**Symptoms:** Instances in same network cannot communicate
**Cause:** Missing egress or remote group rules
**Solution:** Add rules allowing traffic between security groups

#### Default Security Group Too Restrictive

**Symptoms:** New instances cannot be reached
**Cause:** Default group only allows egress by default
**Solution:** Add ingress rules or use custom security group

## Related Documentation

- [Module Catalog](./index.md)
- [Servers](./servers.md)
- [Ports](./ports.md)
- [Networks](./networks.md)
- [OpenStack Neutron Security Groups](https://docs.openstack.org/neutron/latest/admin/archives/adv-features.html)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `securitygroups` |
| **Display Name** | Security Groups |
| **Version** | 1.0.0 |
| **Service** | Neutron |
| **Category** | Network |
| **Deletion Priority** | Low (check attachments first) |
| **Load Order** | Phase 1 (independent) |

---

*Last Updated: 2024*
*Documentation Version: 1.0.0*
