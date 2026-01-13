# Hypervisors Module

## Overview

**Service:** Nova (Compute Service)
**Identifier:** `hypervisors`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Hypervisors/`

The Hypervisors module provides administrative access to OpenStack Nova compute hypervisors. This module enables operators to monitor hypervisor health, resource utilization, and manage compute service availability. It is essential for capacity planning, maintenance operations, and infrastructure monitoring.

**Note:** Hypervisor operations require administrative privileges. Regular users will see an empty list or receive permission errors.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Hypervisor catalog with resource usage metrics |
| **Detail View** | Yes | Comprehensive hypervisor specifications and status |
| **Enable/Disable** | Yes | Control compute service scheduling availability |
| **Server Discovery** | Yes | View instances running on specific hypervisors |
| **Create/Edit** | No | Read-only (hypervisors are physical infrastructure) |
| **Batch Operations** | No | Single hypervisor operations only |
| **Multi-Select** | No | Single selection only |
| **Search/Filter** | Yes | Filter by hostname, state, status, type |
| **Auto-Refresh** | Yes | Periodic refresh every 60 seconds |
| **Health Monitoring** | Yes | State, status, and resource tracking |

## Dependencies

### Required Modules

- None (Hypervisors is a base module with no dependencies)

### Optional Modules

- **Servers** - View instances running on hypervisors
- **Compute Services** - Related compute service management

## Features

### Resource Management

- **Hypervisor Monitoring**: View all compute hypervisors in the cloud
- **Resource Metrics**: Track vCPU, memory, and disk utilization
- **State Tracking**: Monitor hypervisor up/down state
- **Status Management**: Enable or disable hypervisors for scheduling
- **Instance Discovery**: Find servers running on specific hypervisors

### List Operations

The hypervisor list provides a comprehensive view of compute infrastructure with real-time resource utilization metrics.

**Available Actions:**

- `Enter` - View detailed hypervisor information
- `/` - Search hypervisors by hostname, state, or type
- `r` - Refresh hypervisor list
- `E` (Shift) - Enable selected hypervisor
- `D` (Shift) - Disable selected hypervisor (with reason prompt)
- `S` (Shift) - View servers on selected hypervisor
- `Tab` - Switch between views
- `Esc` - Return to main menu

**List Columns:**

| Column | Width | Description |
|--------|-------|-------------|
| HOSTNAME | 28 | Hypervisor hostname |
| STATE | 8 | Current state (UP/DOWN) |
| STATUS | 10 | Scheduling status (Enabled/Disabled) |
| VMs | 6 | Number of running virtual machines |
| vCPUs | 12 | Used/Total vCPU allocation |
| MEMORY | 14 | Used/Total memory in GB |

### Detail View

Displays comprehensive hypervisor information including identification, state, resource usage, and instance statistics.

**Displayed Information:**

- **Basic Information**: ID, hostname, host IP, type, version, service ID
- **State and Status**: Current state (UP/DOWN), status (Enabled/Disabled), operational status
- **Resource Usage**: vCPU, memory, and local disk utilization with percentages
- **Instance Information**: Running VMs count, current workload
- **Available Resources**: Free memory, free disk, disk available least

### Enable/Disable Operations

Hypervisors can be enabled or disabled to control instance scheduling. Disabling a hypervisor prevents new instances from being scheduled on it while existing instances continue to run.

**Enable Hypervisor:**

1. Select hypervisor from list or detail view
2. Press `E` (Shift+E)
3. Confirm the operation
4. Hypervisor becomes available for scheduling

**Disable Hypervisor:**

1. Select hypervisor from list or detail view
2. Press `D` (Shift+D)
3. Enter a reason for disabling
4. Confirm the operation
5. Hypervisor stops accepting new instances

### Server Discovery

View all instances running on a specific hypervisor to understand workload distribution and plan maintenance activities.

**Usage:**

1. Select a hypervisor
2. Press `S` (Shift+S)
3. Navigates to Servers view filtered to that hypervisor

## API Endpoints

### Primary Endpoints

- `GET /os-hypervisors` - List all hypervisors
- `GET /os-hypervisors/detail` - List hypervisors with full details
- `GET /os-hypervisors/{hypervisor_id}` - Get specific hypervisor details

### Secondary Endpoints

- `GET /os-hypervisors/{hypervisor_id}/servers` - List servers on hypervisor
- `PUT /os-services/enable` - Enable compute service on host
- `PUT /os-services/disable` - Disable compute service on host

## Configuration

### Module Settings

```swift
HypervisorsModule(
    identifier: "hypervisors",
    displayName: "Hypervisors",
    version: "1.0.0",
    cacheEnabled: true
)
```

### Environment Variables

- `HYPERVISOR_REFRESH_INTERVAL` - Auto-refresh interval in seconds (Default: `60`)
- `HYPERVISOR_CACHE_TTL` - Cache lifetime in seconds (Default: `60`)

### Performance Tuning

- **Refresh Interval**: Set to 60 seconds by default due to frequent resource usage changes
- **Cache Duration**: Short-lived cache as hypervisor metrics change frequently
- **Timeout Configuration**: Priority-based timeouts (10-30 seconds depending on priority)

## Views

### Registered View Modes

#### Hypervisors List (`hypervisors`)

**Purpose:** Display and browse all compute hypervisors with resource metrics

**Key Features:**

- Hostname and IP identification
- State indicators (UP/DOWN) with color coding
- Status indicators (Enabled/Disabled) with color coding
- Real-time resource usage (vCPUs, memory)
- Running VM count per hypervisor
- Search and filter support

**Navigation:**

- **Enter from:** Main menu, compute services
- **Exit to:** Hypervisor detail view, main menu

#### Hypervisor Detail (`hypervisorDetail`)

**Purpose:** Display comprehensive hypervisor specifications and controls

**Key Features:**

- Complete identification information
- Detailed state and status indicators
- Resource usage with percentages
- Instance statistics
- Available resource metrics
- Enable/disable controls

**Navigation:**

- **Enter from:** Hypervisors list view
- **Exit to:** Hypervisors list view

## Keyboard Shortcuts

### Global Shortcuts (Available in all module views)

| Key | Action | Context |
|-----|--------|---------|
| `Enter` | Select/View Details | List views |
| `Esc` | Go Back | Any view |
| `q` | Quit to Main Menu | Any view |
| `/` | Search | List views |
| `r` | Refresh | List views |
| `c` | Clear Cache | List views |

### Module-Specific Shortcuts

| Key | Action | View | Description |
|-----|--------|------|-------------|
| `E` (Shift) | Enable Hypervisor | List/Detail | Enable compute scheduling |
| `D` (Shift) | Disable Hypervisor | List/Detail | Disable with reason prompt |
| `S` (Shift) | View Servers | List/Detail | Show instances on hypervisor |
| `Tab` | Switch View | Any | Toggle between list and detail |

## Data Provider

**Provider Class:** `HypervisorsDataProvider`

### Caching Strategy

Hypervisor data is cached with a short TTL due to frequently changing resource metrics. Cache is refreshed automatically every 60 seconds to provide near real-time resource visibility.

### Refresh Patterns

- **Automatic Refresh**: Every 60 seconds (configurable)
- **Manual Refresh**: On-demand with 'r' key or 'c' for cache clear
- **Startup Load**: Full refresh on module initialization
- **Post-Action Refresh**: Automatic refresh after enable/disable operations

### Performance Optimizations

- **Priority-Based Timeouts**: Critical operations get 30s, background operations get 10s
- **Async Task Groups**: Timeout handling via Swift concurrency
- **Weak References**: Proper memory management with weak TUI/module references
- **On-Demand Loading**: Server lists fetched only when requested

## Known Limitations

### Current Constraints

- **Admin-Only Access**: Requires administrative privileges to view hypervisors
- **Read-Only Infrastructure**: Cannot create or modify hypervisor configurations
- **No Live Migration**: Migration operations not yet supported
- **Limited Metrics History**: Only current point-in-time metrics available
- **No NUMA Topology**: Detailed NUMA information not displayed

### Planned Improvements

- Live migration support for instance evacuation
- Historical resource usage graphs
- NUMA topology visualization
- Aggregate and availability zone integration
- Resource allocation ratio configuration

## Examples

### Common Usage Scenarios

#### Monitoring Hypervisor Health

```
1. Navigate to Hypervisors module from main menu
2. Review STATE column for any DOWN hypervisors
3. Check STATUS column for disabled hypervisors
4. Press Enter on any hypervisor for detailed metrics
5. Review resource utilization percentages
```

#### Preparing Hypervisor for Maintenance

```
1. Enter Hypervisors module
2. Select the hypervisor to maintain
3. Press S (Shift+S) to view running instances
4. Migrate instances to other hypervisors as needed
5. Return to Hypervisors view
6. Press D (Shift+D) to disable
7. Enter maintenance reason (e.g., "Hardware upgrade")
8. Confirm the disable operation
```

#### Re-enabling After Maintenance

```
1. Navigate to Hypervisors module
2. Select the disabled hypervisor
3. Press E (Shift+E) to enable
4. Confirm the enable operation
5. Verify STATUS changes to "Enabled"
```

#### Finding Overloaded Hypervisors

```
1. Enter Hypervisors module
2. Review vCPU and MEMORY columns
3. Look for hypervisors with high utilization
4. Press Enter for detailed view
5. Check usage percentages in Resource Usage section
```

### Code Examples

#### Programmatic Access

```swift
// Access hypervisors through data provider
let provider = DataProviderRegistry.shared.provider(for: "hypervisors")
let result = await provider.fetchData(priority: .critical, forceRefresh: true)

// Access cached hypervisors
let hypervisors = tui.cacheManager.cachedHypervisors

// Filter operational hypervisors
let operational = hypervisors.filter { $0.isOperational }
```

#### Custom Integration

```swift
// Analyze hypervisor capacity
extension HypervisorsModule {
    func analyzeCapacity() -> CapacityReport {
        let hypervisors = self.hypervisors

        let totalVcpus = hypervisors.compactMap { $0.vcpus }.reduce(0, +)
        let usedVcpus = hypervisors.compactMap { $0.vcpusUsed }.reduce(0, +)
        let totalMemoryGb = hypervisors.compactMap { $0.memoryMb }.reduce(0, +) / 1024
        let usedMemoryGb = hypervisors.compactMap { $0.memoryMbUsed }.reduce(0, +) / 1024

        return CapacityReport(
            vcpuUtilization: Double(usedVcpus) / Double(totalVcpus) * 100,
            memoryUtilization: Double(usedMemoryGb) / Double(totalMemoryGb) * 100,
            runningVms: hypervisors.compactMap { $0.runningVms }.reduce(0, +)
        )
    }
}
```

## Troubleshooting

### Common Issues

#### Hypervisors Not Loading

**Symptoms:** Empty hypervisor list or permission errors
**Cause:** User does not have administrative privileges
**Solution:** Verify user has admin role in OpenStack. Hypervisor API requires admin access.

#### Enable/Disable Operations Fail

**Symptoms:** Error message when trying to enable or disable
**Cause:** Compute service API issues or insufficient permissions
**Solution:** Verify compute service is responding and user has service management permissions

#### Stale Resource Metrics

**Symptoms:** Resource utilization appears outdated
**Cause:** Cache not refreshed
**Solution:** Press 'r' to force refresh or 'c' to clear cache and reload

#### Hypervisor Shows DOWN State

**Symptoms:** STATE shows DOWN for a hypervisor
**Cause:** Compute service on host is not responding
**Solution:** Check compute service status on the affected host. May indicate infrastructure issues.

#### Server List Empty for Hypervisor

**Symptoms:** No servers shown when pressing S on hypervisor with running VMs
**Cause:** API timeout or filtering issue
**Solution:** Verify server API is accessible. Check network connectivity to OpenStack API.

### Debug Commands

```bash
# List all hypervisors via CLI
openstack hypervisor list

# Show hypervisor details
openstack hypervisor show <hypervisor_id>

# List servers on a hypervisor
openstack hypervisor servers <hypervisor_hostname>

# Check compute service status
openstack compute service list

# Enable compute service
openstack compute service set --enable <host>

# Disable compute service with reason
openstack compute service set --disable --disable-reason "Maintenance" <host>

# Check logs
cat ~/.substation/logs/hypervisors.log
```

## Related Documentation

- [Module Catalog](./index.md)
- [Servers Module](./servers.md)
- [Flavors Module](./flavors.md)
- [OpenStack Nova Hypervisors API](https://docs.openstack.org/api-ref/compute/#hypervisors-os-hypervisors)
- [OpenStack Compute Service Management](https://docs.openstack.org/nova/latest/admin/services.html)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `hypervisors` |
| **Display Name** | Hypervisors |
| **Version** | 1.0.0 |
| **Service** | Nova |
| **Category** | Compute Infrastructure |
| **Dependencies** | None |
| **Deletion Priority** | N/A |
| **Load Order** | 5 |
| **Memory Usage** | ~3-8 MB |
| **CPU Impact** | Low |
| **Refresh Interval** | 60 seconds |
| **Admin Required** | Yes |

---

*Last Updated: January 2025*
*Documentation Version: 1.0.0*
