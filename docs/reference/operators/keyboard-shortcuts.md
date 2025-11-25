# Keyboard Shortcuts and Navigation Guide

Complete keyboard shortcut reference and navigation guide for Substation. This is your quick reference. Print it, bookmark it, tattoo it on your arm. Whatever helps you remember. Master keyboard-driven navigation -- your mouse is for the weak.

## Navigation Philosophy

Substation uses **command-driven navigation** as the modern, primary interface:

**Command Input (`:command`)** - The primary navigation method

- Type `:` to enter command mode
- Type the command name (`:servers`, `:networks`, etc.)
- Press Enter to navigate
- Tab completion and fuzzy matching available
- Discoverable (press `:` then Tab to see all commands)
- Multiple aliases support learning (`:servers`, `:srv`, `:s`)
- Context-aware commands like `:create` adapt to your current view

**Context Actions (Uppercase Keys)** - Secondary, view-specific actions

- Uppercase keys (C, D, S, T, R, etc.) trigger actions
- Only available in relevant views
- Examples: `C` for Create, `S` for Start Server, `R` for Restart

**IMPORTANT**: Lowercase letter keys (a-z) do NOT navigate between views.
They will display a helpful message: "Use commands for navigation (type : and press Tab for suggestions)"

**Everyone uses command input** -- It's fast, discoverable, and works everywhere.
Press `:` then Tab to see all available commands. There are no "shortcuts to memorize" -- the commands ARE the interface.

## Command Input (Primary Navigation)

Press `:` to enter command input -- the primary way to navigate and execute actions in Substation.

### How Command Input Works

```text
:                    Press colon to enter command input
: <Tab>              Show all available commands
: servers <Enter>    Navigate to servers view
: create <Enter>     Create resource (context-aware)
: start <Enter>      Start selected server (in server view)
<Esc>                Cancel command input
```

### Command Discovery Features

**Tab Completion:**

- Press `:` then `Tab` to see all available commands
- Type `:serv` then `Tab` to complete to `:servers`
- Press `Tab` multiple times to cycle through matches

**Fuzzy Matching:**

- `:servrs` suggests `:servers` (handles typos)
- `:netwrk` suggests `:networks`
- `:vols` suggests `:volumes`

**Command History:**

- Press `Up Arrow` to cycle through previous commands
- Press `Down Arrow` to cycle forward
- History persists between sessions

**Multiple Aliases:**

- `:servers`, `:srv`, `:s`, `:nova` all work
- `:networks`, `:net`, `:n`, `:neutron` all work
- `:volumes`, `:vol`, `:v`, `:cinder` all work

### Navigation Commands

| Command | Aliases | Action |
|---------|---------|--------|
| `:dashboard` | `:dash`, `:d` | Navigate to dashboard |
| `:servers` | `:server`, `:srv`, `:s`, `:nova` | Navigate to servers view |
| `:networks` | `:network`, `:net`, `:n`, `:neutron` | Navigate to networks view |
| `:volumes` | `:volume`, `:vol`, `:v`, `:cinder` | Navigate to volumes view |
| `:images` | `:image`, `:img`, `:i`, `:glance` | Navigate to images view |
| `:flavors` | `:flavor`, `:flv`, `:f`, `:novaflavors`, `:novaflavor` | Navigate to flavors view |
| `:security groups` | `:securitygroups`, `:securitygroup`, `:secgroups`, `:secgroup`, `:sec`, `:e`, `:neutronsecuritygroups`, `:neutronsecuritygroup` | Navigate to security groups |
| `:server groups` | `:servergroups`, `:servergroup`, `:srvgrp`, `:sg`, `:g`, `:novaservergroups`, `:novaservergroup` | Navigate to server groups |
| `:subnets` | `:subnet`, `:sub`, `:u`, `:neutronsubnets`, `:neutronsubnet` | Navigate to subnets view |
| `:ports` | `:port`, `:p`, `:neutronports`, `:neutronport` | Navigate to ports view |
| `:routers` | `:router`, `:rtr`, `:r`, `:neutronrouters`, `:neutronrouter` | Navigate to routers view |
| `:floatingips` | `:floatingip`, `:fips`, `:fip`, `:floating`, `:l`, `:neutronfloatingips`, `:neutronfloatingip` | Navigate to floating IPs |
| `:keypairs` | `:keypair`, `:keys`, `:key`, `:kp`, `:k`, `:novakeypairs`, `:novakeypair` | Navigate to key pairs |
| `:secrets` | `:secret`, `:barbican`, `:b` | Navigate to secrets (Barbican) |
| `:object storage` | `:swift`, `:objectstorage`, `:objects`, `:obj`, `:j` | Navigate to object storage (Swift) |
| `:operations` | `:ops`, `:background`, `:tasks` | Navigate to Swift background operations |
| `:performance` | `:metrics`, `:perf`, `:stats` | Navigate to performance metrics |
| `:health` | `:healthdashboard`, `:h` | Navigate to health dashboard |
| `:search` | `:find`, `:z` | Navigate to advanced search |
| `:volume archives` | `:archives`, `:archive`, `:arch`, `:m`, `:volumearchives`, `:volumearchive`, `:cinderbackups`, `:cinderbackup` | Navigate to volume archives (backups) |
| `:help` | `:?` | Show help |
| `:about` | - | Show about/version information |

### Discovery Commands

These commands help you learn Substation:

| Command | Aliases | Action |
|---------|---------|--------|
| `:tutorial` | `:walkthrough` | Show interactive tutorial |
| `:shortcuts` | `:cheatsheet` | Show keyboard shortcuts reference |
| `:examples` | `:workflows` | Show example workflows |
| `:welcome` | `:intro` | Show welcome screen |

### Action Commands (Context-Aware)

These commands adapt to your current view:

| Command | Aliases | Action | Context |
|---------|---------|--------|---------|
| `:create` | `:new`, `:add` | Create resource | All resource lists |
| `:delete` | `:remove`, `:rm`, `:del` | Delete selected resource | All resources |
| `:start` | `:boot`, `:power-on` | Start server | Server view |
| `:stop` | `:shutdown`, `:power-off` | Stop server | Server view |
| `:restart` | `:reboot` | Restart server | Server view |
| `:refresh` | `:reload` | Refresh current view | All views |
| `:clear-cache` | `:clearcache`, `:cc` | Purge all caches | All views |
| `:reload-all` | - | Reload all modules | All views (advanced) |
| `:manage` | `:edit` | Manage resource | Context-specific |

### System Commands

| Command | Aliases | Action | Context |
|---------|---------|--------|---------|
| `:quit` | `:exit`, `:q` | Quit Substation | Main view |
| `:commands` | `:list` | Show available commands | All views |
| `:help` | `:?` | Show help | All views |

**Note:** The following action commands mentioned in earlier versions are NOT currently implemented:

- `:attach` / `:connect` - Use `:manage` instead in Volume/Network views
- `:detach` / `:disconnect` - Use `:manage` instead in Volume/Network views
- `:snapshot` / `:snap` - Not available via command mode (use keyboard shortcuts)
- `:resize` - Not available via command mode (use keyboard shortcuts)
- `:console` / `:logs` - Not available via command mode (use keyboard shortcuts)

### Context Commands

| Command | Action | Example |
|---------|--------|---------|
| `:ctx` | List available clouds | Lists all clouds from `clouds.yaml` |
| `:ctx <cloud>` | Switch to cloud | `:ctx production` |
| `:context <cloud>` | Switch to cloud | `:context staging` (alias for `:ctx`) |

**Cloud Context Switching:**

Switch between OpenStack clouds defined in your `clouds.yaml`:

```bash
# List available clouds
:ctx

# Switch to a specific cloud
:ctx production
:ctx staging
:ctx dev

# Tab completion for cloud names
:ctx pro<Tab>  # Completes to :ctx production
:ctx <Tab>     # Shows all available clouds
```

### Command Input Tips

1. **Start with Tab** - Press `:` then `Tab` to discover all commands
2. **Use fuzzy matching** - Don't worry about typos, commands will suggest corrections
3. **Learn aliases progressively** - Start with full names (`:servers`), graduate to shortcuts (`:s`)
4. **Context matters** - `:create` does different things in different views
5. **History saves time** - Use Up/Down arrows to recall previous commands

## Quick Reference Card

Print this and tape it to your monitor (we won't judge).

### Context Action Keys

These keys trigger actions in relevant views. Note: Most actions use lowercase keys, with uppercase reserved for potentially dangerous operations.

| Key | Action | Available In |
|-----|--------|--------------|
| `c` | Create new resource | FloatingIPs, Ports, Servers (use `:create` command in other views) |
| `Del` or `d` | Delete selected resource | Volumes (archives), Swift (containers/objects), FloatingIPs, Ports |
| `s` | Start server | Server views |
| `S` | Stop server | Server views (uppercase = potentially destructive) |
| `r` | Reboot server | Server views |
| `R` | Resize server | Server views (uppercase = significant change) |
| `a` | Attach/Assign | Volumes (attach to server), SecurityGroups (server attachments), FloatingIPs (server assignment), Ports (server assignment) |
| `m` | Manage attachments | Volumes (manage server attachments) |
| `p` | Port/Pair management | FloatingIPs (port assignment), Ports (allowed address pairs) |
| `r` | Manage rules | SecurityGroups |
| `A` | Cycle auto-refresh interval | All views (5s/10s/30s/60s/off) |
| `n` | Create snapshot | Server views |
| `b` | Create backup | Volume views |
| `l` | View console logs | Server views |
| `c` | Open console | Server views (context-dependent with create) |

**Note**: Navigation is done via command mode (`:servers`, `:networks`, etc.), NOT single lowercase keys.

#### Global Actions

| Key | Command Equivalent | Action | Notes |
|-----|-------------------|--------|-------|
| `?` | `:help` | Show Help | Context-aware -- changes based on current view |
| `@` | - | About | Version info, credits |
| `/` | - | Search/Filter | Instant local filtering, no API calls |
| `:` | - | Command Input | PRIMARY navigation method (see Command Input section) |
| `Ctrl-X` | - | Multi-Select Mode | Toggle multi-select mode for bulk operations |
| `Esc` | - | Back/Cancel | Works everywhere, exits everything |
| `q` | `:quit` | Quit | From main view only |

**Note**: Cache purge and refresh commands are NOT available as single-key shortcuts. Use `:clear-cache` or `:cc` for cache purge, and `:refresh` or `:reload` for refresh.

#### List Navigation

| Key | Action | Vim Users Note |
|-----|--------|----------------|
| `^` or `k` | Move up | Vim muscle memory works |
| `v` or `j` | Move down | Vim muscle memory works |
| `Page Up` | Scroll up one page | - |
| `Page Down` | Scroll down one page | - |
| `Home` or `g` | Jump to top | Vim-style |
| `End` or `G` | Jump to bottom | Vim-style |
| `Space` | View details (or toggle selection in multi-select) | Deep dive into a resource |
| `Enter` | View details | Same as Space, because options |

#### Multi-Select Mode

| Key | Action | Notes |
|-----|--------|-------|
| `Ctrl-X` | Toggle multi-select mode | Enter/exit multi-select mode |
| `Space` | Toggle item selection | Select/deselect items (in multi-select mode) |
| `Del` | Bulk delete | Delete all selected items (confirmation required) |
| `Esc` | Exit multi-select | Cancel and clear selections |

**Multi-Select Workflow:**

1. Press `Ctrl-X` to enter multi-select mode
2. Use arrow keys to navigate, `Space` to select/deselect items
3. Status icons change to `[ ]` (unselected) or `[X]` (selected)
4. Press `Del` to bulk delete selected items
5. Press `Ctrl-X` or `Esc` to exit multi-select mode

**Supported Views:**

- Servers, Volumes, Networks, Subnets, Routers, Ports
- Floating IPs, Security Groups, Server Groups, Key Pairs, Images

#### Resource Actions

| Key | Command Equivalent | Action | Context |
|-----|-------------------|--------|---------|
| `c` | `:create` | Create | Some modules (FloatingIPs, Ports, Servers); use `:create` command in other views |
| `Del` or `d` | `:delete` | Delete | Module-specific (Volumes/archives, Swift, FloatingIPs, Ports); confirmation required |

**Note**: Not all modules register keyboard shortcuts for create/delete. Use command mode (`:create`, `:delete`) for universal access to these actions.

## Context-Specific Shortcuts

**Note**: Section headers show old single-key references (like `s` for servers). These lowercase keys NO LONGER work for navigation. Use command mode instead: `:servers`, `:networks`, `:volumes`, etc.

### Server View (`:servers`)

| Key | Action | Notes |
|-----|--------|-------|
| `:create` | Create server | Full server creation form (no keyboard shortcut) |
| `Del` | Delete server | Confirmation required (or bulk delete in multi-select) |
| `s` | Start server | Power on |
| `S` | Stop server | Graceful shutdown (uppercase = destructive) |
| `r` | Reboot server | Reboot (soft by default) |
| `l` | View console logs | Last 100 lines |
| `n` | Create snapshot | Create image from server |
| `R` | Resize server | Change flavor (uppercase = significant change) |
| `c` | Open console | Access server console |
| `Ctrl-X` | Multi-select mode | Bulk operations on multiple servers |

### Server Groups View (`:servergroups`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create server group | Anti-affinity/affinity policies |
| `Del` | Delete server group | Must be empty first |
| `Space` | View group members | See which servers are in group |

### Networks View (`:networks`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create network | Name, MTU, port security |
| `Del` | Delete network | Must delete subnets first |
| `M` | Manage network interfaces | Attach/detach from servers |

### Security Groups View (`:securitygroups`)

| Key | Action | Notes |
|-----|--------|-------|
| `:create` | Create security group | Name and description (no keyboard shortcut) |
| `Del` | Delete security group | Can't delete 'default' |
| `r` | Manage rules | Add/remove firewall rules |
| `a` | Manage server attachments | Attach/detach from servers |

### Volumes View (`:volumes`)

| Key | Action | Notes |
|-----|--------|-------|
| `:create` | Create volume | Size, type, bootable option (no keyboard shortcut) |
| `Del` | Delete volume | Must be detached first (or bulk delete in multi-select) |
| `a` | Attach to server | Select server and device |
| `m` | Manage server attachments | View and manage volume attachments |
| `b` | Create backup | Volume backup |
| `Ctrl-X` | Multi-select mode | Bulk operations on multiple volumes |

#### Volume Archives View (`:volumearchives`)

| Key | Action | Notes |
|-----|--------|-------|
| `d` | Delete archive | Delete backup/archive |

### Images View (`:images`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create/Upload image | Upload custom images |
| `Del` | Delete image | Admin only for public images |
| `Space` | View image details | Size, format, properties |

### Flavors View (`:flavors`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create flavor | Admin only |
| `Del` | Delete flavor | Admin only |
| `Space` | View flavor specs | CPU, RAM, disk details |

### Subnets View (`:subnets`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create subnet | CIDR, allocation pools, DNS |
| `Del` | Delete subnet | Must be unused first |
| `M` | Attach to router | Enable external routing |

### Ports View (`:ports`)

| Key | Action | Notes |
|-----|--------|-------|
| `c` | Create port | Manual port creation |
| `d` | Delete port | Detach from server first |
| `p` | Manage allowed address pairs | Configure allowed address pairs |
| `a` | Manage server assignment | Assign port to server |
| `Space` | View port details | MAC, IPs, security groups |

### Routers View (`:routers`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create router | Name and admin state |
| `Del` | Delete router | Remove interfaces first |
| `G` | Set gateway | Connect to external network |
| `I` | Manage interfaces | Add/remove subnet connections |

### Floating IPs View (`:floatingips`)

| Key | Action | Notes |
|-----|--------|-------|
| `c` | Allocate floating IP | From external pool |
| `d` | Release floating IP | Returns to pool |
| `a` | Manage server assignment | Attach to instance |
| `p` | Manage port assignment | Attach to port |

### Barbican View (`:barbican`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create secret | Store sensitive data |
| `Del` | Delete secret | Permanent deletion |
| `Space` | View secret metadata | Metadata only, not payload |

### Swift View (`:swift`)

| Key | Action | Notes |
|-----|--------|-------|
| `:create` | Create container | Object storage container (no keyboard shortcut) |
| `d` | Delete container/object | Must be empty for containers |

**Note**: Upload, download, web access, and metadata management operations are accessed through detail views and forms, not keyboard shortcuts.

### Health Dashboard (`:health`)

| Key | Action | Notes |
|-----|--------|-------|
| `^/v` | Navigate metrics | Scroll through metrics |
| `Space` | View metric details | Detailed metric breakdown |

### Advanced Search (`:search`)

| Key | Action | Notes |
|-----|--------|-------|
| Type query | Search across services | Searches all OpenStack services |
| `Enter` | Execute search | Start cross-service search |
| `^/v` | Navigate results | Browse search results |
| `Space` | View result details | Inspect found resource |
| `Esc` | Close search | Return to previous view |

## Form Navigation

### Form Field Navigation

| Key | Action | Notes |
|-----|--------|-------|
| `Tab` | Next field | Move to next form field |
| `Shift+Tab` | Previous field | Move to previous field |
| `^/v` | Move between fields | Alternative navigation |
| `Space` | Activate field | Toggle/selector activation |
| `Enter` | Enter edit mode | For text fields |
| `Esc` | Exit edit mode | Cancel form or exit field |

### Text Field Editing

| Key | Action | Notes |
|-----|--------|-------|
| `<-/->` | Move cursor | Character-by-character |
| `Home` | Start of line | Jump to beginning |
| `End` | End of line | Jump to end |
| `Backspace` | Delete before cursor | Standard deletion |
| `Delete` | Delete at cursor | Forward delete |
| `Ctrl+U` | Clear line | Erase entire line |
| `Esc` | Exit edit mode | Save and exit |

### Selector Fields

| Key | Action | Notes |
|-----|--------|-------|
| `^/v` | Navigate items | Browse available items |
| `Page Up/Down` | Scroll page | Fast scrolling |
| `Space` | Select/Deselect | Toggle selection |
| `Enter` | Confirm selection | Accept and close |
| `/` | Search items | Filter selector items |
| `Esc` | Cancel selection | Close without selecting |

## Navigation Patterns and Workflows

### Command-Based Workflows

**PRIMARY NAVIGATION METHOD**: All navigation uses command mode.

Lowercase letters (s, n, v, etc.) do NOT navigate - use `:servers`, `:networks`, `:volumes` instead.

**Server Management:**

```bash
:servers          # Navigate to servers view
^/v               # Select a server
S                 # Start the selected server (uppercase context action)
```

**Alternative using command mode for actions:**

```bash
:servers          # Navigate to servers view
^/v               # Select a server
:start            # Start the selected server
```

**Network Troubleshooting:**

```bash
:networks         # Navigate to networks view
/                 # Local search
type query        # Filter results
Space             # View details
```

**Resource Creation:**

```bash
:servers          # Navigate to servers view
C                 # Open create form (uppercase context action)
Tab               # Navigate form fields
Enter             # Submit form
```

**Alternative using command mode for actions:**

```bash
:servers          # Navigate to servers view
:create           # Open create form
Tab               # Navigate form fields
Enter             # Submit form
```

**Quick Resource Inspection:**

```bash
:volumes          # Navigate to any resource view
^/v               # Select resource
Space             # View details
Esc               # Return to list
```

### Efficient View Switching

1. **Use command input** - `:servers`, `:networks`, `:volumes` for discoverable navigation
2. **Tab completion** - Press `:` then Tab to see all available commands
3. **Use search frequently** - `/` to quickly find resources
4. **Learn context actions** - `:create`, `:delete`, `:start` adapt to your view
5. **Detail views** - `Space` for quick resource inspection

## Vim-Style Navigation

For vim users (muscle memory is real):

| Vim Key | Standard Key | Action |
|---------|--------------|--------|
| `j` | `v` | Move down |
| `k` | `^` | Move up |
| `g` | `Home` | Jump to top |
| `G` | `End` | Jump to bottom |
| `Esc` | `Esc` | Exit/Cancel (works everywhere) |
| `:q` | `q` | Quit (from main view) |

**Note**: `:q` works! But `q` does too. We're somewhat vim-like, but view navigation uses full command names (`:servers`, not `s`).

## Hidden Gems and Pro Tips

### Context-Aware Help (`?`)

Press `?` at any time:

- Help changes based on current view
- Shows available actions for current context
- Lists relevant keyboard shortcuts
- Explains what you're looking at

### Cache Management (`:clear-cache` or `:cc`)

Use `:clear-cache` or `:cc` to purge ALL caches:

- Clears all cached data
- Next operations slower while cache rebuilds
- Use when data looks stale or wrong

**When to purge cache:**

- OpenStack cluster just had a bad day (again)
- Data looks stale and wrong
- Just launched 50 servers and they're not showing up
- Debugging and need truth, not cached lies

**Note**: There is NO single-key shortcut for cache purge. Use the command mode.

### Quick Filter (`/`)

Press `/` in any list:

- Instant local filtering (no API calls)
- Results update as you type
- Works on visible fields only
- Clear query or press `Esc` to reset

**Local vs. Advanced Search:**

- **Local (`/`)**: Fast, searches current view only, instant results
- **Advanced (`z`)**: Comprehensive, searches all services, <500ms typical

### Navigation Shortcuts

- **Use command mode** - `:servers`, `:networks`, `:volumes` for view navigation
- **Press `Esc` repeatedly** to bubble up to dashboard
- **Press `?` when lost** for context-aware help
- **Use `:clear-cache` sparingly** - only when data is truly stale

## Search Behavior

### Local Search (`/`)

- Searches visible items only
- Instant filtering (no network calls)
- Case-insensitive by default
- Regex not supported
- Results update as you type

**Use when**: You know the resource is in the current view and you want instant results.

### Advanced Search (`z`)

- Searches all OpenStack services in parallel
- Cross-service queries (Nova, Neutron, Cinder, Glance, Keystone, Swift)
- 5-second timeout per service
- Shows partial results if service times out
- Results organized by service priority

**Use when**: You don't know which service has the resource or need comprehensive search.

## Auto-Refresh Configuration

Press `A` (uppercase) to cycle auto-refresh intervals:

- **5 seconds** -- Real-time monitoring (resource intensive)
- **10 seconds** -- Active monitoring (balanced)
- **30 seconds** -- Passive monitoring (light)
- **60 seconds** -- Background monitoring (very light)
- **Off** -- Manual refresh only (press `r` when needed)

**Recommendation**: Use 10-30 seconds for most workflows. Use 5 seconds only when actively monitoring a deployment.

## Accessibility Features

### Keyboard-Only Operation

Every operation can be performed without a mouse:

- **Navigation**: Arrow keys, Tab, Shift-Tab
- **Selection**: Space, Enter
- **Actions**: Single-key shortcuts
- **Forms**: Tab navigation, Enter to edit
- **Help**: `?` key always available

### Screen Reader Support

- Structured navigation
- Clear focus indicators
- Descriptive action labels
- Status announcements

### Visual Indicators

- **Selected items**: Highlighted
- **Active fields**: Clearly marked
- **Status colors**:
  - Green = Good/Active
  - Red = Error/Failed
  - Yellow = Warning/Building
- **Progress indicators**: For long operations

## Troubleshooting Navigation

### "My keyboard shortcuts don't work!"

**Check**:

1. Are you in a text field? (Press `Esc` to exit)
2. Is a modal/form open? (Press `Esc` to close)
3. Terminal settings correct? (Check terminal emulator)

### "Search returns nothing!"

**Local search (`/`)**:

- Are you searching the right view?
- Try broader search terms
- Case-insensitive matching

**Advanced search (`z`)**:

- Services might be slow (partial results shown)
- 5-second timeout per service
- Check OpenStack service health

### "View won't refresh!"

**Solutions**:

- Use `:refresh` (or `:reload`) to manually refresh
- Use `:clear-cache` (or `:cc`) to purge cache (if data is stale)
- Check auto-refresh setting (press `A` - uppercase)

## Cheat Sheet

### Most Used Shortcuts

```
Navigation:  :servers :networks :volumes :images  (Command mode -- type : then command name)
Actions:     C Del Space ? q                      (Create, Delete, Details, Help, Quit)
Search:      / :search                            (Local, Advanced search)
Commands:    : (then cmd name)                    (Command input -- :ctx, :servers, :create, etc.)
Refresh:     :refresh :clear-cache                (Refresh view, Cache purge)
Movement:    ^v j k Page-Up/Dn                     (List navigation)
Bulk Ops:    Ctrl-X Space Del                     (Multi-select, Select, Bulk delete)
Cloud:       :ctx <cloud>                         (Switch between clouds)
Server Mgmt: S T R                                (Start, Stop, Restart -- uppercase context actions)
```

### Emergency Shortcuts

```
:cc or :clear-cache - Cache purge (when data is stale)
Esc                 - Get me out of here
q                   - Quit (from main view)
?                   - Help! (context-aware)
```

### Pro Tips

1. **Use command mode for navigation** -- `:servers`, `:networks`, `:volumes` (NOT lowercase letters)
2. **Press `Esc` repeatedly** to bubble up to dashboard
3. **Press `?` when lost** for context-aware help
4. **Use `:clear-cache` sparingly** -- only when data is truly stale
5. **Use `/` first** before `:search` -- local search is instant
6. **Learn uppercase context actions** -- C for Create, S/T/R for server management
7. **Use `Space` liberally** -- Quick detail inspection
8. **Vim keys work** -- `j/k` for navigation, `g/G` for jumps
9. **Command input Tab completion** -- `:` then Tab shows all commands, `:ctx <Tab>` shows all clouds
10. **Command history** -- UP/DOWN arrows in command input recall previous commands

---

**Remember**: You don't need to memorize everything. Press `?` at any time for context-aware help. The more you use Substation, the more shortcuts will become muscle memory.

*Keyboard warriors don't use mice. The terminal is your canvas. The keyboard is your brush.*
