# User Guide

Welcome to the Substation User Guide! This comprehensive guide covers all aspects of using Substation for OpenStack cloud management. Whether you're performing routine operations or complex infrastructure deployments, this guide will help you work efficiently.

## Overview

Substation provides a powerful terminal-based interface designed specifically for OpenStack operators. Key benefits include:

- **Keyboard-driven workflow** for maximum efficiency
- **Real-time updates** with intelligent refresh
- **Batch operations** for managing multiple resources
- **Advanced search** across all services
- **Performance monitoring** with built-in telemetry

## Interface Layout

```text
┌──────────────────────────────────────────────────────────────┐
│ Header: Cloud Info, Region, Project                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Main Content Area:                                          │
│  • Resource lists                                            │
│  • Detail views                                              │
│  • Forms and dialogs                                         │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│ Status Bar: Messages, Shortcuts, Help                        │
└──────────────────────────────────────────────────────────────┘
```

## Navigation Fundamentals

### Main View Navigation

| Key | View | Description |
|-----|------|-------------|
| `d` | Dashboard | Main dashboard with resource overview |
| `s` | Servers | Compute instances (Nova) |
| `g` | Server Groups | Server group management |
| `n` | Networks | Network management (Neutron) |
| `e` | Security Groups | Security group management |
| `v` | Volumes | Volume management (Cinder) |
| `i` | Images | Image management (Glance) |
| `f` | Flavors | Flavor specifications |
| `t` | Topology | Network topology view |
| `h` | Health Dashboard | System health and monitoring |
| `u` | Subnets | Subnet management |
| `p` | Ports | Network port management |
| `r` | Routers | Router management |
| `l` | Floating IPs | Floating IP management |
| `b` | Barbican Secrets | Secrets management |
| `o` | Octavia | Load balancers |
| `j` | Swift | Object storage |
| `k` | Key Pairs | SSH key management |
| `q` | Configuration Profiles | Cloud configuration management |
| `z` | Advanced Search | Cross-service search |

### List Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `↑` | Move up | Previous item in list |
| `↓` | Move down | Next item in list |
| `PgUp` | Page up | Move up one page |
| `PgDn` | Page down | Move down one page |

### Detail View Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `Space` | View details | Open selected resource detail view |
| `Esc` | Go back | Return to list view or exit detail view |

## View-Specific Operations

## Navigation Behavior

### Detail View Navigation

- When in detail views, navigation keys return to parent list
- `Esc` always goes back to previous view
- Detail views support scrolling with arrow keys
- `Space` from list views opens detail view

### Search and Filtering

- Search applies to current view only
- Results are filtered in real-time
- `Esc` clears active search
- Search persists when navigating away and back

### View-Specific Operations

#### Common Operations (All Views)

| Key | Action | Description |
|-----|--------|-------------|
| `C` | Create | Create new resource (context-specific) |
| `Del` | Delete | Delete selected resource |
| `/` | Search | Search/filter current view |
| `r` | Refresh | Manual refresh of current view |
| `a` | Auto-refresh | Toggle auto-refresh |
| `c` | Cache | Purge cache and refresh |
| `?` | Help | Show context-sensitive help |
| `@` | About | Show about information |

#### Server Operations (Servers View)

| Key | Action | Description |
|-----|--------|-------------|
| `C` | Create server | Navigate to server creation form |
| `Del` | Delete server | Delete selected server |
| `S` | Start server | Start stopped server |
| `T` | Stop server | Stop running server |
| `R` | Restart server | Restart server |
| `L` | View logs | View server console logs |
| `P` | Create snapshot | Create server snapshot |
| `Z` | Resize server | Resize server to different flavor |

#### Context-Sensitive Actions

**Security Groups View**:

- `A` - Attach security group to servers
- `M` - Manage security group rules

**Networks View**:

- `A` - Manage network interfaces (attach to servers)

**Volumes View**:

- `A` - Attach volume to servers
- `P` - Create volume snapshot
- `M` - Manage volume snapshots

**Floating IPs View**:

- `A` - Manage floating IP server assignment

**Subnets View**:

- `A` - Attach subnet to router

**Topology View**:

- `Tab` - Cycle topology display modes
- `W` - Export topology

## Search and Filtering

### Quick Search

Press `/` to activate search:

- Type to search across visible fields
- Results update in real-time
- Clear search query or press `Esc` to clear

### Advanced Search

Press `z` to access advanced search:

- Cross-service resource search
- Smart filtering capabilities
- Search across all OpenStack services

## Form Navigation

### Create Forms

When creating resources (`C` key), navigate forms with:

- `↑/↓` - Move between form fields
- `Enter` - Enter edit mode for text fields
- `Esc` - Exit edit mode or cancel form
- `Tab` - Move to next field
- `Shift+Tab` - Move to previous field

### Text Field Editing

In edit mode (for name, description fields):

- Type normally to enter text
- `Esc` - Exit edit mode
- All printable characters supported
- Optimized for certificate/key pasting

## Auto-Refresh and Performance

### Auto-Refresh Control

- `a` - Toggle auto-refresh on/off
- `A` - Cycle refresh intervals (context-dependent)
- Refresh intervals: 5s, 10s, 30s, 60s
- `r` - Manual refresh
- `c` - Purge cache and refresh

### Performance Features

- Intelligent caching reduces API calls
- Optimized rendering for large lists
- Background data loading
- Scroll optimization for better performance

## Special Views

### Health Dashboard (`h`)

- Service status monitoring
- Performance metrics
- API response times
- System health scores
- Navigate with arrow keys

### Topology View (`t`)

- Visual network topology
- `Tab` - Cycle display modes
- `W` - Export topology
- Arrow keys for navigation

### Advanced Search (`z`)

- Cross-service search capabilities
- Filter across all OpenStack resources
- Smart search suggestions

## Complete Keyboard Reference

### Navigation Keys

| Key | Action |
|-----|--------|
| `d` | Dashboard |
| `s` | Servers |
| `g` | Server Groups |
| `n` | Networks |
| `e` | Security Groups |
| `v` | Volumes |
| `i` | Images |
| `f` | Flavors |
| `t` | Topology |
| `h` | Health Dashboard |
| `u` | Subnets |
| `p` | Ports |
| `r` | Routers |
| `l` | Floating IPs |
| `b` | Barbican Secrets |
| `o` | Octavia |
| `j` | Swift |
| `k` | Key Pairs |
| `q` | Configuration Profiles |
| `z` | Advanced Search |

### Action Keys

| Key | Action |
|-----|--------|
| `C` | Create resource |
| `Del` | Delete resource |
| `Space` | View details |
| `Esc` | Back/Cancel |
| `/` | Search |
| `r` | Refresh |
| `a` | Auto-refresh toggle |
| `c` | Cache purge |
| `?` | Help |
| `@` | About |

### Context Actions

| Key | Context | Action |
|-----|---------|--------|
| `A` | Security Groups | Attach to servers |
| `A` | Networks | Manage interfaces |
| `A` | Volumes | Attach to servers |
| `A` | Floating IPs | Manage assignment |
| `A` | Subnets | Attach to router |
| `M` | Security Groups | Manage rules |
| `M` | Volumes | Manage snapshots |
| `S` | Servers | Start server |
| `T` | Servers | Stop server |
| `R` | Servers | Restart server |
| `L` | Servers | View logs |
| `P` | Servers/Volumes | Create snapshot |
| `Z` | Servers | Resize server |
| `Tab` | Topology | Cycle modes |
| `W` | Topology | Export |

## Tips and Best Practices

### Efficient Navigation

1. **Master navigation keys** - `d` `s` `n` `v` etc. for instant view switching
2. **Use search frequently** - `/` to quickly find resources
3. **Learn context actions** - `A` key behavior changes per view
4. **Detail views** - `Space` for quick resource inspection

### Performance Optimization

1. **Enable auto-refresh** - `a` key for real-time updates
2. **Adjust refresh intervals** - Balance freshness vs. performance
3. **Use cache refresh** - `c` key when data seems stale
4. **Monitor with health dashboard** - `h` key for system status

### Working with Forms

1. **Use `C` for creation** - Works in all resource list views
2. **Master form navigation** - Arrow keys between fields
3. **Efficient text entry** - Optimized for certificate/key pasting
4. **Always use `Esc`** - Cancel operations cleanly

## Configuration Management

### Configuration Profiles (`q`)

- Manage different cloud configurations
- Switch between environments
- Save and load connection profiles
- Useful for dev/staging/production separation

### Export Features

- **Topology Export** - `W` key in topology view
- Export network diagrams and infrastructure maps
- JSON format support

## Troubleshooting

### Common Issues

1. **Slow performance** - Use `c` to purge cache and refresh
2. **Missing resources** - Use `r` for manual refresh
3. **Interface unresponsive** - Check connection with health dashboard (`h`)
4. **Form problems** - Use `Esc` to cancel and retry

### Getting Help

- `?` - Context-sensitive help
- `@` - About and version information
- Status bar shows current operation status
- Error messages appear in status bar

### Performance Monitoring

- Health dashboard (`h`) shows system status
- Real-time API performance metrics
- Cache hit rates and optimization stats
- Service availability monitoring

---

**Note**: This interface is optimized for keyboard navigation. All operations can be performed without mouse interaction for maximum efficiency in terminal environments.
