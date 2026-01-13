# Images Module

## Overview

**Service:** Glance (Image Service)
**Identifier:** `images`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Images/`

The Images module provides read-only access to OpenStack Glance (Image Service) functionality, enabling users to browse, search, and inspect machine images used for launching virtual instances. This module serves as a critical dependency for server creation and volume operations.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Full image catalog with filtering and search |
| **Detail View** | Yes | Comprehensive image properties and metadata |
| **Create/Edit** | No | Read-only module (creation via CLI/API only) |
| **Batch Operations** | Yes | Bulk deletion support |
| **Multi-Select** | Yes | Select multiple images for batch operations |
| **Search/Filter** | Yes | Search by name, status, visibility |
| **Auto-Refresh** | Yes | Configurable refresh interval |
| **Health Monitoring** | Yes | Service health and quota tracking |

## Dependencies

### Required Modules

- None (Images is a base module with no dependencies)

### Optional Modules

- **Servers** - Uses images for instance creation
- **Volumes** - Can create volumes from images

## Features

### Resource Management

- **Image Browsing**: Navigate through available machine images
- **Status Filtering**: Filter by ACTIVE, QUEUED, SAVING, ERROR states
- **Visibility Control**: Filter by public, private, shared, community images
- **Property Inspection**: View technical specifications and metadata
- **Size Analysis**: Monitor image sizes and disk requirements

### List Operations

The image list view provides a comprehensive catalog of available images with real-time status updates.

**Available Actions:**

- `Enter` - View detailed image information
- `d` - Delete selected image (with confirmation)
- `/` - Search images by name or properties
- `r` - Refresh image list
- `Tab` - Switch between list and detail views

### Detail View

Displays comprehensive information about a selected image including technical specifications, metadata, and usage recommendations.

**Displayed Information:**

- **Basic Properties**: Name, ID, status, visibility, owner
- **Technical Specs**: Size, disk format, container format, minimum requirements
- **Metadata**: Custom properties, tags, architecture, OS details
- **Security Info**: Checksum, signature verification status
- **Usage Stats**: Creation date, last update, protected status

### Create/Edit Operations

This module is read-only. Image creation and modification must be performed through the OpenStack CLI or API.

### Batch Operations

Supports efficient bulk deletion of multiple images with proper dependency checking.

**Supported Batch Actions:**

- **Bulk Delete**: Remove multiple images in a single operation with automatic dependency validation

## API Endpoints

### Primary Endpoints

- `GET /v2/images` - List all images with pagination
- `GET /v2/images/{image_id}` - Get detailed image information
- `DELETE /v2/images/{image_id}` - Delete an image

### Secondary Endpoints

- `GET /v2/schemas/images` - Get image schema
- `GET /v2/schemas/image` - Get single image schema

## Configuration

### Module Settings

```swift
ImagesModule(
    identifier: "images",
    displayName: "Images (Glance)",
    version: "1.0.0",
    deletionPriority: 9  // Lowest priority for batch operations
)
```

### Environment Variables

- `GLANCE_ENDPOINT` - Override default Glance endpoint (Default: from service catalog)
- `IMAGE_LIST_LIMIT` - Maximum images per page (Default: `100`)
- `IMAGE_CACHE_TTL` - Cache lifetime in seconds (Default: `60`)

### Performance Tuning

- **Pagination Size**: Adjust `IMAGE_LIST_LIMIT` for large catalogs
- **Cache Duration**: Increase `IMAGE_CACHE_TTL` for stable environments
- **Prefetch**: Images are prefetched during module initialization

## Views

### Registered View Modes

#### Image List (`images`)

**Purpose:** Display and manage the catalog of available machine images

**Key Features:**

- Sortable columns (name, status, size, created)
- Real-time status indicators
- Quick filtering by visibility and status
- Multi-select for batch operations

**Navigation:**

- **Enter from:** Main menu, server creation workflow
- **Exit to:** Image detail view, main menu

#### Image Detail (`imageDetail`)

**Purpose:** Display comprehensive information about a specific image

**Key Features:**

- Full property display with categorization
- Metadata viewer with custom properties
- Security information and checksums
- Usage recommendations based on specifications

**Navigation:**

- **Enter from:** Image list view
- **Exit to:** Image list view

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
| `d` | Delete Image | List | Delete selected image with confirmation |
| `Space` | Toggle Selection | List | Select/deselect for batch operations |
| `a` | Select All | List | Select all visible images |
| `A` | Deselect All | List | Clear all selections |
| `Tab` | Switch View | Any | Toggle between list and detail |

## Data Provider

**Provider Class:** `ImagesDataProvider`

### Caching Strategy

Images are cached locally with automatic expiration and refresh. The cache is invalidated when images are deleted or when the TTL expires.

### Refresh Patterns

- **Automatic Refresh**: Every 60 seconds (configurable)
- **Manual Refresh**: On-demand with 'r' key
- **Event-Based**: After delete operations

### Performance Optimizations

- **Lazy Loading**: Image details fetched only when needed
- **Pagination**: Large image lists are paginated
- **Parallel Fetching**: Multiple image details fetched concurrently

## Known Limitations

### Current Constraints

- **Read-Only Operations**: Cannot create or modify images through the TUI
- **Large Images**: Download progress not displayed for image data
- **Format Support**: Limited validation of exotic image formats
- **Metadata Editing**: Cannot modify custom properties through TUI

### Planned Improvements

- Image upload functionality with progress tracking
- Advanced metadata editor
- Image conversion utilities
- Signature verification interface

## Examples

### Common Usage Scenarios

#### Browsing Available Images

```
1. Select "Images (Glance)" from main menu
2. Use arrow keys to navigate image list
3. Press '/' to search for specific images
4. Press Enter to view image details
5. Press Esc to return to list
```

#### Deleting Unused Images

```
1. Navigate to Images module
2. Select image with arrow keys
3. Press 'd' for delete
4. Confirm deletion when prompted
5. Image removed from catalog
```

#### Batch Deletion of Test Images

```
1. Enter Images module
2. Press Space to select multiple images
3. Use 'a' to select all if needed
4. Press 'd' for batch delete
5. Confirm bulk deletion
```

### Code Examples

#### Programmatic Access

```swift
// Access images through the data provider
let provider = DataProviderRegistry.shared.provider(for: "images")
let images = await provider.fetchData()

// Filter active images
let activeImages = images.filter { $0.status == "ACTIVE" }
```

#### Custom Integration

```swift
// Register custom image action
ActionProviderRegistry.shared.registerCustomAction(
    ModuleActionRegistration(
        identifier: "image.analyze",
        title: "Analyze Image",
        keybinding: "z",
        viewModes: [.imageDetail],
        handler: { screen in
            // Custom analysis logic
        }
    )
)
```

## Troubleshooting

### Common Issues

#### Images Not Loading

**Symptoms:** Empty image list or loading errors
**Cause:** Glance service unavailable or authentication issues
**Solution:** Check Glance service status and verify credentials

#### Slow Image List Performance

**Symptoms:** Long load times for image catalog
**Cause:** Large number of images without pagination
**Solution:** Adjust IMAGE_LIST_LIMIT environment variable

#### Delete Operation Fails

**Symptoms:** Error when attempting to delete image
**Cause:** Image in use by active instances or protected
**Solution:** Check for dependent resources and protection status

### Debug Commands

- `openstack image list --debug` - Verify API connectivity
- `glance image-list` - Direct Glance CLI access
- Check logs in `~/.substation/logs/images.log`

## Related Documentation

- [Module Catalog](./index.md)
- [Servers Module](./servers.md)
- [Volumes Module](./volumes.md)
- [OpenStack Glance Documentation](https://docs.openstack.org/glance/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `images` |
| **Display Name** | Images (Glance) |
| **Version** | 1.0.0 |
| **Service** | Glance |
| **Category** | Compute Infrastructure |
| **Deletion Priority** | 9 (lowest) |
| **Load Order** | 10 |
| **Memory Usage** | ~5-10 MB |
| **CPU Impact** | Low |
