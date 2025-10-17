# Common Workflows

Everyday OpenStack operations with Substation.

## Command-Based Workflows

Substation emphasizes **command-based navigation** as the primary method for all operations. Commands are discoverable (tab completion), forgiving (fuzzy matching), and context-aware.

### Learning Path

1. **Beginners**: Use command input (`:` then Tab to discover commands)
2. **Intermediate**: Learn command aliases (`:servers` = `:srv` = `:s`)
3. **Advanced**: Master short aliases and command combinations for efficiency

## Server Management

### List Servers

1. Launch Substation: `substation --cloud mycloud`
2. Press `:` to enter command input
3. Type `servers` (or press Tab to see all commands)
4. Press `Enter` to navigate to servers view
5. Use `↑/↓` to navigate
6. Press `Space` to view details

**Command Discovery:**

```text
:                    Enter command input
: <Tab>              Show all available commands
: serv<Tab>          Auto-complete to :servers
: servers<Enter>     Navigate to servers view
```

**Advanced Filtering:**

1. Navigate to servers: `:servers<Enter>`
2. Press `/` for local search
3. Type filter (e.g., "prod" for production servers)
4. Navigate filtered results

### Create a Server

1. Navigate to servers view: `:servers<Enter>`
2. Create server: `:create<Enter>`
3. Fill in the form:
   - **Name**: Server name (e.g., web-server-01)
   - **Flavor**: Tab to select size (or use recommendation mode)
   - **Image**: Select OS image
   - **Network**: Select network(s)
   - **Security Groups** (optional)
   - **Key Pair** (optional)
4. Tab through fields, Enter to edit
5. Press `Enter` to create
6. Watch real-time status as server builds

**Pro Tip**: Press Tab in flavor selector to enter recommendation mode for workload-aware suggestions.

**Command Aliases:**

- `:create` = `:new` = `:add`
- All work the same way, choose what feels natural

### Server Actions

**Start Server:**

1. Navigate to server list: `:servers<Enter>`
2. Select stopped server with `↑/↓`
3. Start server: `:start<Enter>` (or `:boot<Enter>`)
4. Confirm if prompted

**Stop Server:**

1. Navigate to server list: `:servers<Enter>`
2. Select running server with `↑/↓`
3. Stop server: `:stop<Enter>` (or `:shutdown<Enter>`)
4. Confirm if prompted

**Restart Server:**

1. Navigate to server list: `:servers<Enter>`
2. Select running server
3. Restart: `:restart<Enter>` (or `:reboot<Enter>`)
4. Choose soft or hard reboot
5. Confirm

**Delete Server:**

1. Navigate to server list: `:servers<Enter>`
2. Select server to delete
3. Delete: `:delete<Enter>` (or `:remove<Enter>` or `:rm<Enter>`)
4. Confirm deletion
5. Server removed

**View Console Logs:**

1. Navigate to server list: `:servers<Enter>`
2. Select server
3. View logs: `:console<Enter>` (or `:logs<Enter>`)
4. View console output
5. Press `Esc` to close

**Command Discovery Tips:**

- `:start` = `:boot` = `:power-on` (all aliases work)
- `:stop` = `:shutdown` = `:power-off`
- `:restart` = `:reboot`
- `:delete` = `:remove` = `:rm`
- Press `:` then Tab to see all available action commands

### Create Server Snapshot

1. Navigate to servers: `:servers<Enter>`
2. Select server to snapshot
3. Create snapshot: `:snapshot<Enter>` (or `:snap<Enter>`)
4. Enter snapshot name
5. Snapshot creates in background
6. Check images: `:images<Enter>` to see snapshot

### Resize Server

1. Select server to resize
2. Resize: `:resize<Enter>`
3. Select new flavor
4. Confirm resize
5. Verify resize (or revert if issues)

## Network Management

### List Networks

1. Navigate to networks: `:networks<Enter>`
2. View all networks in project
3. Press `Space` for network details
4. See subnets, ports, DHCP status

**Command Aliases:**

- `:networks` = `:net` = `:n` = `:neutron`

### Create Network

1. Navigate to networks: `:networks<Enter>`
2. Create network: `:create<Enter>`
3. Fill in network form:
   - **Name**: Network name
   - **MTU**: Default 1500 (or custom)
   - **Port Security**: Enable/disable
   - **External**: Mark as external (if applicable)
4. Press `Enter` to create

### Create Subnet

1. Navigate to subnets: `:subnets<Enter>`
2. Create subnet: `:create<Enter>`
3. Fill in subnet form:
   - **Name**: Subnet name
   - **Network**: Select parent network
   - **CIDR**: IP range (e.g., 192.168.1.0/24)
   - **Gateway IP**: Gateway address (or auto)
   - **DHCP**: Enable/disable
   - **Allocation Pools** (optional)
   - **DNS Nameservers** (optional)
4. Press `Enter` to create

**Command Aliases:**

- `:subnets` = `:sub` = `:u`

### Create Router

1. Navigate to routers: `:routers<Enter>`
2. Create router: `:create<Enter>`
3. Configure router:
   - **Name**: Router name
   - **External Network**: Select for gateway (optional)
4. Press `Enter` to create

**Command Aliases:**

- `:routers` = `:rtr` = `:r`

### Attach Subnet to Router

1. Navigate to subnets: `:subnets<Enter>`
2. Select subnet to attach
3. Attach: `:attach<Enter>` (or `:connect<Enter>`)
4. Select target router
5. Confirm attachment

### Manage Security Groups

**Create Security Group:**

1. Navigate to security groups: `:securitygroups<Enter>`
2. Create group: `:create<Enter>`
3. Enter security group name and description
4. Press `Enter` to create

**Command Aliases:**

- `:securitygroups` = `:secgroups` = `:sg` = `:e`

**Add Security Group Rule:**

1. Navigate to security groups: `:securitygroups<Enter>`
2. Select security group
3. Manage rules: `:manage<Enter>`
4. Create rule: `:create<Enter>`
5. Configure rule:
   - **Direction**: Ingress or Egress
   - **Protocol**: TCP, UDP, ICMP, or Any
   - **Port Range**: Single port or range
   - **Remote**: CIDR or security group
6. Press `Enter` to add rule

### Manage Floating IPs

**Allocate Floating IP:**

1. Navigate to floating IPs: `:floatingips<Enter>`
2. Create/allocate: `:create<Enter>`
3. Select floating IP pool (external network)
4. IP allocated and shown in list

**Command Aliases:**

- `:floatingips` = `:fips` = `:l`

**Associate Floating IP:**

1. Navigate to floating IPs: `:floatingips<Enter>`
2. Select unassociated IP
3. Associate: `:attach<Enter>` (or `:connect<Enter>`)
4. Select target server
5. Select server port
6. Confirm association

**Disassociate Floating IP:**

1. Select associated floating IP
2. Detach: `:detach<Enter>`
3. Confirm disassociation
4. IP returned to pool

## Storage Management

### List Volumes

1. Navigate to volumes: `:volumes<Enter>`
2. View all volumes
3. Press `Space` for volume details
4. See size, type, attachments, status

**Command Aliases:**

- `:volumes` = `:vol` = `:v` = `:cinder`

### Create Volume

1. Navigate to volumes: `:volumes<Enter>`
2. Create volume: `:create<Enter>`
3. Fill in volume form:
   - **Name**: Volume name
   - **Size**: Size in GB
   - **Volume Type** (optional)
   - **Source**: Empty, image, snapshot, or volume
4. Press `Enter` to create

### Attach Volume to Server

1. Navigate to volumes: `:volumes<Enter>`
2. Select available volume
3. Attach: `:attach<Enter>` (or `:connect<Enter>`)
4. Select target server
5. Optionally specify device path
6. Confirm attachment

### Detach Volume from Server

1. Select attached volume
2. Detach: `:detach<Enter>` (or `:disconnect<Enter>`)
3. Confirm detachment
4. Volume returns to available state

### Create Volume Snapshot

1. Select volume to snapshot
2. Create snapshot: `:snapshot<Enter>` (or `:snap<Enter>`)
3. Enter snapshot name
4. Snapshot created
5. View in volume snapshots list

### Extend Volume Size

1. Select volume to extend
2. Extend: `:resize<Enter>`
3. Enter new size (must be larger)
4. Confirm extension
5. Volume size updated

## Image Management

### List Images

1. Navigate to images: `:images<Enter>`
2. View all images in project
3. Use `/` to filter by name
4. Press `Space` for image details

**Command Aliases:**

- `:images` = `:img` = `:i` = `:glance`

### Upload Image

1. Navigate to images: `:images<Enter>`
2. Create/upload: `:create<Enter>`
3. Configure image:
   - **Name**: Image name
   - **File**: Path to image file (or URL)
   - **Disk Format**: qcow2, raw, vmdk, etc.
   - **Container Format**: bare, ovf, etc.
   - **Visibility**: public, private, shared
4. Press `Enter` to upload
5. Monitor upload progress

### Create Image from Server

(See "Create Server Snapshot" above)

## Search Operations

### Local Search (Fast)

Search within current view:

1. Navigate to any resource list (e.g., `:servers<Enter>`)
2. Press `/` to activate search
3. Type query (filters as you type)
4. Results update instantly
5. Press `Esc` to clear search

**Example:**

```text
:servers<Enter>      Navigate to servers view
/                    Start local search
type "web"           Shows only servers with "web" in name
Esc                  Clear search filter
```

### Cross-Service Search (Comprehensive)

1. Open search: `:search<Enter>` (or `:find<Enter>`)
2. Type query (e.g., "production")
3. Press `Enter`
4. Results from all services:
   - Servers (Nova)
   - Networks (Neutron)
   - Volumes (Cinder)
   - Images (Glance)
   - Users (Keystone)
   - Containers (Swift)
5. Navigate results with `↑/↓`
6. Press `Space` for details

**Command Aliases:**

- `:search` = `:find` = `:z`

**Example Queries:**

- `prod` - Find all production resources
- `192.168.1` - Find resources with this IP
- `ubuntu` - Find all Ubuntu-related resources
- `error` - Find resources in error state

## Troubleshooting Workflows

### Debug Server Issues

1. **Check Server Status:**
   - Navigate: `:servers<Enter>`
   - Find problem server
   - Press `Space` for details
   - Note status and error message

2. **View Console Logs:**
   - Select server
   - View logs: `:console<Enter>` (or `:logs<Enter>`)
   - Review boot sequence
   - Look for errors

3. **Check Network Connectivity:**
   - Navigate: `:ports<Enter>`
   - Find server ports
   - Verify network attachment
   - Check security groups

4. **Check Volume Attachments:**
   - Navigate: `:volumes<Enter>`
   - Verify volume status
   - Check attachment to server

### Investigate Network Issues

1. **Verify Router Configuration:**
   - Navigate: `:routers<Enter>`
   - Check router status
   - Verify gateway configuration
   - Check subnet attachments

2. **Check Security Rules:**
   - Navigate: `:securitygroups<Enter>`
   - Review applied groups
   - Check rule configurations
   - Verify protocol and port settings

3. **Check Floating IP Associations:**
   - Navigate: `:floatingips<Enter>`
   - Verify IP associations
   - Check router external gateway

### Cache and Performance Issues

**Stale Data:**

1. Cache purge: `:cache-purge<Enter>` (or `:clear-cache<Enter>`)
2. Refresh view: `:refresh<Enter>` (or `:reload<Enter>`)
3. Fresh data loaded from API

**Slow Performance:**

1. Navigate to health: `:health<Enter>`
2. Check API response times
3. Check cache hit rates (target: 80%+)
4. Enable wiretap if needed: `substation --wiretap`

## Batch Operations

### Multi-Select Mode

Substation supports multi-select for bulk operations:

1. Navigate to resource list (e.g., `:servers<Enter>`)
2. Enter multi-select mode: Press `Ctrl-X`
3. Use `↑/↓` to navigate
4. Press `Space` to select/deselect items
5. Delete selected: `:delete<Enter>` (or press `Del`)
6. Exit multi-select: Press `Ctrl-X` or `Esc`

**Supported Views:**

- Servers, Volumes, Networks, Subnets, Routers, Ports
- Floating IPs, Security Groups, Server Groups, Key Pairs, Images

### Monitor Build Progress

1. Create resources (`:create<Enter>` in any view)
2. Resources show "BUILD" status
3. Auto-refresh updates status (toggle with `a`)
4. Wait for "ACTIVE" status

## Tips and Tricks

### Command Discovery Workflow

**For Beginners:**

1. Press `:` to enter command input
2. Press `Tab` to see all available commands
3. Type first few letters and `Tab` to auto-complete
4. Use `Up/Down` arrows to recall command history
5. Commands persist in `~/.config/substation/command_history`

**Progressive Learning:**

1. **Week 1**: Use full command names (`:servers`, `:networks`, `:volumes`)
2. **Week 2**: Learn common aliases (`:srv`, `:net`, `:vol`)
3. **Week 3**: Try short aliases (`:s`, `:n`, `:v`)
4. **Week 4+**: Master command-based workflows for efficiency

### Efficient Resource Creation

1. Navigate to resource view (`:servers<Enter>`)
2. Create resource (`:create<Enter>`)
3. Use Tab to navigate form fields quickly
4. Use flavor recommendation mode for servers
5. Submit with `Enter`

**Tips:**

- Tab completion works in command input
- Fuzzy matching handles typos (`:servrs` suggests `:servers`)
- Command history saves frequently used commands

### Quick Status Checks

1. Health dashboard: `:health<Enter>` (or `:h<Enter>`)
2. See all services at a glance
3. Check performance metrics
4. Monitor cache effectiveness

### Navigation Efficiency

**Recommended Learning Path:**

1. **Start with commands**: `:servers`, `:networks`, `:volumes` (discoverable)
2. **Learn tab completion**: `:serv<Tab>` completes to `:servers`
3. **Use fuzzy matching**: `:netwrk` suggests `:networks`
4. **Memorize aliases**: `:servers` = `:srv` = `:s` = `:nova`

**Command Discovery:**

- Press `:` then `Tab` to see all commands
- Press `?` for context-aware help
- Use `/` for local search within views
- Use `:search<Enter>` for cross-service search

### Data Freshness

1. Refresh: `:refresh<Enter>` (uses cache if valid)
2. Cache purge: `:cache-purge<Enter>` (force fresh data from API)
3. Auto-refresh: Press `a` to toggle intervals (5s, 10s, 30s, 60s, off)
4. Health check: `:health<Enter>` to see cache hit rate

---

**Remember**: Start with command input for discoverability. Commands teach you the interface as you learn. As you become more proficient, use shorter command aliases for speed. Before long, you'll be managing OpenStack faster than Horizon could ever dream.

*Commands are your guide. Efficiency is your reward. Mastery is your goal.*
