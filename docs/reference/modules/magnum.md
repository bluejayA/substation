# Magnum Module

## Overview

**Service:** OpenStack Magnum (Container Orchestration Engine)
**Identifier:** `magnum`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Magnum/`

The Magnum module provides comprehensive management of OpenStack Container Infrastructure resources. It enables users to create, manage, and monitor Kubernetes and Docker Swarm clusters through an intuitive terminal interface. The module supports cluster lifecycle operations, template management, and cluster scaling.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Clusters and cluster templates with status indicators |
| **Detail View** | Yes | Comprehensive cluster and template details with nodegroups |
| **Create/Edit** | Yes | Full cluster and cluster template creation forms |
| **Batch Operations** | Yes | Bulk deletion of clusters and templates |
| **Multi-Select** | Yes | Select multiple clusters or templates for batch operations |
| **Search/Filter** | Yes | Filter by name, UUID, COE type, image ID |
| **Auto-Refresh** | Yes | Periodic refresh of cluster and template lists |
| **Health Monitoring** | Yes | Cluster status tracking and health checks |

## Dependencies

### Required Modules

- None (Magnum is a standalone module with no hard dependencies)

### Optional Modules

- **Flavors** - Used for selecting compute flavors in cluster templates
- **Images** - Used for selecting node images in cluster templates
- **Networks** - Used for selecting external networks in cluster templates
- **Keypairs** - Used for selecting SSH keypairs for cluster access

## Features

### Resource Management

- **Cluster Management**: Create, resize, and delete Kubernetes/Swarm clusters
- **Template Management**: Create and manage cluster templates
- **Nodegroup Viewing**: View nodegroup details within clusters
- **Kubeconfig Download**: Download kubeconfig files for cluster access
- **Status Monitoring**: Real-time status tracking with visual indicators

### List Operations

The cluster list provides a comprehensive view of all container clusters with status-based filtering and multi-select support.

**Available Actions:**

- `Enter` - View detailed cluster information
- `c` - Create a new cluster
- `d` - Delete selected cluster
- `r` - Resize cluster (scale worker nodes)
- `k` - Download kubeconfig for cluster
- `t` - Switch to cluster templates view
- `/` - Search clusters by name or properties
- `Space` - Toggle multi-select for batch operations
- `Tab` - Switch between views

### Detail View

Displays comprehensive cluster information including configuration, node counts, addresses, and associated resources.

**Displayed Information:**

- **Basic Information**: UUID, name, status, status reason
- **Configuration**: Cluster template, COE version, keypair, timeout
- **Node Counts**: Total nodes, master count, worker count
- **Node Addresses**: Master and worker node IP addresses
- **API Access**: Kubernetes API endpoint
- **Nodegroups**: List of nodegroups with role and status
- **Network Configuration**: Floating IP and master load balancer status
- **Labels**: Custom cluster labels
- **Infrastructure**: Heat stack ID, discovery URL
- **Ownership**: Project ID, user ID
- **Timestamps**: Creation and update times

### Create/Edit Operations

The module provides full-featured forms for creating clusters and cluster templates.

**Cluster Creation Form Fields:**

- Cluster Name (required)
- Cluster Template (required, selector)
- SSH Keypair (optional, selector)
- Master Nodes count (required, 1-10)
- Worker Nodes count (required, 1-100)
- Create Timeout in minutes (optional, 10-1440)

**Cluster Template Creation Form Fields:**

- Template Name (required)
- Container Engine (required, Kubernetes/Docker Swarm)
- Node Image (required, selector)
- External Network (optional, selector)
- Worker Flavor (optional, selector)
- Master Flavor (optional, selector)
- SSH Keypair (optional, selector)
- Docker Volume Size in GB (optional, 1-1000)
- Network Driver (optional, Flannel/Calico)
- Enable Floating IPs (toggle)
- Enable Master Load Balancer (toggle)

### Batch Operations

The module supports bulk operations for efficient resource management.

**Supported Batch Operations:**

- `clusterBulkDelete` - Delete multiple clusters simultaneously
- `clusterTemplateBulkDelete` - Delete multiple cluster templates

**Deletion Priority:** 4 (early deletion - clusters are high-level resources)

**Error Handling:**

- HTTP 404 errors treated as success for idempotent behavior
- Validation checks for clusters in-progress or already being deleted
- Warnings for templates in use by active clusters

## API Endpoints

### Primary Endpoints

- `GET /clusters` - List all clusters
- `GET /clusters/{cluster_id}` - Get specific cluster details
- `POST /clusters` - Create a new cluster
- `DELETE /clusters/{cluster_id}` - Delete a cluster
- `POST /clusters/{cluster_id}/actions/resize` - Resize cluster

### Secondary Endpoints

- `GET /clusters/{cluster_id}/config` - Get cluster kubeconfig
- `GET /clusters/{cluster_id}/nodegroups` - List cluster nodegroups
- `GET /clustertemplates` - List all cluster templates
- `GET /clustertemplates/{template_id}` - Get template details
- `POST /clustertemplates` - Create a cluster template
- `DELETE /clustertemplates/{template_id}` - Delete a cluster template

## Configuration

### Module Settings

```swift
MagnumModule(
    identifier: "magnum",
    displayName: "Container Infra (Magnum)",
    version: "1.0.0",
    cacheEnabled: true
)
```

### Environment Variables

- `CLUSTER_LIST_LIMIT` - Maximum clusters per page (Default: `100`)
- `CLUSTER_CACHE_TTL` - Cache lifetime in seconds (Default: `60`)
- `TEMPLATE_CACHE_TTL` - Template cache lifetime in seconds (Default: `120`)

### Performance Tuning

- **Cache Duration**: Clusters refresh every 60 seconds, templates every 120 seconds
- **Parallel Fetching**: Clusters and templates are fetched concurrently
- **Timeout Configuration**: Configurable timeouts based on fetch priority
  - Critical: 30 seconds
  - Secondary: 20 seconds
  - Background: 10 seconds
  - On-Demand: 30 seconds
  - Fast: 15 seconds

## Views

### Registered View Modes

#### Cluster List (`clusters`)

**Purpose:** Display and browse container clusters

**Key Features:**

- Status-based coloring (green=complete, yellow=in-progress, red=failed)
- Node count columns (total, masters, workers)
- Multi-select mode for batch operations
- Search and filter capabilities

**Navigation:**

- **Enter from:** Main menu, cluster templates view
- **Exit to:** Cluster detail view, main menu

#### Cluster Detail (`clusterDetail`)

**Purpose:** Display comprehensive cluster information and configuration

**Key Features:**

- Scrollable detail sections
- Nodegroup information display
- Associated template details
- Node addresses listing

**Navigation:**

- **Enter from:** Cluster list view
- **Exit to:** Cluster list view

#### Cluster Create (`clusterCreate`)

**Purpose:** Create a new container cluster

**Key Features:**

- Form-based input with validation
- Template and keypair selectors
- Configurable node counts
- Real-time validation feedback

**Navigation:**

- **Enter from:** Cluster list view (c key)
- **Exit to:** Cluster list view

#### Cluster Resize (`clusterResize`)

**Purpose:** Scale cluster worker nodes

**Key Features:**

- Current node count display
- Increment/decrement controls
- Scale up/down indicators
- Submission confirmation

**Navigation:**

- **Enter from:** Cluster list or detail view (r key)
- **Exit to:** Cluster detail view

#### Cluster Templates (`clusterTemplates`)

**Purpose:** Display and browse cluster templates

**Key Features:**

- COE type indicators with color coding
- Network driver and server type columns
- Public/private visibility indicators
- Multi-select for batch deletion

**Navigation:**

- **Enter from:** Cluster list view (t key), main menu
- **Exit to:** Template detail view, main menu

#### Cluster Template Detail (`clusterTemplateDetail`)

**Purpose:** Display comprehensive template configuration

**Key Features:**

- Compute configuration details
- Network and storage settings
- Security configuration
- Proxy settings and labels

**Navigation:**

- **Enter from:** Cluster templates list view
- **Exit to:** Cluster templates list view

#### Cluster Template Create (`clusterTemplateCreate`)

**Purpose:** Create a new cluster template

**Key Features:**

- COE selection (Kubernetes/Swarm)
- Image, flavor, and network selectors
- Toggle fields for floating IPs and load balancer
- Docker volume configuration

**Navigation:**

- **Enter from:** Cluster templates view (C key)
- **Exit to:** Cluster templates list view

## Keyboard Shortcuts

### Global Shortcuts (Available in all module views)

| Key | Action | Context |
|-----|--------|---------|
| `Enter` | Select/View Details | List views |
| `Esc` | Go Back | Any view |
| `q` | Quit to Main Menu | Any view |
| `/` | Search | List views |
| `Space` | Toggle Selection | Multi-select mode |

### Module-Specific Shortcuts

| Key | Action | View | Description |
|-----|--------|------|-------------|
| `c` | Create Cluster | Clusters | Open cluster creation form |
| `C` | Create Template | Templates | Open template creation form |
| `d` | Delete | List views | Delete selected resource |
| `r` | Resize | Clusters | Open cluster resize form |
| `k` | Kubeconfig | Clusters | Download cluster kubeconfig |
| `t` | Templates | Clusters | Switch to templates view |
| `+`/`=` | Increment | Resize | Increase node count |
| `-`/`_` | Decrement | Resize | Decrease node count |
| `Tab` | Navigate | Forms | Move between form fields |

## Data Provider

**Provider Class:** `MagnumDataProvider`

### Caching Strategy

Magnum resources are cached with different TTLs based on update frequency:

- **Clusters**: 60-second refresh interval (frequently changing status)
- **Cluster Templates**: 120-second refresh interval (relatively static)
- **Nodegroups**: Fetched on-demand when viewing cluster details

### Refresh Patterns

- **Automatic Refresh**: Clusters every 60 seconds, templates every 120 seconds
- **Manual Refresh**: On-demand with refresh action
- **Startup Load**: Full refresh on module initialization
- **Post-Operation Refresh**: Automatic refresh after create/delete operations

### Performance Optimizations

- **Parallel Fetching**: Clusters and templates fetched concurrently
- **Lazy Nodegroup Loading**: Nodegroups loaded only when viewing cluster details
- **Priority-Based Timeouts**: Different timeout values for different fetch priorities
- **Cache Updates**: Local cache updated immediately after operations

## Known Limitations

### Current Constraints

- **Single COE Support**: Limited to Kubernetes and Docker Swarm
- **Resize Scope**: Only worker nodes can be resized, not master nodes
- **Nodegroup Management**: View-only for nodegroups, no create/edit
- **Label Editing**: Labels cannot be modified after cluster creation
- **Cluster Upgrade**: No in-place cluster upgrade support

### Planned Improvements

- Nodegroup creation and management
- Cluster upgrade workflows
- Label editing for existing clusters
- Federation support for multi-cluster management
- Cost estimation based on flavor selection

## Examples

### Common Usage Scenarios

#### Creating a New Kubernetes Cluster

```
1. Navigate to Clusters module from main menu
2. Press 'c' to open cluster creation form
3. Enter cluster name (e.g., "production-k8s")
4. Select cluster template from dropdown
5. Choose SSH keypair for node access
6. Set master node count (e.g., 3 for HA)
7. Set worker node count (e.g., 5)
8. Optionally adjust create timeout
9. Press Enter to submit creation request
10. Monitor cluster status in list view
```

#### Scaling Cluster Workers

```
1. Navigate to Clusters module
2. Select the cluster to resize
3. Press 'r' to open resize form
4. Use +/- keys to adjust worker count
5. Review scale up/down indicator
6. Press Enter to submit resize request
7. Monitor cluster status during resize
```

#### Creating a Cluster Template

```
1. Navigate to Clusters module
2. Press 't' to switch to templates view
3. Press 'C' (shift+c) to create template
4. Enter template name
5. Select container engine (Kubernetes/Swarm)
6. Choose node image from available images
7. Configure network and flavor settings
8. Enable/disable floating IPs and load balancer
9. Press Enter to create template
```

#### Downloading Kubeconfig

```
1. Navigate to Clusters module
2. Select an active cluster
3. Press 'k' to download kubeconfig
4. File saved to ~/kubeconfig-<cluster-name>.yaml
5. Use with: export KUBECONFIG=~/kubeconfig-<name>.yaml
```

### Code Examples

#### Programmatic Access

```swift
// Access Magnum module through registry
let module = ModuleRegistry.shared.module(for: "magnum") as? MagnumModule

// Get cached clusters
let clusters = module?.clusters ?? []

// Filter active clusters
let activeClusters = clusters.filter { $0.isActive }

// Get cluster templates
let templates = module?.clusterTemplates ?? []
```

#### Custom Integration

```swift
// Register custom action handler
extension MagnumModule {
    func customClusterAnalysis(cluster: Cluster) -> ClusterHealth {
        // Custom analysis logic
        let nodeHealth = evaluateNodeHealth(cluster)
        let resourceUtilization = calculateUtilization(cluster)

        return ClusterHealth(
            status: cluster.status,
            nodeHealth: nodeHealth,
            utilization: resourceUtilization
        )
    }
}
```

## Troubleshooting

### Common Issues

#### Clusters Not Loading

**Symptoms:** Empty cluster list or loading errors
**Cause:** Magnum service issues, authentication problems, or network connectivity
**Solution:**
- Verify Magnum service is enabled in your OpenStack deployment
- Check user permissions for container-infra resources
- Verify network connectivity to Magnum API endpoint

#### Cluster Creation Fails

**Symptoms:** Cluster stuck in CREATE_IN_PROGRESS or moves to CREATE_FAILED
**Cause:** Resource quotas, Heat stack issues, or image problems
**Solution:**
- Check Heat stack status for detailed error messages
- Verify sufficient quotas for instances, volumes, and networks
- Ensure selected image is compatible with COE version

#### Kubeconfig Download Fails

**Symptoms:** Error when attempting to download kubeconfig
**Cause:** Cluster not yet active or API endpoint not ready
**Solution:**
- Wait for cluster status to show CREATE_COMPLETE
- Verify cluster API address is populated
- Check master node health

#### Template Creation Fails

**Symptoms:** Error creating cluster template
**Cause:** Missing required resources or invalid configuration
**Solution:**
- Verify selected image exists and is active
- Check external network is properly configured
- Ensure selected flavors have sufficient resources

### Debug Commands

- `openstack coe cluster list` - List all clusters via CLI
- `openstack coe cluster show <cluster>` - Show cluster details
- `openstack coe cluster template list` - List cluster templates
- `openstack coe nodegroup list <cluster>` - List cluster nodegroups
- Check logs in `~/.substation/logs/magnum.log`

## Related Documentation

- [Module Catalog](./index.md)
- [Flavors Module](./flavors.md)
- [Images Module](./images.md)
- [Networks Module](./networks.md)
- [Keypairs Module](./keypairs.md)
- [OpenStack Magnum Documentation](https://docs.openstack.org/magnum/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `magnum` |
| **Display Name** | Container Infra (Magnum) |
| **Version** | 1.0.0 |
| **Service** | Magnum |
| **Category** | Compute Infrastructure |
| **Deletion Priority** | 4 |
| **Load Order** | 10 |
| **Memory Usage** | ~5-15 MB |
| **CPU Impact** | Low-Medium |

---

*Last Updated: January 2025*
*Documentation Version: 1.0.0*
