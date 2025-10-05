# Getting Started with Substation

Welcome to Substation! This guide will help you understand the concepts and get started with the OpenStack Terminal UI.

## Overview

Substation provides a powerful terminal-based interface for managing OpenStack infrastructure. Whether you're managing a small development cloud or a large production environment, Substation streamlines your operational workflows.

![Substation Dashboard](../assets/substation-dash.png)

## Installation and Configuration

Before using Substation, you'll need to install it and configure your OpenStack credentials:

- **[Installation Guide](../installation/index.md)** - Install via Docker, pre-built binary, or build from source
- **[Configuration Guide](../configuration/index.md)** - Set up clouds.yaml with your OpenStack credentials

### Quick Install

#### Using Docker

```bash
# Docker (easiest)
docker run --volume ~/.config/openstack:/root/.config/openstack \
           --interactive --tty --env TERM --rm \
           ghcr.io/cloudnull/substation/substation:latest
```

#### Using Pre-Built Binary

```bash
# Or download binary
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation
chmod +x substation
sudo mv substation /usr/local/bin/
```

### Quick Configuration

```bash
mkdir -p ~/.config/openstack
cat > ~/.config/openstack/clouds.yaml << 'EOF'
clouds:
  mycloud:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      username: operator
      password: secret
      project_name: operations
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne
EOF
chmod 600 ~/.config/openstack/clouds.yaml
```

See the guides above for complete details on all installation methods, authentication options, and configuration settings.

## First Steps

### 1. Launch Substation

Start Substation with your configured cloud:

```bash
substation --cloud mycloud
```

When you start Substation, you'll see the main dashboard showing an overview of your OpenStack resources:

![Substation Startup](../assets/substation-startup.png)

**Initial Loading:**

- Phase 1: Critical resources (servers, networks, flavors) load first (~1s)
- Phase 2: Secondary resources (volumes, images, keypairs) load next (~2s)
- Phase 3: Expensive resources (ports, security groups) load in background (~5s)

### 2. Understanding the Dashboard

The dashboard shows:

- **Resource Summary**: Count of servers, networks, volumes, images
- **Recent Activity**: Latest changes in your cloud
- **Health Status**: OpenStack service health indicators
- **Performance Metrics**: Cache hit rate, API response times

### 3. Navigate Between Views

Press single keys to switch between resource views:

| Key | View | Description |
|-----|------|-------------|
| `d` | Dashboard | Resource overview and health |
| `s` | Servers | Compute instances (VMs) |
| `n` | Networks | Virtual networks |
| `v` | Volumes | Block storage |
| `i` | Images | OS images and snapshots |
| `f` | Flavors | Instance sizes/types |
| `g` | Server Groups | Anti-affinity groups |
| `e` | Security Groups | Firewall rules |
| `u` | Subnets | Network subnets |
| `p` | Ports | Network interfaces |
| `r` | Routers | Virtual routers |
| `l` | Floating IPs | Public IP addresses |
| `b` | Barbican | Secrets management |
| `o` | Octavia | Load balancers |
| `j` | Swift | Object storage |

### 4. Working with Resource Lists

**Navigate Lists:**

```text
↑/↓ or j/k    Move selection up/down
Page Up/Down  Scroll by page
Home/End      Jump to start/end
```

**View Details:**

1. Navigate to any resource (e.g., press `s` for servers)
2. Use arrow keys to select a server
3. Press `Space` or `Enter` to view full details
4. Press `Esc` to return to the list

![Substation Image Show](../assets/substation-image-show.png)

### 5. Searching for Resources

**Local Search (fast, filters current view):**

```text
/ (slash)     Start local search
Type query    Results filter as you type
Esc           Clear search
```

**Cross-Service Search (searches all services):**

```text
z             Open advanced search
Type query    Searches Nova, Neutron, Cinder, Glance, Keystone, Swift
Enter         Execute search (< 500ms typical)
```

### 6. Refreshing Data

**Manual Refresh:**

```text
r             Refresh current view (uses cache if available)
c             Purge ALL caches and force fresh data from API
```

**Note:** Pressing `c` clears L1, L2, and L3 caches. Next operations will be slower while cache rebuilds.

### 7. Creating Resources

#### Example: Creating a Server

1. Press `s` to view servers
2. Press `n` for "New Server" (or follow on-screen prompts)
3. Fill in the form:
   - Server name
   - Select flavor (instance size)
   - Select image (OS)
   - Select network(s)
   - Optional: Add security groups, keypairs
4. Press `Enter` to create
5. Watch real-time status as server builds

##### Other Creation Workflows

- **Networks**: Press `n` in network view
- **Volumes**: Press `n` in volume view
- **Security Groups**: Press `n` in security group view

## Essential Keyboard Shortcuts

### Global Commands

| Key | Action | Description |
|-----|--------|-------------|
| `?` | Show Help | Context-aware help for current view |
| `q` | Quit | Exit Substation |
| `r` | Refresh | Refresh current view data |
| `c` | Cache Purge | Clear ALL caches (use when data is stale) |
| `z` | Advanced Search | Cross-service search |
| `d` | Dashboard | Return to dashboard |

### List Navigation

| Key | Action | Alternative |
|-----|--------|-------------|
| `↑/↓` | Navigate up/down | `j/k` (vim-style) |
| `Page Up/Down` | Scroll by page | - |
| `Home/End` | Jump to start/end | `g/G` (vim-style) |
| `Space` | View details | `Enter` |
| `/` | Local search/filter | - |
| `Esc` | Go back | `q` in detail view |

### Resource Management

| Key | Action | Context |
|-----|--------|---------|
| `n` | New/Create | Resource lists |
| `d` | Delete | Selected resource |
| `e` | Edit/Modify | Selected resource |
| `a` | Attach/Associate | Volumes, networks |
| `x` | Detach/Disassociate | Volumes, networks |

## Common Workflows

### Workflow 1: List Your Servers

```bash
# Launch Substation
substation --cloud mycloud

# Press 's' to view servers
# Use ↑/↓ to navigate
# Press Space to view details
# Press Esc to go back
```

### Workflow 2: Create a New Server

```bash
# Launch Substation
substation --cloud mycloud

# Press 's' for servers
# Press 'n' for new server
# Fill in:
#   - Name: web-server-01
#   - Flavor: m1.medium
#   - Image: Ubuntu 22.04
#   - Network: private-network
# Press Enter to create
```

### Workflow 3: Search Across All Resources

```bash
# Launch Substation
substation --cloud mycloud

# Press 'z' for advanced search
# Type: "prod"
# Press Enter
# Results show all resources matching "prod" from:
#   - Servers (Nova)
#   - Networks (Neutron)
#   - Volumes (Cinder)
#   - Images (Glance)
#   - Users (Keystone)
#   - Containers (Swift)
```

### Workflow 4: Force Fresh Data

```bash
# When your data looks stale or wrong
# Press 'c' to purge ALL caches
# Press 'r' to refresh current view
# Fresh data loaded from OpenStack API (slower, but accurate)
```

## Troubleshooting

If you encounter issues, consult the comprehensive troubleshooting guide:

- **[Troubleshooting Guide](../troubleshooting/index.md)** - Solutions to common problems

**Quick Troubleshooting Tips:**

**Authentication Failed:**

- Verify auth_url includes `/v3`
- Check domain fields are present
- Test with: `substation --cloud mycloud --wiretap`

**Slow Performance:**

- Most likely your OpenStack API is slow, not Substation
- Enable wiretap to measure: `substation --cloud mycloud --wiretap`
- Check logs: `tail -f ~/substation.log | grep "ms)"`

**Stale Data:**

- Press `c` to purge all caches
- Press `r` to refresh current view

For detailed troubleshooting, connection issues, performance debugging, and more, see the **[Troubleshooting Guide](../troubleshooting/index.md)**.

## Next Steps

Now that you're up and running, explore:

- **[Navigation Guide](../guides/operators/keyboard-shortcuts.md)** - Master all keyboard shortcuts
- **[Common Workflows](../guides/operators/workflows.md)** - Everyday operations and best practices
- **[OpenStack Integration](../reference/openstack/index.md)** - Which OpenStack services are supported
- **[Performance](../performance/index.md)** - Tuning cache settings for your environment
- **[Architecture](../architecture/index.md)** - Understanding how Substation works
- **[Troubleshooting](../troubleshooting/index.md)** - Solutions to common problems

## Key Concepts

Understanding these concepts will help you use Substation effectively:

- **[Caching](../concepts/caching.md)** - How the multi-level cache reduces API calls by 60-80%
- **[Search](../concepts/search.md)** - Local search vs. cross-service advanced search
- **[Security](../concepts/security.md)** - How credentials are protected and encrypted
- **[Features](../concepts/features.md)** - Complete feature overview

## Getting Help

- **Built-in Help**: Press `?` at any time for context-aware help
- **Documentation**: Complete guides in this documentation site
- **GitHub Issues**: [Report bugs and request features](https://github.com/cloudnull/substation/issues)
- **FAQ**: [Common questions](../reference/faq.md)
- **Logs**: Enable `--wiretap` and check `~/substation.log` for debugging
