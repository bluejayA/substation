# Swift Module

## Overview

**Service:** OpenStack Swift (Object Storage)
**Identifier:** `swift`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Swift/`

The Swift module provides comprehensive object storage management for OpenStack Swift. It offers a hierarchical file-browser interface for navigating containers and objects, with support for uploads, downloads, metadata management, and background operations. The module features advanced capabilities including directory-based navigation, bulk operations, web access configuration, and real-time transfer monitoring.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Hierarchical container/object browser with tree navigation |
| **Detail View** | Yes | Container and object details with metadata |
| **Create/Edit** | Yes | Container creation, object upload, metadata editing |
| **Batch Operations** | Yes | Bulk delete, bulk download, bulk upload |
| **Multi-Select** | Yes | Select multiple objects for batch operations |
| **Search/Filter** | Yes | Search within containers by name or path |
| **Auto-Refresh** | Yes | 60-second background sync with ETag differential updates |
| **Health Monitoring** | Yes | Service availability and transfer status tracking |

## Dependencies

### Required Modules

This module has no required dependencies and can operate independently.

### Optional Modules

- **Servers** - Integration for serving objects to compute instances
- **Images** - Upload images directly to Swift storage

## Features

### Resource Management

- **Container Management**: Create, delete, and configure storage containers
- **Object Operations**: Upload, download, delete objects and directories
- **Metadata Management**: Edit container and object metadata
- **Directory Navigation**: Pseudo-directory support with breadcrumb navigation
- **Web Access**: Configure public/private web access for containers
- **Transfer Monitoring**: Real-time progress for uploads and downloads
- **Background Operations**: Track long-running transfers in background

### List Operations

The Swift browser provides a file-system-like interface for navigating object storage.

**Available Actions:**

- `Space` - Navigate into container/directory or view object details
- `Enter` - Show container metadata (from container list)
- `Esc` - Navigate up one directory level or back to container list
- `c` - Create new container
- `U` - Upload file(s) to current location
- `D` - Download selected object(s) or container
- `Delete` - Delete selected object(s)/container(s)
- `M` - Edit metadata
- `W` - Configure web access
- `/` - Search in current container
- `b` - View background operations

### Detail View

Displays comprehensive information about containers and objects.

**Displayed Information:**

- **Container Details**: Object count, total size, storage policy, metadata
- **Object Details**: Size, content type, ETag/MD5, last modified
- **Metadata**: Custom headers and system metadata
- **Access Control**: Read/write ACLs, temporary URLs
- **Web Settings**: Index file, error file, listings enabled

### Create/Edit Operations

Multiple forms for different Swift operations with context-aware fields.

**Container Creation Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Container Name | Text | Yes | Container name (cannot contain '/' character) |

**Object Upload Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| File/Directory Path | Text | Yes | Local file or directory to upload |
| Prefix | Text | No | Prefix for object names (directories only) |
| Object Name | Text | No | Override object name (single files only) |
| Content-Type | Text | No | MIME type (auto-detected if empty) |
| Recursive | Toggle | No | Include subdirectories (directories only) |
| Background Upload | Toggle | No | Run upload in background (default: enabled) |

### Batch Operations

Efficient bulk operations for managing multiple objects simultaneously.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple objects/directories or containers
- **Bulk Download**: Download multiple objects with directory structure
- **Bulk Upload**: Upload entire directories recursively
- **Bulk Create**: Create multiple containers

## API Endpoints

### Primary Endpoints

- `GET /v1/{account}` - List containers
- `GET /v1/{account}/{container}` - List objects in container
- `PUT /v1/{account}/{container}` - Create container
- `DELETE /v1/{account}/{container}` - Delete container
- `PUT /v1/{account}/{container}/{object}` - Upload object
- `GET /v1/{account}/{container}/{object}` - Download object
- `DELETE /v1/{account}/{container}/{object}` - Delete object

### Secondary Endpoints

- `HEAD /v1/{account}/{container}` - Get container metadata
- `POST /v1/{account}/{container}` - Update container metadata
- `HEAD /v1/{account}/{container}/{object}` - Get object metadata
- `POST /v1/{account}/{container}/{object}` - Update object metadata
- `GET /v1/{account}?format=json` - Get account statistics

## Configuration

### Module Settings

```swift
// Module initialization
let swiftModule = SwiftModule(tui: tui)

// Configuration with background sync
await swiftModule.configure()

// Stop background sync
swiftModule.stopBackgroundSyncTask()
```

### Environment Variables

- `SWIFT_MAX_CACHE_CONTAINERS` - Maximum cached containers (Default: `10`)
- `SWIFT_SYNC_INTERVAL` - Background sync interval in seconds (Default: `60`)

### Performance Tuning

- **Container Cache**: LRU cache for 10 most recent containers
- **ETag Differential Sync**: Only fetch changed objects (uses object count as pseudo-ETag)
- **Tree Prefetch**: Prefetch up to 10 top-level directory structures for instant navigation
- **Parallel Fetching**: Up to 5 concurrent workers for large container loading
- **Page Size**: 100 objects for initial page, 1000 for background fetching

## Views

### Registered View Modes

#### Swift Browser (`.swift`)

**Purpose:** Main container and object browser interface

**Key Features:**

- Tree-style navigation
- Container/object indicators
- Size and count display
- Breadcrumb navigation

**Navigation:**

- **Enter from:** Main menu, dashboard
- **Exit to:** Object detail, container detail, upload form

#### Container Detail (`.swiftContainerDetail`)

**Purpose:** Display container information and settings

**Key Features:**

- Storage statistics
- Access control settings
- Metadata display
- Web access configuration

**Navigation:**

- **Enter from:** Swift browser
- **Exit to:** Swift browser, metadata editor

#### Object Detail (`.swiftObjectDetail`)

**Purpose:** Show object properties and metadata

**Key Features:**

- Content information
- Download link generation
- Metadata display
- Version information

**Navigation:**

- **Enter from:** Swift browser
- **Exit to:** Swift browser, download form

#### Background Operations (`.swiftBackgroundOperations`)

**Purpose:** Monitor active transfers and operations

**Key Features:**

- Operation list with type, status, resource, container, progress, size, rate, time columns
- Status indicators (Queued, Running, Completed, Failed, Canceled)
- Cancel active operations
- Remove completed operations from history

**Keyboard Shortcuts:**

| Key | Action | Description |
|-----|--------|-------------|
| `Space` | Open Detail | View detailed operation information |
| `M` | Performance Metrics | Navigate to performance metrics view |
| `Delete/Backspace` | Cancel/Remove | Cancel active operation or remove from history |

**Navigation:**

- **Enter from:** Any Swift view via 'b' key
- **Exit to:** Previous view

#### Background Operation Detail (`.swiftBackgroundOperationDetail`)

**Purpose:** View detailed information about a specific background operation

**Key Features:**

- Basic information (ID, type, status)
- Resource information (container, object, local path)
- Progress information (percentage, bytes transferred, transfer rate, files processed)
- Timing information (start time, elapsed time, duration)
- Error information (if failed)
- Cancel/remove options

**Keyboard Shortcuts:**

| Key | Action | Description |
|-----|--------|-------------|
| `Delete/Backspace` | Cancel/Remove | Cancel active operation or remove from history |
| `Esc` | Go Back | Return to operations list |

**Navigation:**

- **Enter from:** Background operations list via Space key
- **Exit to:** Background operations list

#### Container Create (`.swiftContainerCreate`)

**Purpose:** Create a new Swift container

**Key Features:**

- Container name input
- Access control configuration
- Storage policy selection
- Metadata assignment

**Navigation:**

- **Enter from:** Swift browser via 'c' key
- **Exit to:** Swift browser

#### Object Upload (`.swiftObjectUpload`)

**Purpose:** Upload files or directories to a container

**Key Features:**

- File/directory selection
- Upload progress tracking
- Metadata assignment
- Automatic segmentation for large files
- Background transfer support

**Navigation:**

- **Enter from:** Container view via 'u' key
- **Exit to:** Container view

#### Container Download (`.swiftContainerDownload`)

**Purpose:** Download entire container contents

**Key Features:**

- Destination directory selection
- Progress tracking
- Preserve directory structure
- Resume support
- Background download

**Navigation:**

- **Enter from:** Swift browser
- **Exit to:** Swift browser

#### Object Download (`.swiftObjectDownload`)

**Purpose:** Download a specific object from a container

**Key Features:**

- Destination path selection
- Progress tracking
- ETag verification
- Resume capability
- Background transfer

**Navigation:**

- **Enter from:** Object detail or container view via 'd' key
- **Exit to:** Previous view

#### Directory Download (`.swiftDirectoryDownload`)

**Purpose:** Download a virtual directory (prefix) from a container

**Key Features:**

- Recursive download
- Directory structure preservation
- Progress for multiple objects
- Parallel transfers
- Background operation

**Navigation:**

- **Enter from:** Container view with directory selected
- **Exit to:** Container view

#### Container Metadata (`.swiftContainerMetadata`)

**Purpose:** View and edit container metadata

**Key Features:**

- Standard metadata display
- Custom metadata editing
- ACL configuration
- Versioning settings
- CORS configuration

**Navigation:**

- **Enter from:** Container view via 'm' key
- **Exit to:** Container view

#### Object Metadata (`.swiftObjectMetadata`)

**Purpose:** View and edit object metadata

**Key Features:**

- Content type editing
- Custom metadata
- Cache control headers
- Content disposition
- Delete at timestamp

**Navigation:**

- **Enter from:** Object detail via 'm' key
- **Exit to:** Object detail

#### Directory Metadata (`.swiftDirectoryMetadata`)

**Purpose:** View and edit metadata for a virtual directory

**Key Features:**

- Directory-level metadata
- Propagation to child objects
- Custom attributes
- Access control

**Navigation:**

- **Enter from:** Container view with directory selected
- **Exit to:** Container view

#### Container Web Access (`.swiftContainerWebAccess`)

**Purpose:** Configure container for static website hosting

**Key Features:**

- Index page configuration
- Error page setup
- CSS customization
- Access control
- CDN settings

**Navigation:**

- **Enter from:** Container view via 'w' key
- **Exit to:** Container view

## Keyboard Shortcuts

### Global Shortcuts (Available in all module views)

| Key | Action | Context |
|-----|--------|---------|
| `Enter` | Select/Navigate | List views |
| `Esc` | Go Back | Any view |
| `q` | Quit to Main Menu | Any view |
| `/` | Search | Container view |
| `r` | Refresh | List views |

### Module-Specific Shortcuts

| Key | Action | View | Description |
|-----|--------|------|-------------|
| `Space` | Navigate Into | Swift Browser | Enter container |
| `Enter` | Show Metadata | Swift Browser | Show container details |
| `Esc` | Navigate Up | Container Detail | Go to parent directory or container list |
| `c` | Create Container | Swift Browser | Create new container |
| `U` | Upload | Container View | Upload files/directories |
| `D` | Download | Container View | Download selected items |
| `M` | Metadata | Any Swift View | Edit metadata |
| `W` | Web Access | Swift Browser | Configure web settings |
| `b` | Background Ops | Any Swift View | View active operations |
| `Delete` | Delete | List Views | Delete selected items |

## Data Provider

**Provider Class:** `SwiftDataProvider`

### Caching Strategy

The module implements intelligent caching with ETag-based differential sync. Container contents are cached with automatic background refresh every 60 seconds. Only changed objects are updated to minimize API calls.

### Refresh Patterns

- **ETag Differential**: Only fetch if container object count changed
- **Background Sync**: Automatic refresh for active container every 60 seconds
- **LRU Eviction**: Keep only 10 most recent containers cached
- **Tree Prefetch**: Prefetch up to 10 top-level directory structures
- **Stale-While-Revalidate**: Show cached data immediately, revalidate in background if stale (30-second freshness threshold)

### Performance Optimizations

- **Parallel Uploads**: Multiple files uploaded concurrently
- **Chunked Transfers**: Large files split into 64MB chunks
- **Progressive Loading**: Load objects as user scrolls
- **Metadata Caching**: Cache frequently accessed metadata

## Known Limitations

### Current Constraints

- **Large Containers**: Performance degrades with >10,000 objects
- **Versioning**: Object versioning UI not yet implemented
- **Segments**: Large object segments not fully supported
- **Temp URLs**: Temporary URL generation requires manual configuration

### Planned Improvements

- Object versioning interface
- Static large object support
- Dynamic large object assembly
- Bulk archive extraction
- Cross-container copy/move

## Examples

### Common Usage Scenarios

#### Uploading a Directory

```
1. Navigate to target container
2. Press 'u' for upload
3. Select directory path
4. Enable "Recursive" option
5. Confirm to start background upload
6. Press 'b' to monitor progress
```

#### Setting Up Web Hosting

```
1. Select container in browser
2. Press 'w' for web access
3. Enable "Web Listing"
4. Set index.html as index file
5. Set 404.html as error file
6. Apply settings
```

#### Bulk Download with Structure

```
1. Navigate to container/directory
2. Press Space to enable multi-select
3. Select desired objects
4. Press 'd' for download
5. Choose local directory
6. Enable "Preserve Structure"
7. Start download
```

### Code Examples

#### Programmatic Access

```swift
// List containers
let containers = await tui.client.getContainers()

// Upload object
let data = Data(contentsOf: fileURL)
await tui.client.createObject(
    container: "my-container",
    name: "path/to/object.txt",
    data: data,
    contentType: "text/plain"
)
```

#### Custom Integration

```swift
// Bulk metadata update
for object in selectedObjects {
    var metadata = object.metadata ?? [:]
    metadata["X-Object-Meta-Category"] = "archived"
    await tui.client.updateObjectMetadata(
        container: containerName,
        object: object.name,
        metadata: metadata
    )
}
```

## Troubleshooting

### Common Issues

#### Slow Container Listing

**Symptoms:** Container takes long time to load
**Cause:** Large number of objects without pagination
**Solution:** Use prefix filtering or implement pagination

#### Upload Fails for Large Files

**Symptoms:** Upload times out or fails
**Cause:** File exceeds single object size limit
**Solution:** Use segmented upload for files >5GB

#### ETag Mismatch

**Symptoms:** Upload completes but verification fails
**Cause:** Data corruption during transfer
**Solution:** Retry upload, check network stability

### Debug Commands

- Check Swift service status in Health Dashboard
- Monitor background operations with 'b' key
- Review transfer logs in background operation details
- Verify container ACLs and policies

## Related Documentation

- [Module Catalog](./index.md)
- [Volumes Module](./volumes.md)
- [Images Module](./images.md)
- [OpenStack Swift Documentation](https://docs.openstack.org/swift/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `swift` |
| **Display Name** | Object Storage (Swift) |
| **Version** | 1.0.0 |
| **Service** | OpenStack Swift |
| **Category** | Storage |
| **Deletion Priority** | 25 |
| **Load Order** | 35 |
| **Memory Usage** | ~20 MB typical (varies with cache) |
| **CPU Impact** | Low (higher during transfers) |

---

*Last Updated: January 2025*
*Documentation Version: 1.1.0*
