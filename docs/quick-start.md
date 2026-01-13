# Quick Start Guide

You have 60 seconds. Let's use them wisely.

By the end of this page, you'll have Substation running and navigating your OpenStack cloud. No theory, no deep dives - just the fastest path from zero to operational.

## Installation

**Recommended: Docker** (works everywhere, zero dependencies)

```bash
docker run --volume ~/.config/openstack:/root/.config/openstack \
           --interactive \
           --tty \
           --env TERM \
           --rm \
           ghcr.io/cloudnull/substation/substation:latest
```

### Alternative: Pre-built Binary

```bash
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation
chmod +x substation
sudo mv substation /usr/local/bin/
```

**Alternative: Build from Source** (requires Swift 6.1)

```bash
git clone https://github.com/cloudnull/substation.git
cd substation
~/.swiftly/bin/swift build -c release
.build/release/substation
```

Need more details? See the **[Installation Guide](installation/index.md)** for prerequisites, verification, and platform-specific instructions.

## Configuration

Create a minimal `clouds.yaml` with your OpenStack credentials:

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

Test your connection:

```bash
substation --cloud mycloud
```

If you're connecting, you're ready. For advanced authentication methods, multiple clouds, or troubleshooting, see the **[Configuration Guide](configuration/index.md)**.

## Launch and Navigate

Substation uses command input as its primary interface. Press `:` (colon) to enter command mode, then type your command. Think of it like Vim - deliberate, discoverable, and fast once you learn the pattern.

### Your First Three Commands

**1. Start command input and discover all commands:**

```text
:                    Press colon to enter command input
: <Tab>              Press Tab to see all available commands
```

Tab completion shows you everything available. This is your map.

**2. Navigate to your servers:**

```text
: servers<Enter>     Type "servers" and press Enter
```

You're now viewing your compute instances. Use `Up/Down` arrows to navigate the list, press `Space` to view details of the selected server, and press `Esc` to go back.

**3. Return to the dashboard:**

```text
: dashboard<Enter>   Or use the shortcut: :d<Enter>
```

The dashboard gives you an overview of your cloud's resources and health.

### Why Command Input?

Command input is discoverable through Tab completion, forgiving with fuzzy matching (`:servrs` suggests `:servers`), and progressive - learn full names first, then shortcuts (`:servers` becomes `:srv` or just `:s`). Commands like `:create` adapt to your current view, so you're always working in context.

### Essential Navigation

All navigation happens through command input. Here are the commands you'll use most:

**Primary Views:**

- `:dashboard` (`:d`) - Start here for cloud overview
- `:servers` (`:srv`, `:s`) - Compute instances
- `:networks` (`:net`, `:n`) - Network resources
- `:volumes` (`:vol`, `:v`) - Block storage
- `:images` (`:img`, `:i`) - Available images
- `:flavors` (`:flav`, `:f`) - Instance sizes

**Network Details:**

- `:subnets` (`:sub`, `:u`) - Network subnets
- `:routers` (`:rtr`, `:r`) - Virtual routers
- `:ports` (`:port`, `:p`) - Network ports
- `:floatingips` (`:fips`, `:l`) - Floating IPs
- `:securitygroups` (`:sec`, `:e`) - Security groups

**Supporting Resources:**

- `:keypairs` (`:keys`, `:k`) - SSH keypairs
- `:servergroups` (`:sg`, `:g`) - Server affinity groups
- `:swift` (`:obj`, `:j`) - Object storage
- `:barbican` (`:secrets`, `:b`) - Secrets management

**System Views:**

- `:health` (`:h`) - Health dashboard
- `:performance` (`:perf`, `:stats`) - Performance metrics
- `:help` (`:?`) - Context-aware help
- `:quit` (`:q`) - Exit application

### Common Operations

**Search locally** within your current view by pressing `/`, typing your query, and pressing `Esc` to clear. For searching across all services, use `:search<Enter>` (or `:find<Enter>` or `:z<Enter>`), type your query, and press `Enter`.

**Create resources** by navigating to the appropriate view (`:servers<Enter>`), entering `:create<Enter>`, filling in the form, and submitting with `Enter`.

**Refresh data** with `:refresh<Enter>` to reload the current view, or `:cache-purge<Enter>` (shortcut `:cc<Enter>`) to purge all cached data and force a complete refresh.

**Context-aware actions** adapt to where you are. The `:create` command creates a server in the servers view, a network in the networks view, and so on. Similarly, `:delete` removes the selected resource, `:start` and `:stop` control server power states, and `:restart` reboots servers.

### Global Navigation Keys

While command input is primary, these keys work everywhere:

- `Up/Down` arrows navigate lists
- `Space` views details of selected item
- `/` opens local search
- `?` shows context-aware help
- `Esc` goes back or cancels current action

## Quick Workflow Examples

**List and inspect your servers:**
Launch Substation, press `:`, type `servers<Enter>`, navigate with `Up/Down`, and press `Space` to view details.

**Find a resource across all services:**
Press `:`, type `search<Enter>`, type your query (like "production"), press `Enter`, and browse results from all OpenStack services.

**Create a new network:**
Navigate with `:networks<Enter>`, create with `:create<Enter>`, fill the form, and submit with `Enter`.

**Force data refresh:**
If something looks stale, use `:cc<Enter>` to purge the cache, then `:refresh<Enter>` to reload.

## Next Steps

- **[Installation Guide](installation/index.md)** - Complete installation options and verification
- **[Configuration Guide](configuration/index.md)** - Advanced authentication and multi-cloud setup
- **[Getting Started](getting-started/index.md)** - Concepts and deeper first steps
- **[Navigation Guide](reference/operators/keyboard-shortcuts.md)** - Master all keyboard shortcuts
- **[Common Workflows](reference/operators/workflows.md)** - Everyday operations and patterns
- **[Troubleshooting](troubleshooting/index.md)** - When things go wrong

Press `?` at any time for context-aware help, or report issues on **[GitHub](https://github.com/cloudnull/substation/issues)**.
