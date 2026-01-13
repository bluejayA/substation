# Flavors Module

## Overview

**Service:** Nova (Compute Service)
**Identifier:** `flavors`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Flavors/`

The Flavors module provides read-only access to OpenStack Nova instance types (flavors), which define the compute, memory, and storage capacity of virtual machine instances. This module is essential for server creation workflows and capacity planning.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Complete flavor catalog with resource specifications |
| **Detail View** | Yes | Detailed specifications and performance analysis |
| **Create/Edit** | No | Read-only (admin operation via CLI/API) |
| **Batch Operations** | No | Not applicable for flavors |
| **Multi-Select** | No | Single selection only |
| **Search/Filter** | Yes | Filter by name, RAM, vCPUs, disk |
| **Auto-Refresh** | Yes | Periodic refresh of flavor list |
| **Health Monitoring** | Yes | Availability and quota tracking |

## Dependencies

### Required Modules

- None (Flavors is a base module with no dependencies)

### Optional Modules

- **Servers** - Uses flavors for instance sizing
- **Quotas** - Validates flavor usage against quotas

## Features

### Resource Management

- **Flavor Browsing**: Navigate available instance types
- **Resource Specifications**: View vCPUs, RAM, disk allocations
- **Performance Categories**: Group by compute-optimized, memory-optimized, etc.
- **Cost Analysis**: Compare resource allocations across flavors
- **Extra Specs Viewing**: Access advanced flavor properties

### List Operations

The flavor list provides a comprehensive view of available instance types with sortable resource specifications.

**Available Actions:**

- `Enter` - View detailed flavor specifications
- `/` - Search flavors by name or specs
- `r` - Refresh flavor list
- `s` - Sort by different criteria (name, RAM, vCPUs)
- `Tab` - Switch between views

### Detail View

Displays complete flavor specifications including performance characteristics and recommended use cases.

**Displayed Information:**

- **Core Specs**: vCPUs, RAM, root disk, ephemeral disk, swap
- **Performance Profile**: CPU policy, NUMA topology, CPU threads
- **Resource Limits**: IOPS limits, bandwidth restrictions
- **Extra Specifications**: Custom properties, GPU allocation, SR-IOV
- **Usage Recommendations**: Workload suitability analysis

### Create/Edit Operations

This module is read-only. Flavor management is an administrative operation performed through the OpenStack CLI or API.

### Batch Operations

Not applicable for flavors as they are system-defined resources.

## API Endpoints

### Primary Endpoints

- `GET /flavors` - List all flavors
- `GET /flavors/detail` - List flavors with full details
- `GET /flavors/{flavor_id}` - Get specific flavor details

### Secondary Endpoints

- `GET /flavors/{flavor_id}/os-extra_specs` - Get flavor extra specifications
- `GET /flavors/{flavor_id}/os-flavor-access` - Get flavor access list

## Configuration

### Module Settings

```swift
FlavorsModule(
    identifier: "flavors",
    displayName: "Instance Flavors",
    version: "1.0.0",
    cacheEnabled: true
)
```

### Environment Variables

- `FLAVOR_LIST_LIMIT` - Maximum flavors per page (Default: `100`)
- `FLAVOR_CACHE_TTL` - Cache lifetime in seconds (Default: `300`)
- `SHOW_PRIVATE_FLAVORS` - Include private flavors (Default: `false`)

### Performance Tuning

- **Cache Duration**: Increase `FLAVOR_CACHE_TTL` as flavors rarely change
- **List Filtering**: Use `SHOW_PRIVATE_FLAVORS` to reduce list size
- **Sorting**: Pre-sort by most commonly used criteria

## Views

### Registered View Modes

#### Flavor List (`flavors`)

**Purpose:** Display and browse available instance flavors

**Key Features:**

- Resource specification columns (vCPUs, RAM, disk)
- Performance category indicators
- Quick comparison of specifications
- Sortable by any resource dimension

**Navigation:**

- **Enter from:** Main menu, server creation workflow
- **Exit to:** Flavor detail view, main menu

#### Flavor Detail (`flavorDetail`)

**Purpose:** Display comprehensive flavor specifications and analysis

**Key Features:**

- Complete resource specifications
- Extra specs and custom properties
- Performance characteristics
- Workload recommendations

**Navigation:**

- **Enter from:** Flavor list view
- **Exit to:** Flavor list view

#### Flavor Selection (`flavorSelection`)

**Purpose:** Select a flavor during server creation

**Key Features:**

- Filtered view based on requirements
- Quick resource comparison
- Quota validation indicators
- Immediate selection feedback

**Navigation:**

- **Enter from:** Server creation form
- **Exit to:** Server creation form with selection

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
| `s` | Sort Options | List | Cycle through sort criteria |
| `f` | Filter Toggle | List | Show/hide private flavors |
| `c` | Compare Mode | List | Enter flavor comparison view |
| `Tab` | Switch View | Any | Toggle between list and detail |
| `Space` | Quick Select | Selection | Select flavor in creation workflow |

## Data Provider

**Provider Class:** `FlavorsDataProvider`

### Caching Strategy

Flavors are aggressively cached as they change infrequently. Cache is shared across all module instances.

### Refresh Patterns

- **Automatic Refresh**: Every 5 minutes (configurable)
- **Manual Refresh**: On-demand with 'r' key
- **Startup Load**: Full refresh on module initialization

### Performance Optimizations

- **Static Caching**: Flavors cached for extended periods
- **Lazy Extra Specs**: Extra specifications loaded on demand
- **Sorted Cache**: Pre-sorted by common criteria

## Known Limitations

### Current Constraints

- **Read-Only Access**: Cannot create or modify flavors
- **Admin Properties**: Some properties hidden for non-admin users
- **Custom Flavors**: Private flavors may not be visible
- **GPU Details**: Limited GPU specification display

### Planned Improvements

- Advanced filtering by extra specifications
- Flavor comparison matrix view
- Resource calculator integration
- Cost estimation features

## Examples

### Common Usage Scenarios

#### Finding Appropriate Flavor for Workload

```
1. Navigate to Flavors module
2. Press 's' to sort by RAM
3. Use '/' to search for specific requirements
4. Press Enter to view detailed specs
5. Review extra specifications for special features
```

#### Selecting Flavor During Server Creation

```
1. In server creation form, select flavor field
2. Flavors module opens in selection mode
3. Browse or search for appropriate flavor
4. Press Space or Enter to select
5. Return to creation form with selection
```

#### Comparing Multiple Flavors

```
1. Enter Flavors module
2. Press 'c' for comparison mode
3. Select flavors to compare
4. View side-by-side specifications
5. Make informed selection decision
```

### Code Examples

#### Programmatic Access

```swift
// Access flavors through data provider
let provider = DataProviderRegistry.shared.provider(for: "flavors")
let flavors = await provider.fetchData()

// Filter by minimum RAM requirement
let largeFlavors = flavors.filter { $0.ram >= 16384 }
```

#### Custom Integration

```swift
// Add custom flavor analyzer
extension FlavorsModule {
    func analyzeWorkloadFit(flavor: Flavor, workload: WorkloadType) -> FitScore {
        // Custom analysis logic
        return FitScore(
            cpu: evaluateCPU(flavor.vcpus, workload.cpuRequirement),
            memory: evaluateMemory(flavor.ram, workload.memoryRequirement),
            storage: evaluateStorage(flavor.disk, workload.storageRequirement)
        )
    }
}
```

## Troubleshooting

### Common Issues

#### Flavors Not Loading

**Symptoms:** Empty flavor list or errors
**Cause:** Nova service issues or permissions
**Solution:** Verify Nova service status and user permissions

#### Missing Private Flavors

**Symptoms:** Expected flavors not visible
**Cause:** Flavor access restrictions
**Solution:** Check flavor access list or contact administrator

#### Incorrect Specifications Display

**Symptoms:** Wrong resource values shown
**Cause:** Cache inconsistency
**Solution:** Force refresh with 'r' key or clear cache

### Debug Commands

- `openstack flavor list --all` - List all available flavors
- `openstack flavor show <flavor>` - Show flavor details
- Check logs in `~/.substation/logs/flavors.log`

## Related Documentation

- [Module Catalog](./index.md)
- [Servers Module](./servers.md)
- [OpenStack Nova Documentation](https://docs.openstack.org/nova/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `flavors` |
| **Display Name** | Instance Flavors |
| **Version** | 1.0.0 |
| **Service** | Nova |
| **Category** | Compute Infrastructure |
| **Deletion Priority** | N/A |
| **Load Order** | 5 |
| **Memory Usage** | ~2-5 MB |
| **CPU Impact** | Minimal |
