# Volumes Module

## Overview

**Service:** OpenStack Cinder (Block Storage)
**Identifier:** `volumes`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Volumes/`

The Volumes module provides comprehensive block storage management capabilities for OpenStack Cinder. It enables users to create, manage, and attach persistent block storage volumes to compute instances. The module supports advanced features including snapshots, backups, volume attachments, and archive management with a unified interface for all volume-related operations.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Volume listing with status, size, type, and attachment info |
| **Detail View** | Yes | Comprehensive volume details including metadata and attachments |
| **Create/Edit** | Yes | Volume creation with advanced options |
| **Batch Operations** | Yes | Bulk delete, bulk snapshot, bulk backup |
| **Multi-Select** | Yes | Select multiple volumes for batch operations |
| **Search/Filter** | Yes | Search by name, ID, status, or type |
| **Auto-Refresh** | Yes | 30-second interval for volumes, 60s for snapshots/backups |
| **Health Monitoring** | Yes | Service availability and cache status tracking |

## Dependencies

### Required Modules

This module has no required dependencies and can operate independently.

### Optional Modules

- **Servers** - Enhanced integration for volume attachments to compute instances
- **Images** - Support for creating bootable volumes from images

## Features

### Resource Management

- **Volume Creation**: Create volumes with custom size, type, and optional boot capabilities
- **Snapshot Management**: Create point-in-time snapshots for backup and recovery
- **Backup Management**: Create full backups to object storage for disaster recovery
- **Attachment Control**: Attach/detach volumes to/from compute instances
- **Archive Management**: Unified view of all snapshots and backups
- **Metadata Management**: Add custom metadata to volumes for organization

### List Operations

The volume list view provides a comprehensive overview of all block storage volumes in the project.

**Available Actions:**

- `Enter` - View detailed volume information
- `c` - Create new volume
- `d` - Delete selected volume(s)
- `r` - Refresh volume list
- `B` - Create backup of selected volume
- `P` - Create snapshot of selected volume
- `M` - Manage volume attachments
- `/` - Search volumes
- `Space` - Toggle multi-select mode

### Detail View

Displays comprehensive information about a selected volume including all technical details and relationships.

**Displayed Information:**

- **Basic Info**: Name, ID, status, size, type, bootable flag
- **Attachments**: Server attachments with device paths and attachment IDs
- **Metadata**: Custom key-value pairs for organization
- **Timestamps**: Created, updated dates
- **Availability**: Zone information
- **Properties**: Encryption status, multiattach capability
- **Source Info**: Created from snapshot, image, or blank

### Create/Edit Operations

Volume creation supports multiple source types and configuration options.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Volume display name |
| Description | Text | No | Volume description |
| Size (GB) | Integer | Yes | Volume size in gigabytes |
| Type | Select | No | Volume type (SSD, HDD, etc.) |
| Availability Zone | Select | No | Target availability zone |
| Source Type | Select | No | blank, image, snapshot, or volume |
| Source ID | Select | Conditional | Required if source type specified |
| Bootable | Toggle | No | Make volume bootable |

### Batch Operations

The module supports efficient batch operations for managing multiple volumes simultaneously.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple volumes at once
- **Bulk Snapshot**: Create snapshots of multiple volumes
- **Bulk Backup**: Create backups of multiple volumes
- **Bulk Detach**: Detach multiple volumes from instances

## API Endpoints

### Primary Endpoints

- `GET /v3/{project_id}/volumes` - List all volumes
- `GET /v3/{project_id}/volumes/detail` - List volumes with details
- `GET /v3/{project_id}/volumes/{volume_id}` - Get volume details
- `POST /v3/{project_id}/volumes` - Create new volume
- `DELETE /v3/{project_id}/volumes/{volume_id}` - Delete volume
- `PUT /v3/{project_id}/volumes/{volume_id}` - Update volume

### Secondary Endpoints

- `GET /v3/{project_id}/snapshots` - List volume snapshots
- `POST /v3/{project_id}/snapshots` - Create snapshot
- `GET /v3/{project_id}/backups` - List volume backups
- `POST /v3/{project_id}/backups` - Create backup
- `POST /v3/{project_id}/volumes/{volume_id}/action` - Volume actions (attach/detach)
- `GET /v3/{project_id}/types` - List volume types

## Configuration

### Module Settings

```swift
// Module initialization
let volumesModule = VolumesModule(tui: tui)

// Configuration
await volumesModule.configure()

// Health check
let health = await volumesModule.healthCheck()
```

### Performance Tuning

- **Cache TTL**: 30 seconds for volume list, 60 seconds for snapshots/backups
- **Batch Size**: Up to 50 volumes can be selected for batch operations
- **Refresh Strategy**: On-demand with automatic background refresh

## Views

### Registered View Modes

#### Volume List (`.volumes`)

**Purpose:** Display and manage all block storage volumes

**Key Features:**

- Status indicators with color coding
- Size and type information
- Attachment status
- Search and filter capabilities

**Navigation:**

- **Enter from:** Main menu, dashboard
- **Exit to:** Volume detail, create form, main menu

#### Volume Detail (`.volumeDetail`)

**Purpose:** Show comprehensive volume information

**Key Features:**

- Full metadata display
- Attachment details
- Source information
- Action history

**Navigation:**

- **Enter from:** Volume list
- **Exit to:** Volume list

#### Volume Create (`.volumeCreate`)

**Purpose:** Form for creating new volumes

**Key Features:**

- Source selection (blank, image, snapshot)
- Type selection
- Size configuration
- Bootable option

**Navigation:**

- **Enter from:** Volume list
- **Exit to:** Volume list

#### Volume Archives (`.volumeArchives`)

**Purpose:** Unified view of snapshots and backups

**Key Features:**

- Combined snapshot/backup list
- Type indicators
- Size and status display
- Delete operations

**Navigation:**

- **Enter from:** Volume list
- **Exit to:** Archive detail, volume list

#### Volume Archive Detail (`.volumeArchiveDetail`)

**Purpose:** Display detailed information about a specific volume snapshot or backup archive

**Key Features:**

- Complete archive metadata
- Size and creation date
- Restore operations
- Delete archived volume

**Navigation:**

- **Enter from:** Volume archives list
- **Exit to:** Volume archives list

#### Volume Management (`.volumeManagement`)

**Purpose:** General volume management and configuration

**Key Features:**

- Volume metadata editing
- Type changes
- QoS management
- Multi-attach configuration

**Navigation:**

- **Enter from:** Volume detail view
- **Exit to:** Volume list or detail view

#### Volume Server Management (`.volumeServerManagement`)

**Purpose:** Manage volume attachments to servers

**Key Features:**

- View current attachments
- Attach to new servers
- Detach from servers
- Mount point specification
- Multi-attachment support

**Navigation:**

- **Enter from:** Volume list via 'M' key or detail view
- **Exit to:** Volume list

#### Volume Snapshot Management (`.volumeSnapshotManagement`)

**Purpose:** Create and manage volume snapshots

**Key Features:**

- Snapshot creation with naming
- Snapshot metadata
- Progress tracking
- Snapshot to volume conversion

**Navigation:**

- **Enter from:** Volume list via 'P' key
- **Exit to:** Volume list

#### Volume Backup Management (`.volumeBackupManagement`)

**Purpose:** Create and manage volume backups

**Key Features:**

- Full and incremental backups
- Backup scheduling
- Backup metadata and description
- Restore from backup
- Progress monitoring

**Navigation:**

- **Enter from:** Volume list via 'B' key
- **Exit to:** Volume list

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
| `B` | Create Backup | Volume List | Create backup of selected volume |
| `P` | Create Snapshot | Volume List | Create snapshot of selected volume |
| `M` | Manage Attachments | Volume List | Manage server attachments |
| `c` | Create Volume | Volume List | Open volume creation form |
| `d` | Delete | Volume List/Archives | Delete selected resource |
| `Space` | Multi-Select | List Views | Toggle multi-selection mode |

## Data Provider

**Provider Class:** `VolumesDataProvider`

### Caching Strategy

The module implements a multi-tier caching strategy with different TTLs for different resource types. Volumes are cached for 30 seconds while snapshots and backups use 60-second TTLs to reduce API load.

### Refresh Patterns

- **On-Demand**: Manual refresh via 'r' key
- **Auto-Refresh**: Background refresh at configured intervals
- **Cache Invalidation**: After create/delete operations

### Performance Optimizations

- **Lazy Loading**: Details fetched only when needed
- **Batch Fetching**: Multiple resources fetched in parallel
- **Differential Updates**: Only changed items updated in cache

## Known Limitations

### Current Constraints

- **Encryption**: Volume encryption settings cannot be modified after creation
- **Type Change**: Volume type cannot be changed after creation
- **Size Reduction**: Volumes can only be extended, not shrunk
- **Multi-Attach**: Limited support for multi-attach volumes

### Planned Improvements

- Volume migration between availability zones
- Volume type conversion support
- Enhanced encryption key management
- Volume group management

## Examples

### Common Usage Scenarios

#### Creating a Bootable Volume

```
1. Press 'c' in volume list to create new volume
2. Select "image" as source type
3. Choose desired OS image
4. Set size (must be >= image min disk)
5. Enable "Bootable" toggle
6. Submit form
```

#### Creating a Volume Backup

```
1. Select volume in list view
2. Press 'B' for backup
3. Enter backup name and description
4. Choose incremental or full backup
5. Submit to create backup
```

#### Attaching Volume to Server

```
1. Select volume in list view
2. Press 'M' for manage attachments
3. Select target server
4. Choose device path (optional)
5. Confirm attachment
```

### Code Examples

#### Programmatic Access

```swift
// Get all volumes
let volumes = await tui.client.getAllVolumes()

// Create new volume
let volumeRequest = VolumeCreateRequest(
    name: "data-volume",
    size: 100,
    volumeType: "ssd"
)
let newVolume = await tui.client.createVolume(volumeRequest)
```

#### Custom Integration

```swift
// Batch snapshot creation
for volume in selectedVolumes {
    let snapshot = SnapshotCreateRequest(
        volumeId: volume.id,
        name: "backup-\(Date())",
        force: true
    )
    await tui.client.createSnapshot(snapshot)
}
```

## Troubleshooting

### Common Issues

#### Volume Stuck in Creating State

**Symptoms:** Volume remains in "creating" status for extended time
**Cause:** Backend storage issues or quota exceeded
**Solution:** Check Cinder logs, verify storage backend health, check quotas

#### Attachment Fails

**Symptoms:** Cannot attach volume to instance
**Cause:** Volume in wrong availability zone or already attached
**Solution:** Verify AZ matches, check multi-attach capability, detach from other instances

#### Backup Creation Fails

**Symptoms:** Backup fails immediately or times out
**Cause:** Swift/S3 backend unavailable or volume in use
**Solution:** Check object storage service, ensure volume is available state

### Debug Commands

- Check volume service status in Health Dashboard
- Review Cinder service logs for errors
- Verify quota usage in dashboard
- Check backend storage capacity

## Related Documentation

- [Module Catalog](./index.md)
- [Servers Module](./servers.md)
- [Images Module](./images.md)
- [OpenStack Cinder Documentation](https://docs.openstack.org/cinder/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `volumes` |
| **Display Name** | Volumes (Cinder) |
| **Version** | 1.0.0 |
| **Service** | OpenStack Cinder |
| **Category** | Storage |
| **Deletion Priority** | 30 |
| **Load Order** | 40 |
| **Memory Usage** | ~15 MB typical |
| **CPU Impact** | Low |

---

*Last Updated: 2024-11-23*
*Documentation Version: 1.0.0*
