# Common Workflows

Everyday OpenStack operations with Substation.

## Server Management

### List Servers

**Quick Method:**

1. Launch Substation: `substation --cloud mycloud`
2. Press `s` for servers
3. Use `↑/↓` to navigate
4. Press `Space` to view details

**Advanced Filtering:**

1. Press `s` for servers
2. Press `/` for local search
3. Type filter (e.g., "prod" for production servers)
4. Navigate filtered results

### Create a Server

1. Press `s` to view servers
2. Press `C` for "Create Server"
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

### Server Actions

**Start Server:**

1. Navigate to server list (`s`)
2. Select stopped server with `↑/↓`
3. Press `S` for start
4. Confirm if prompted

**Stop Server:**

1. Navigate to server list (`s`)
2. Select running server
3. Press `T` for stop
4. Confirm if prompted

**Restart Server:**

1. Select running server
2. Press `R` for restart
3. Choose soft or hard reboot
4. Confirm

**Delete Server:**

1. Select server to delete
2. Press `Del` or `D`
3. Confirm deletion
4. Server removed

**View Console Logs:**

1. Select server
2. Press `L` for logs
3. View console output
4. Press `Esc` to close

### Create Server Snapshot

1. Navigate to server list (`s`)
2. Select server to snapshot
3. Press `P` for snapshot
4. Enter snapshot name
5. Snapshot creates in background
6. Check images (`i`) to see snapshot

### Resize Server

1. Select server to resize
2. Press `Z` for resize
3. Select new flavor
4. Confirm resize
5. Verify resize (or revert if issues)

## Network Management

### List Networks

1. Press `n` for networks
2. View all networks in project
3. Press `Space` for network details
4. See subnets, ports, DHCP status

### Create Network

1. Press `n` for networks
2. Press `C` for create
3. Fill in network form:
   - **Name**: Network name
   - **MTU**: Default 1500 (or custom)
   - **Port Security**: Enable/disable
   - **External**: Mark as external (if applicable)
4. Press `Enter` to create

### Create Subnet

1. Press `u` for subnets
2. Press `C` for create
3. Fill in subnet form:
   - **Name**: Subnet name
   - **Network**: Select parent network
   - **CIDR**: IP range (e.g., 192.168.1.0/24)
   - **Gateway IP**: Gateway address (or auto)
   - **DHCP**: Enable/disable
   - **Allocation Pools** (optional)
   - **DNS Nameservers** (optional)
4. Press `Enter` to create

### Create Router

1. Press `r` for routers
2. Press `C` for create
3. Configure router:
   - **Name**: Router name
   - **External Network**: Select for gateway (optional)
4. Press `Enter` to create

### Attach Subnet to Router

1. Navigate to subnets (`u`)
2. Select subnet to attach
3. Press `A` for attach
4. Select target router
5. Confirm attachment

### Manage Security Groups

**Create Security Group:**

1. Press `e` for security groups
2. Press `C` for create
3. Enter security group name and description
4. Press `Enter` to create

**Add Security Group Rule:**

1. Navigate to security groups (`e`)
2. Select security group
3. Press `M` for manage rules
4. Press `C` to create rule
5. Configure rule:
   - **Direction**: Ingress or Egress
   - **Protocol**: TCP, UDP, ICMP, or Any
   - **Port Range**: Single port or range
   - **Remote**: CIDR or security group
6. Press `Enter` to add rule

### Manage Floating IPs

**Allocate Floating IP:**

1. Press `l` for floating IPs
2. Press `C` for create/allocate
3. Select floating IP pool (external network)
4. IP allocated and shown in list

**Associate Floating IP:**

1. Navigate to floating IPs (`l`)
2. Select unassociated IP
3. Press `A` for associate
4. Select target server
5. Select server port
6. Confirm association

**Disassociate Floating IP:**

1. Select associated floating IP
2. Press `D` for disassociate
3. Confirm disassociation
4. IP returned to pool

## Storage Management

### List Volumes

1. Press `v` for volumes
2. View all volumes
3. Press `Space` for volume details
4. See size, type, attachments, status

### Create Volume

1. Press `v` for volumes
2. Press `C` for create
3. Fill in volume form:
   - **Name**: Volume name
   - **Size**: Size in GB
   - **Volume Type** (optional)
   - **Source**: Empty, image, snapshot, or volume
4. Press `Enter` to create

### Attach Volume to Server

1. Navigate to volumes (`v`)
2. Select available volume
3. Press `A` for attach
4. Select target server
5. Optionally specify device path
6. Confirm attachment

### Detach Volume from Server

1. Select attached volume
2. Press `X` or `D` for detach
3. Confirm detachment
4. Volume returns to available state

### Create Volume Snapshot

1. Select volume to snapshot
2. Press `P` for snapshot
3. Enter snapshot name
4. Snapshot created
5. View in volume snapshots list

### Extend Volume Size

1. Select volume to extend
2. Press `E` for extend
3. Enter new size (must be larger)
4. Confirm extension
5. Volume size updated

## Image Management

### List Images

1. Press `i` for images
2. View all images in project
3. Use `/` to filter by name
4. Press `Space` for image details

### Upload Image

1. Press `i` for images
2. Press `C` for create
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

1. Navigate to any resource list
2. Press `/` to activate search
3. Type query (filters as you type)
4. Results update instantly
5. Press `Esc` to clear search

**Example:**

```
In servers list:
/ → type "web" → shows only servers with "web" in name
```

### Cross-Service Search (Comprehensive)

Search across all OpenStack services:

1. Press `z` for advanced search
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

**Example Queries:**

- `prod` - Find all production resources
- `192.168.1` - Find resources with this IP
- `ubuntu` - Find all Ubuntu-related resources
- `error` - Find resources in error state

## Troubleshooting Workflows

### Debug Server Issues

1. **Check Server Status:**
   - Press `s` for servers
   - Find problem server
   - Press `Space` for details
   - Note status and error message

2. **View Console Logs:**
   - Select server
   - Press `L` for logs
   - Review boot sequence
   - Look for errors

3. **Check Network Connectivity:**
   - Press `p` for ports
   - Find server ports
   - Verify network attachment
   - Check security groups

4. **Check Volume Attachments:**
   - Press `v` for volumes
   - Verify volume status
   - Check attachment to server

### Investigate Network Issues

1. **Verify Router Configuration:**
   - Press `r` for routers
   - Check router status
   - Verify gateway configuration
   - Check subnet attachments

2. **Check Security Rules:**
   - Press `e` for security groups
   - Review applied groups
   - Check rule configurations
   - Verify protocol and port settings

3. **Check Floating IP Associations:**
   - Press `l` for floating IPs
   - Verify IP associations
   - Check router external gateway

### Cache and Performance Issues

**Stale Data:**

1. Press `c` to purge ALL caches
2. Press `r` to refresh current view
3. Fresh data loaded from API

**Slow Performance:**

1. Press `h` for health dashboard
2. Check API response times
3. Check cache hit rates (target: 80%+)
4. Enable wiretap if needed: `substation --wiretap`

## Batch Operations

### Delete Multiple Resources

While Substation doesn't currently have built-in batch delete UI:

1. Use advanced search (`z`) to find resources
2. Note resource IDs/names
3. Use OpenStack CLI for batch operations:

   ```bash
   for id in $resource_ids; do
       openstack server delete $id
   done
   ```

### Monitor Build Progress

1. Create resources (servers, volumes, etc.)
2. Resources show "BUILD" status
3. Auto-refresh updates status
4. Press `a` to toggle auto-refresh
5. Wait for "ACTIVE" status

## Tips and Tricks

### Efficient Resource Creation

1. Learn the create form flow for each resource type
2. Use Tab to navigate fields quickly
3. Use flavor recommendation mode for servers
4. Keep frequently used images/networks at the top of your lists

### Quick Status Checks

1. Press `h` for health dashboard
2. See all services at a glance
3. Check performance metrics
4. Monitor cache effectiveness

### Keyboard Efficiency

1. Memorize main navigation keys (`d`, `s`, `n`, `v`, `i`)
2. Use `/` for quick filtering
3. Use `z` for comprehensive search
4. Press `?` when you forget a shortcut

### Data Freshness

1. Press `r` to refresh current view (uses cache if valid)
2. Press `c` to force fresh data from API (purges cache)
3. Use auto-refresh (`a`) for real-time monitoring
4. Check cache hit rate in health dashboard (`h`)

---

**Remember**: Practice makes perfect. The more you use these workflows, the faster you'll become. Before long, you'll be managing OpenStack faster than Horizon could ever dream.

*Speed is a feature. Learn the shortcuts.*
