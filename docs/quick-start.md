# Quick Start Guide

Get up and running with Substation in 1 minute.

## Installation

Choose the installation method that works best for you:

### Option 1: Docker (Easiest)

```bash
docker run --volume ~/.config/openstack:/root/.config/openstack \
           --interactive \
           --tty \
           --env TERM \
           --rm \
           ghcr.io/cloudnull/substation/substation:latest
```

### Option 2: Pre-built Binary

```bash
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation
chmod +x substation
sudo mv substation /usr/local/bin/
```

### Option 3: Build from Source (requires Swift 6.1)

```bash
git clone https://github.com/cloudnull/substation.git
cd substation
~/.swiftly/bin/swift build -c release
.build/release/substation
```

For detailed installation instructions including prerequisites, verification, and troubleshooting, see the **[Installation Guide](installation/index.md)**.

## Configuration

### 1. Create clouds.yaml

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

### 2. Test Connection

```bash
substation --cloud mycloud
```

For detailed configuration including authentication methods, multiple clouds, and advanced options, see the **[Configuration Guide](configuration/index.md)**.

## First Steps

### Learning Command Input (Primary Navigation)

Substation uses **command input** as the primary navigation method. Press `:` to enter command input, then type your command.

**First Command:**

```text
:                    Press colon to enter command input
: <Tab>              Press Tab to see all available commands
: servers<Enter>     Type "servers" and press Enter to navigate
```

**Command Discovery:**

1. Press `:` to enter command input
2. Press `Tab` to see all available commands
3. Start typing (e.g., `serv`) and press `Tab` to auto-complete
4. Press `Enter` to execute the command
5. Press `Esc` to cancel

**Why Command Input?**

- **Discoverable**: Tab completion shows all options
- **Forgiving**: Fuzzy matching handles typos (`:servrs` suggests `:servers`)
- **Progressive**: Learn full names first, then shortcuts (`:servers` -> `:srv` -> `:s`)
- **Context-Aware**: Commands like `:create` adapt to your current view

### Navigation Basics

Use command input for all navigation:

| Command | Aliases | Action |
|---------|---------|--------|
| `:dashboard` | `:dash`, `:d` | Dashboard (start here) |
| `:servers` | `:srv`, `:s` | View Servers |
| `:networks` | `:net`, `:n` | View Networks |
| `:volumes` | `:vol`, `:v` | View Volumes |
| `:help` | `:?` | Show Help |
| `:quit` | `:exit`, `:q` | Quit |

### Common Operations

**View Resources:**

1. Enter command input: `:`
2. Navigate to servers: `servers<Enter>` (or press `Tab` to see all views)
3. Use `Up/Down` to navigate
4. Press `Space` for details
5. Press `Esc` to go back

**Search Resources:**

1. Press `/` for quick local search (within current view)
2. Type your query
3. Press `Esc` to clear

Or use advanced search:

1. `:search<Enter>` (or `:find<Enter>` or `:z<Enter>`)
2. Type your query
3. Press `Enter` to search across all services

**Refresh Data:**

- Refresh view: `:refresh<Enter>` (or `:reload<Enter>`)
- Purge cache: `:cache-purge<Enter>` (or `:clear-cache<Enter>` or `:cc<Enter>`)

## Essential Commands

### Navigation Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `:dashboard` | `:dash`, `:d` | Dashboard overview |
| `:servers` | `:srv`, `:s`, `:nova` | Servers (compute instances) |
| `:networks` | `:net`, `:n`, `:neutron` | Networks |
| `:subnets` | `:sub`, `:u` | Subnets |
| `:routers` | `:rtr`, `:r` | Routers |
| `:ports` | `:port`, `:p` | Network ports |
| `:floatingips` | `:fips`, `:fip`, `:l` | Floating IPs |
| `:securitygroups` | `:secgroups`, `:sec`, `:e` | Security groups |
| `:volumes` | `:vol`, `:v`, `:cinder` | Volumes (block storage) |
| `:images` | `:img`, `:i`, `:glance` | Images |
| `:flavors` | `:flav`, `:f` | Flavors (instance sizes) |
| `:keypairs` | `:keys`, `:kp`, `:k` | SSH keypairs |
| `:servergroups` | `:srvgrp`, `:sg`, `:g` | Server groups (affinity) |
| `:swift` | `:objectstorage`, `:obj`, `:j` | Object storage |
| `:barbican` | `:secrets`, `:b` | Secrets management |
| `:health` | `:healthdashboard`, `:h` | Health dashboard |
| `:performance` | `:metrics`, `:perf`, `:stats` | Performance metrics |

### Action Commands (Context-Aware)

| Command | Aliases | Action | Context |
|---------|---------|--------|---------|
| `:create` | `:new`, `:add` | Create resource | All resource lists |
| `:delete` | `:remove`, `:rm` | Delete selected | All resources |
| `:start` | `:boot` | Start server | Server view |
| `:stop` | `:shutdown` | Stop server | Server view |
| `:restart` | `:reboot` | Restart server | Server view |
| `:refresh` | `:reload` | Refresh view | All views |
| `:cache-purge` | `:clear-cache`, `:cc` | Purge all caches | All views |
| `:reload-all` | - | Reload all modules | All views (advanced) |

### Global Actions

| Key | Command Equivalent | Action |
|-----|-------------------|--------|
| `Up/Down` | - | Navigate lists |
| `Space` | - | View details |
| `/` | - | Local search |
| `?` | `:help` | Context help |
| `Esc` | - | Go back/Cancel |

## Common Workflows

### List Your Servers

1. Launch Substation: `substation --cloud mycloud`
2. Enter command input: `:`
3. Navigate: `servers<Enter>` (or `srv<Enter>` or `s<Enter>`)
4. Use `Up/Down` to navigate
5. Press `Space` for server details

### Create a Resource

1. Navigate to view: `:servers<Enter>`
2. Create resource: `:create<Enter>`
3. Fill in form fields
4. Submit with `Enter`

### Search Across Services

1. Open search: `:search<Enter>` (or `:find<Enter>` or `:z<Enter>`)
2. Type your query (e.g., "prod")
3. Press `Enter`
4. Results from all services appear

### Refresh Data

1. Refresh view: `:refresh<Enter>`
2. Or purge cache: `:cache-purge<Enter>` (or `:cc<Enter>`)

## Troubleshooting

### Connection Issues

**Problem**: Can't connect to OpenStack

**Solution**: Verify auth_url includes `/v3`:

```yaml
# Correct
auth_url: https://keystone.example.com:5000/v3  [OK]

# Wrong
auth_url: https://keystone.example.com:5000     [X]
```

### Slow Performance

**Problem**: Everything is slow

**Solution**: Enable wiretap to diagnose:

```bash
substation --cloud mycloud --wiretap
tail -f ~/substation.log | grep "ms)"
```

### Stale Data

**Problem**: Resources not showing up

**Solution**: `:cache-purge<Enter>` to purge cache, then `:refresh<Enter>` to reload

## Next Steps

- **[Installation Guide](installation/index.md)** - Detailed installation options and troubleshooting
- **[Configuration Guide](configuration/index.md)** - Advanced clouds.yaml setup and authentication
- **[Getting Started](getting-started/index.md)** - Learn the concepts and first steps
- **[Navigation Guide](reference/operators/keyboard-shortcuts.md)** - Master all keyboard shortcuts
- **[Common Workflows](reference/operators/workflows.md)** - Learn everyday operations
- **[Troubleshooting](troubleshooting/index.md)** - Detailed problem solving

## Getting Help

- Press `?` at any time for context-aware help
- Check **[FAQ](reference/faq.md)** for common questions
- Report issues on **[GitHub](https://github.com/cloudnull/substation/issues)**
