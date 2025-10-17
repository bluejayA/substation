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

### 3. Learn Command Input (Primary Navigation)

Substation emphasizes **command-based navigation** as the primary method. This approach is discoverable, forgiving, and teaches you the interface as you learn.

**Your First Command:**

```text
:                    Press colon to enter command input
: <Tab>              Press Tab to see all available commands
: servers<Enter>     Type "servers" and press Enter to navigate
```

**Command Discovery Features:**

1. **Tab Completion**: Press `:` then `Tab` to see all available commands
2. **Auto-Complete**: Type `:serv<Tab>` to complete to `:servers`
3. **Fuzzy Matching**: `:servrs` suggests `:servers` (handles typos)
4. **Command History**: Use `Up/Down` arrows to recall previous commands
5. **Multiple Aliases**: `:servers`, `:srv`, `:s`, `:nova` all work

**Progressive Learning Path:**

1. **Week 1**: Use full command names (`:servers`, `:networks`, `:volumes`)
   - Discoverable and self-documenting
   - Tab completion teaches you the commands

2. **Week 2**: Learn common aliases (`:srv`, `:net`, `:vol`)
   - Faster typing with shorter names
   - Still clear what you're doing

3. **Week 3**: Try short aliases (`:s`, `:n`, `:v`)
   - Very fast navigation
   - Requires some memorization

4. **Week 4+**: Graduate to single-key shortcuts (`s`, `n`, `v`)
   - Muscle memory speed for power users
   - Optional - use only when comfortable

### 4. Navigate Between Views

**Command-Based Navigation (Recommended):**

| Command | Aliases | Description |
|---------|---------|-------------|
| `:dashboard` | `:dash`, `:d` | Resource overview and health |
| `:servers` | `:srv`, `:s`, `:nova` | Compute instances (VMs) |
| `:networks` | `:net`, `:n`, `:neutron` | Virtual networks |
| `:volumes` | `:vol`, `:v`, `:cinder` | Block storage |
| `:images` | `:img`, `:i`, `:glance` | OS images and snapshots |
| `:flavors` | `:flav`, `:f` | Instance sizes/types |
| `:servergroups` | `:srvgroups`, `:g` | Anti-affinity groups |
| `:securitygroups` | `:secgroups`, `:sg`, `:e` | Firewall rules |
| `:subnets` | `:sub`, `:u` | Network subnets |
| `:ports` | `:p` | Network interfaces |
| `:routers` | `:rtr`, `:r` | Virtual routers |
| `:floatingips` | `:fips`, `:l` | Public IP addresses |
| `:barbican` | `:secrets`, `:b` | Secrets management |
| `:octavia` | `:loadbalancers`, `:lbs`, `:o` | Load balancers |
| `:swift` | `:objects`, `:j` | Object storage |

### 5. Working with Resource Lists

**Navigate Lists:**

```text
↑/↓ or j/k    Move selection up/down
Page Up/Down  Scroll by page
Home/End      Jump to start/end
```

**View Details:**

1. Navigate to resource view: `:servers<Enter>`
2. Use arrow keys to select a server
3. Press `Space` or `Enter` to view full details
4. Press `Esc` to return to the list

![Substation Image Show](../assets/substation-image-show.png)

### 6. Searching for Resources

**Local Search (fast, filters current view):**

```text
/ (slash)     Start local search
Type query    Results filter as you type
Esc           Clear search
```

**Cross-Service Search:**

```text
:search<Enter>     Open advanced search (or :find<Enter> or :z<Enter>)
Type query         Searches Nova, Neutron, Cinder, Glance, Keystone, Swift
Enter              Execute search (< 500ms typical)
```

### 7. Refreshing Data

**Command-Based:**

```text
:refresh<Enter>         Refresh current view (uses cache if available)
:cache-purge<Enter>     Purge ALL caches and force fresh data from API
```

**Note:** Using `:cache-purge` clears L1, L2, and L3 caches. Next operations will be slower while cache rebuilds.

### 8. Creating Resources

#### Example: Creating a Server

1. Navigate to servers: `:servers<Enter>`
2. Create server: `:create<Enter>` (or `:new<Enter>` or `:add<Enter>`)
3. Fill in the form:
   - Server name
   - Select flavor (instance size)
   - Select image (OS)
   - Select network(s)
   - Optional: Add security groups, keypairs
4. Press `Enter` to create
5. Watch real-time status as server builds

#### Context-Aware Action Commands

These commands adapt to your current view:

| Command | Aliases | Action | Context |
|---------|---------|--------|---------|
| `:create` | `:new`, `:add` | Create resource | All resource lists |
| `:delete` | `:remove`, `:rm` | Delete selected | All resources |
| `:start` | `:boot` | Start server | Server view |
| `:stop` | `:shutdown` | Stop server | Server view |
| `:restart` | `:reboot` | Restart server | Server view |
| `:attach` | `:connect` | Attach volume/network | Volume/Network view |
| `:detach` | `:disconnect` | Detach volume/network | Volume/Network view |
| `:snapshot` | `:snap` | Create snapshot | Server/Volume view |

#### Other Creation Workflows

- **Networks**: `:networks<Enter>` then `:create<Enter>`
- **Volumes**: `:volumes<Enter>` then `:create<Enter>`
- **Security Groups**: `:securitygroups<Enter>` then `:create<Enter>`

## Essential Commands Reference

### Global Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `:help` | `:?` | Context-aware help for current view |
| `:quit` | `:exit`, `:q` | Exit Substation |
| `:refresh` | `:reload` | Refresh current view data |
| `:cache-purge` | `:clear-cache` | Clear ALL caches (use when data is stale) |
| `:search` | `:find`, `:z` | Cross-service search |
| `:dashboard` | `:dash`, `:d` | Return to dashboard |

### List Navigation

| Key | Action | Alternative |
|-----|--------|-------------|
| `↑/↓` | Navigate up/down | `j/k` (vim-style) |
| `Page Up/Down` | Scroll by page | - |
| `Home/End` | Jump to start/end | `g/G` (vim-style) |
| `Space` | View details | `Enter` |
| `/` | Local search/filter | - |
| `Esc` | Go back | - |

### Resource Management

| Command | Aliases | Context |
|---------|---------|---------|
| `:create` | `:new`, `:add` | Create resource in any list |
| `:delete` | `:remove`, `:rm` | Delete selected resource |
| `:attach` | `:connect` | Attach volume/network |
| `:detach` | `:disconnect` | Detach volume/network |

## Common Workflows

### Workflow 1: List Your Servers

```bash
# Launch Substation
substation --cloud mycloud

# Enter command input and navigate to servers
:servers<Enter>     # Or :srv<Enter> or :s<Enter>

# Use ↑/↓ to navigate
# Press Space to view details
# Press Esc to go back
```

### Workflow 2: Create a New Server

```bash
# Launch Substation
substation --cloud mycloud

# Navigate to servers and create
:servers<Enter>     # Navigate to servers view
:create<Enter>      # Open create server form

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

# Open search
:search<Enter>      # Or :find<Enter> or :z<Enter>

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

### Workflow 4: Manage Server Lifecycle

```bash
# Start server
:servers<Enter>     # Navigate to servers
# Select stopped server with ↑/↓
:start<Enter>       # Start server (or :boot<Enter>)

# Stop server
# Select running server with ↑/↓
:stop<Enter>        # Stop server (or :shutdown<Enter>)

# Restart server
# Select running server with ↑/↓
:restart<Enter>     # Restart server (or :reboot<Enter>)

# Delete server
# Select server to delete with ↑/↓
:delete<Enter>      # Delete server (confirmation required)
```

### Workflow 5: Force Fresh Data

```bash
# When your data looks stale or wrong
:cache-purge<Enter>  # Purge ALL caches (or :clear-cache<Enter> or :cc<Enter>)
:refresh<Enter>      # Refresh current view (or :reload<Enter>)
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

- Use `:cache-purge<Enter>` (or `:cc<Enter>`) to purge all caches
- Use `:refresh<Enter>` (or `:reload<Enter>`) to refresh current view

For detailed troubleshooting, connection issues, performance debugging, and more, see the **[Troubleshooting Guide](../troubleshooting/index.md)**.

## Next Steps

Now that you're up and running, explore:

- **[Navigation Guide](../reference/operators/keyboard-shortcuts.md)** - Master all keyboard shortcuts
- **[Common Workflows](../reference/operators/workflows.md)** - Everyday operations and best practices
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
