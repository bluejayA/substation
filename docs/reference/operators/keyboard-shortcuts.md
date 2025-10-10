# Keyboard Shortcuts and Navigation Guide

Complete keyboard shortcut reference and navigation guide for Substation. Master keyboard-driven navigation - your mouse is for the weak.

## Quick Reference Card

Print this and tape it to your monitor (we won't judge).

### Navigation (View Switching)

| Key | View | When You'll Need It |
|-----|------|---------------------|
| `d` | Dashboard | First thing, every time. Start here. |
| `s` | Servers | "Why is prod down?" |
| `g` | Server Groups | Advanced anti-affinity wizardry |
| `n` | Networks | "Can you see me now?" |
| `e` | Security Groups | Firewall archaeology and port spelunking |
| `v` | Volumes | "Where did my data go?" (Cinder storage) |
| `i` | Images | Finding that one CentOS 7 image from 2019 |
| `f` | Flavors | Size matters. Choose wisely. |
| `h` | Health Dashboard | "Is it us or them?" (usually them) |
| `u` | Subnets | CIDR math at 3 AM. Fun times. |
| `p` | Ports | MAC address detective work |
| `r` | Routers | Routing table archaeology |
| `l` | Floating IPs | The IPs that mysteriously float away |
| `b` | Barbican (Secrets) | Where secrets hide |
| `o` | Octavia (Load Balancers) | Distributing the pain |
| `j` | Swift (Object Storage) | Blob storage chaos |
| `k` | Key Pairs | SSH key management |
| `q` | Configuration Profiles | Switch clouds/projects |
| `z` | Advanced Search | Cross-service grep for your cloud |

### Global Actions

| Key | Action | Notes |
|-----|--------|-------|
| `?` | Show Help | Context-aware - changes based on current view |
| `@` | About | Version info, credits |
| `c` | Cache Purge | The panic button. Clears ALL caches. Use sparingly. |
| `r` | Refresh | Refresh current view |
| `a` | Auto-refresh Toggle | Cycle between 5s, 10s, 30s, 60s, off |
| `/` | Search/Filter | Instant local filtering, no API calls |
| `:` | Command Mode | command mode (see Command Mode section) |
| `Ctrl-X` | Multi-Select Mode | Toggle multi-select mode for bulk operations |
| `Esc` | Back/Cancel | Works everywhere, exits everything |
| `q` | Quit | From main view only |

### List Navigation

| Key | Action | Vim Users Note |
|-----|--------|----------------|
| `↑` or `k` | Move up | Vim muscle memory works |
| `↓` or `j` | Move down | Vim muscle memory works |
| `Page Up` | Scroll up one page | - |
| `Page Down` | Scroll down one page | - |
| `Home` or `g` | Jump to top | Vim-style |
| `End` or `G` | Jump to bottom | Vim-style |
| `Space` | View details (or toggle selection in multi-select) | Deep dive into a resource |
| `Enter` | View details | Same as Space, because options |

### Multi-Select Mode

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

### Resource Actions

| Key | Action | Context |
|-----|--------|---------|
| `C` | Create | All resource lists |
| `Del` or `D` | Delete | All resources (confirmation required) |

## Context-Specific Shortcuts

### Server View (`s`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create server | Full server creation form |
| `Del` | Delete server | Confirmation required (or bulk delete in multi-select) |
| `S` | Start server | Power on |
| `T` | Stop server | Graceful shutdown |
| `R` | Restart server | Reboot (soft by default) |
| `L` | View console logs | Last 100 lines |
| `P` | Create snapshot | Create image from server |
| `Z` | Resize server | Change flavor |
| `Ctrl-X` | Multi-select mode | Bulk operations on multiple servers |

### Server Groups View (`g`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create server group | Anti-affinity/affinity policies |
| `Del` | Delete server group | Must be empty first |
| `Space` | View group members | See which servers are in group |

### Networks View (`n`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create network | Name, MTU, port security |
| `Del` | Delete network | Must delete subnets first |
| `A` | Manage network interfaces | Attach/detach from servers |

### Security Groups View (`e`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create security group | Name and description |
| `Del` | Delete security group | Can't delete 'default' |
| `A` | Attach to servers | Apply to server instances |
| `M` | Manage rules | Add/remove firewall rules |

### Volumes View (`v`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create volume | Size, type, bootable option |
| `Del` | Delete volume | Must be detached first (or bulk delete in multi-select) |
| `A` | Attach to server | Select server and device |
| `X` | Detach from server | Unmount first! |
| `P` | Create snapshot | Volume backup |
| `M` | Manage snapshots | View/restore snapshots |
| `E` | Extend volume size | Can't shrink, only grow |
| `Ctrl-X` | Multi-select mode | Bulk operations on multiple volumes |

### Images View (`i`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create/Upload image | Upload custom images |
| `Del` | Delete image | Admin only for public images |
| `Space` | View image details | Size, format, properties |

### Flavors View (`f`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create flavor | Admin only |
| `Del` | Delete flavor | Admin only |
| `Space` | View flavor specs | CPU, RAM, disk details |

### Subnets View (`u`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create subnet | CIDR, allocation pools, DNS |
| `Del` | Delete subnet | Must be unused first |
| `A` | Attach to router | Enable external routing |

### Ports View (`p`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create port | Manual port creation |
| `Del` | Delete port | Detach from server first |
| `Space` | View port details | MAC, IPs, security groups |

### Routers View (`r`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create router | Name and admin state |
| `Del` | Delete router | Remove interfaces first |
| `G` | Set gateway | Connect to external network |
| `I` | Manage interfaces | Add/remove subnet connections |

### Floating IPs View (`l`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Allocate floating IP | From external pool |
| `Del` | Release floating IP | Returns to pool |
| `A` | Associate to server | Attach to instance |
| `D` | Disassociate | Detach from instance |

### Barbican View (`b`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create secret | Store sensitive data |
| `Del` | Delete secret | Permanent deletion |
| `Space` | View secret metadata | Metadata only, not payload |

### Octavia View (`o`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create load balancer | VIP, provider, flavor |
| `Del` | Delete load balancer | Removes all listeners/pools |
| `L` | Manage listeners | Add/remove listeners |
| `P` | Manage pools | Backend server pools |
| `M` | Manage members | Pool members |

### Swift View (`j`)

| Key | Action | Notes |
|-----|--------|-------|
| `C` | Create container | Object storage container |
| `Del` | Delete container/object | Must be empty for containers |
| `U` | Upload object | File upload to container |
| `D` | Download object | Save object to disk |

### Health Dashboard (`h`)

| Key | Action | Notes |
|-----|--------|-------|
| `↑/↓` | Navigate metrics | Scroll through metrics |
| `Space` | View metric details | Detailed metric breakdown |
| `r` | Refresh metrics | Update real-time data |

### Advanced Search (`z`)

| Key | Action | Notes |
|-----|--------|-------|
| Type query | Search across services | Searches all OpenStack services |
| `Enter` | Execute search | Start cross-service search |
| `↑/↓` | Navigate results | Browse search results |
| `Space` | View result details | Inspect found resource |
| `Esc` | Close search | Return to previous view |

## Form Navigation

### Form Field Navigation

| Key | Action | Notes |
|-----|--------|-------|
| `Tab` | Next field | Move to next form field |
| `Shift+Tab` | Previous field | Move to previous field |
| `↑/↓` | Move between fields | Alternative navigation |
| `Space` | Activate field | Toggle/selector activation |
| `Enter` | Enter edit mode | For text fields |
| `Esc` | Exit edit mode | Cancel form or exit field |

### Text Field Editing

| Key | Action | Notes |
|-----|--------|-------|
| `←/→` | Move cursor | Character-by-character |
| `Home` | Start of line | Jump to beginning |
| `End` | End of line | Jump to end |
| `Backspace` | Delete before cursor | Standard deletion |
| `Delete` | Delete at cursor | Forward delete |
| `Ctrl+U` | Clear line | Erase entire line |
| `Esc` | Exit edit mode | Save and exit |

### Selector Fields

| Key | Action | Notes |
|-----|--------|-------|
| `↑/↓` | Navigate items | Browse available items |
| `Page Up/Down` | Scroll page | Fast scrolling |
| `Space` | Select/Deselect | Toggle selection |
| `Enter` | Confirm selection | Accept and close |
| `/` | Search items | Filter selector items |
| `Esc` | Cancel selection | Close without selecting |

## Navigation Patterns and Workflows

### Efficient View Switching

1. **Master navigation keys** - `d` `s` `n` `v` etc. for instant view switching
2. **Use search frequently** - `/` to quickly find resources
3. **Learn context actions** - Actions change per view
4. **Detail views** - `Space` for quick resource inspection

### Common Navigation Flows

**Server Management:**

```
d (dashboard) → s (servers) → ↑/↓ (select) → Space (details) → Esc (back)
```

**Network Troubleshooting:**

```
d (dashboard) → n (networks) → / (search) → type query → Space (details)
```

**Resource Creation:**

```
s (servers) → C (create) → Tab (navigate form) → Enter (submit)
```

**Quick Resource Inspection:**

```
Any list view → ↑/↓ (select) → Space (details) → Esc (return) → Repeat
```

## Vim-Style Navigation

For vim users (muscle memory is real):

| Vim Key | Standard Key | Action |
|---------|--------------|--------|
| `j` | `↓` | Move down |
| `k` | `↑` | Move up |
| `g` | `Home` | Jump to top |
| `G` | `End` | Jump to bottom |
| `Esc` | `Esc` | Exit/Cancel (works everywhere) |
| `:q` | `q` | Quit (from main view) |

**Note**: `:q` doesn't work, but `q` does. We're not *that* vim-like.

## Hidden Gems and Pro Tips

### Context-Aware Help (`?`)

Press `?` at any time:

- Help changes based on current view
- Shows available actions for current context
- Lists relevant keyboard shortcuts
- Explains what you're looking at

### Cache Management (`c`)

Press `c` anywhere to purge ALL caches:

- Clears L1, L2, and L3 caches
- Next operations slower while cache rebuilds
- Use when data looks stale or wrong

**When to purge cache:**

- OpenStack cluster just had a bad day (again)
- Data looks stale and wrong
- Just launched 50 servers and they're not showing up
- Debugging and need truth, not cached lies

### Quick Filter (`/`)

Press `/` in any list:

- Instant local filtering (no API calls)
- Results update as you type
- Works on visible fields only
- Clear query or press `Esc` to reset

**Local vs. Advanced Search:**

- **Local (`/`)**: Fast, searches current view only, instant results
- **Advanced (`z`)**: Comprehensive, searches all services, < 500ms typical

### Navigation Shortcuts

- **Double-tap navigation keys** to refresh that view
- **Press `Esc` repeatedly** to bubble up to dashboard
- **Press `?` when lost** for context-aware help
- **Press `c` sparingly** - only when data is truly stale

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

## Command Mode

Press `:` to enter command mode - inspired by vim. Command mode provides a powerful way to navigate, switch contexts, and execute actions. Command mode supports tab completion and command history for efficiency, making it easy to switch between OpenStack clouds and perform actions without leaving the keyboard.

### Entering Command Mode

| Key | Result |
|-----|--------|
| `:` | Activate command mode |
| Type command | Enter command name |
| `Enter` | Execute command |
| `Esc` | Cancel command mode |

### Command Mode Features

**Tab Completion:**

- Press `Tab` to auto-complete commands
- Press `Tab` multiple times to cycle through matches
- Works for both command names and cloud contexts

**Command History:**

- Press `↑` (Up arrow) to navigate to previous commands
- Press `↓` (Down arrow) to navigate to next command
- History persists between sessions (stored in `~/.config/substation/command_history`)
- Maximum 50 commands stored

### Available Commands

**Navigation Commands:**

| Command | Shortcut | Action |
|---------|----------|--------|
| `:servers` | `:s` | Navigate to servers view |
| `:networks` | `:n` | Navigate to networks view |
| `:volumes` | `:v` | Navigate to volumes view |
| `:images` | `:i` | Navigate to images view |
| `:flavors` | `:f` | Navigate to flavors view |
| `:dashboard` | `:d` | Navigate to dashboard |
| `:routers` | `:r` | Navigate to routers view |
| `:ports` | `:p` | Navigate to ports view |
| `:subnets` | `:u` | Navigate to subnets view |
| `:floatingips` | `:l` | Navigate to floating IPs view |
| `:securitygroups` | `:e` | Navigate to security groups view |
| `:servergroups` | `:g` | Navigate to server groups view |
| `:keypairs` | `:k` | Navigate to key pairs view |
| `:search` | `:z` | Navigate to advanced search |
| `:help` | `:?` | Show help |

**Context Commands:**

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

**Tab Completion for Cloud Names:**

- Type `:ctx` (with space) and press `Tab` to see all available clouds
- Type `:ctx p` and press `Tab` to complete cloud names starting with 'p'
- Press `Tab` multiple times to cycle through matching clouds

**Example Workflow:**

```bash
# Switch clouds quickly
:ctx dev<Tab>    # Auto-completes to :ctx development
<Enter>          # Switches to development cloud

# Navigate using history
:↑               # Shows previous command (:ctx development)
:↑               # Shows earlier command (:servers)
<Enter>          # Executes :servers
```

### Command Mode Tips

1. **Use Tab completion** - Faster than typing full commands
2. **Leverage history** - UP/DOWN arrows save keystrokes
3. **Cloud switching** - `:ctx <Tab>` shows all clouds
4. **Fuzzy matching** - Commands suggest closest matches
5. **Shortcuts work** - Most commands have single-letter shortcuts

### Command History Behavior

- History is **persistent** across sessions
- Commands are **deduplicated** (no consecutive duplicates)
- **Maximum 50 commands** retained
- **Newest commands** at the end
- Type any character to **reset** to end of history

## Auto-Refresh Configuration

Press `a` to toggle auto-refresh intervals:

- **5 seconds** - Real-time monitoring (resource intensive)
- **10 seconds** - Active monitoring (balanced)
- **30 seconds** - Passive monitoring (light)
- **60 seconds** - Background monitoring (very light)
- **Off** - Manual refresh only (press `r` when needed)

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

- Press `r` to manually refresh
- Press `c` to purge cache (if data is stale)
- Check auto-refresh setting (press `a`)

## Cheat Sheet

### Most Used Shortcuts

```
Navigation:  d s n v i          (Dashboard, Servers, Networks, Volumes, Images)
Actions:     C Del Space ? q    (Create, Delete, Details, Help, Quit)
Search:      / z                (Local, Advanced)
Commands:    : (then cmd name)  (Command mode - :ctx, :servers, etc.)
Refresh:     r c                (Refresh, Cache purge)
Movement:    ↑↓ j k Page-Up/Dn  (List navigation)
Bulk Ops:    Ctrl-X Space Del   (Multi-select, Select, Bulk delete)
Cloud:       :ctx <cloud>       (Switch between clouds)
```

### Emergency Shortcuts

```
c       - Cache purge (when data is stale)
Esc     - Get me out of here
q       - Quit (from main view)
?       - Help! (context-aware)
```

### Pro Tips

1. **Double-tap navigation keys** to refresh that view
2. **Press `Esc` repeatedly** to bubble up to dashboard
3. **Press `?` when lost** for context-aware help
4. **Press `c` sparingly** - only when data is truly stale
5. **Use `/` first** before `z` - local search is instant
6. **Learn view keys** - Faster than any mouse
7. **Use `Space` liberally** - Quick detail inspection
8. **Vim keys work** - `j/k` for navigation, `g/G` for jumps
9. **Command mode Tab completion** - `:ctx <Tab>` shows all clouds
10. **Command history** - UP/DOWN arrows in command mode recall previous commands

---

**Remember**: You don't need to memorize everything. Press `?` at any time for context-aware help. The more you use Substation, the more shortcuts will become muscle memory.

*Keyboard warriors don't use mice. The terminal is your canvas. The keyboard is your brush.*
