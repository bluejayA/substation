# KeyPairs Module

## Overview

**Service:** Nova (Compute Service)
**Identifier:** `keypairs`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/KeyPairs/`

The KeyPairs module manages SSH key pairs used for secure access to OpenStack instances. It provides functionality for importing, managing, and deleting SSH keys that are injected into instances at launch time for passwordless authentication.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Display all key pairs with fingerprints |
| **Detail View** | Yes | Key properties and security analysis |
| **Create/Edit** | Yes | Import existing public keys |
| **Batch Operations** | Yes | Bulk deletion of key pairs |
| **Multi-Select** | Yes | Select multiple keys for batch operations |
| **Search/Filter** | Yes | Search by name or fingerprint |
| **Auto-Refresh** | Yes | Periodic refresh of key list |
| **Health Monitoring** | Yes | Key validation and security checks |

## Dependencies

### Required Modules

- None (KeyPairs is a base module with no dependencies)

### Optional Modules

- **Servers** - Uses key pairs for instance SSH access
- **Security Groups** - Works with SSH security rules

## Features

### Resource Management

- **Key Pair Import**: Import existing SSH public keys
- **Key Listing**: View all available key pairs
- **Fingerprint Verification**: Validate key fingerprints
- **Security Analysis**: Check key strength and type
- **Usage Tracking**: Monitor which instances use each key

### List Operations

The key pair list provides a comprehensive view of all SSH keys with security indicators.

**Available Actions:**

- `Enter` - View key pair details
- `c` - Create/import new key pair
- `d` - Delete selected key pair
- `/` - Search key pairs
- `r` - Refresh key list
- `Space` - Select for batch operations

### Detail View

Displays complete information about a selected key pair including security properties and usage.

**Displayed Information:**

- **Basic Info**: Name, fingerprint, type (ssh/x509)
- **Security Properties**: Key algorithm, key length, creation date
- **Public Key**: Full public key content (when available)
- **Usage Information**: List of instances using this key
- **Security Assessment**: Key strength evaluation

### Create/Edit Operations

Import existing SSH public keys into OpenStack for use with instances.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Unique identifier for the key pair |
| Public Key | Text Area | Yes | SSH public key content |
| Type | Select | No | Key type (ssh-rsa, ssh-ed25519, etc.) |

### Batch Operations

Efficiently manage multiple key pairs with bulk operations.

**Supported Batch Actions:**

- **Bulk Delete**: Remove multiple unused key pairs
- **Security Audit**: Check multiple keys for compliance

## API Endpoints

### Primary Endpoints

- `GET /os-keypairs` - List all key pairs
- `POST /os-keypairs` - Create/import key pair
- `GET /os-keypairs/{keypair_name}` - Get key pair details
- `DELETE /os-keypairs/{keypair_name}` - Delete key pair

### Secondary Endpoints

- `GET /os-keypairs/{keypair_name}/servers` - List servers using key

## Configuration

### Module Settings

```swift
KeyPairsModule(
    identifier: "keypairs",
    displayName: "SSH KeyPairs",
    version: "1.0.0",
    deletionPriority: 8
)
```

### Environment Variables

- `KEYPAIR_LIST_LIMIT` - Maximum key pairs per page (Default: `50`)
- `KEYPAIR_CACHE_TTL` - Cache lifetime in seconds (Default: `120`)
- `VALIDATE_KEY_FORMAT` - Validate key format on import (Default: `true`)

### Performance Tuning

- **Cache Duration**: Adjust based on key creation frequency
- **Validation**: Disable format validation for trusted keys
- **List Size**: Paginate large key pair collections

## Views

### Registered View Modes

#### KeyPair List (`keyPairs`)

**Purpose:** Display and manage SSH key pairs

**Key Features:**

- Key name and fingerprint display
- Security indicator icons
- Usage count per key
- Multi-select for batch operations

**Navigation:**

- **Enter from:** Main menu, server creation workflow
- **Exit to:** Key pair detail, creation form, main menu

#### KeyPair Detail (`keyPairDetail`)

**Purpose:** Display comprehensive key pair information

**Key Features:**

- Full public key display
- Security analysis results
- Instance usage list
- Fingerprint verification

**Navigation:**

- **Enter from:** Key pair list
- **Exit to:** Key pair list

#### KeyPair Create (`keyPairCreate`)

**Purpose:** Import new SSH public key

**Key Features:**

- Public key validation
- Name uniqueness check
- Format detection
- Import confirmation

**Navigation:**

- **Enter from:** Key pair list, server creation
- **Exit to:** Key pair list with new key selected

## Keyboard Shortcuts

### Global Shortcuts (Available in all module views)

| Key | Action | Context |
|-----|--------|---------|
| `Enter` | Select/View Details | List views |
| `Esc` | Go Back | Any view |
| `q` | Quit to Main Menu | Any view |
| `/` | Search | List views |
| `r` | Refresh | List views |

### Module-Specific Shortcuts

| Key | Action | View | Description |
|-----|--------|------|-------------|
| `c` | Create/Import | List | Open key import form |
| `d` | Delete | List/Detail | Delete selected key pair |
| `Space` | Toggle Selection | List | Select for batch operations |
| `a` | Select All | List | Select all visible keys |
| `A` | Deselect All | List | Clear all selections |
| `v` | Verify | Detail | Verify key fingerprint |
| `Tab` | Switch View | Any | Toggle between views |

## Data Provider

**Provider Class:** `KeyPairsDataProvider`

### Caching Strategy

Key pairs are cached with moderate TTL as they change infrequently but need fresh usage data.

### Refresh Patterns

- **Automatic Refresh**: Every 2 minutes
- **Manual Refresh**: On-demand with 'r' key
- **Post-Operation**: After create/delete operations

### Performance Optimizations

- **Lightweight Listing**: Minimal data in list view
- **Lazy Loading**: Full key content loaded on detail view
- **Usage Caching**: Instance associations cached separately

## Known Limitations

### Current Constraints

- **Key Generation**: Cannot generate new key pairs (import only)
- **Private Keys**: No private key storage or retrieval
- **Key Rotation**: Manual process for key replacement
- **Format Support**: Limited to SSH-RSA and SSH-ED25519

### Planned Improvements

- Key pair generation with private key download
- Automated key rotation workflows
- Support for X.509 certificates
- Key expiration tracking

## Examples

### Common Usage Scenarios

#### Importing SSH Key for New Instances

```
1. Navigate to KeyPairs module
2. Press 'c' to create/import
3. Enter unique key name
4. Paste public key content
5. Confirm import
6. Key available for instance creation
```

#### Cleaning Up Unused Keys

```
1. Enter KeyPairs module
2. Review usage counts in list
3. Select unused keys with Space
4. Press 'd' for batch delete
5. Confirm deletion of selected keys
```

#### Verifying Key for Security Audit

```
1. Navigate to key pair list
2. Select key and press Enter
3. Review security properties
4. Check key algorithm and length
5. Verify fingerprint matches local copy
```

### Code Examples

#### Programmatic Access

```swift
// Import a new key pair
let keyPair = KeyPairCreateForm(
    name: "deployment-key",
    publicKey: "ssh-rsa AAAAB3NzaC1yc2EA..."
)
let result = await tui.client.createKeyPair(keyPair)

// List all key pairs
let provider = DataProviderRegistry.shared.provider(for: "keypairs")
let keyPairs = await provider.fetchData()
```

#### Custom Integration

```swift
// Add key security validator
extension KeyPairsModule {
    func validateKeyStrength(_ publicKey: String) -> SecurityLevel {
        let keyData = parsePublicKey(publicKey)

        if keyData.algorithm == "ssh-ed25519" {
            return .high
        } else if keyData.algorithm == "ssh-rsa" && keyData.bits >= 4096 {
            return .medium
        } else {
            return .low
        }
    }
}
```

## Troubleshooting

### Common Issues

#### Key Import Fails

**Symptoms:** Error when importing public key
**Cause:** Invalid key format or duplicate name
**Solution:** Verify key format and use unique name

#### Keys Not Appearing in Server Creation

**Symptoms:** Imported keys not available for instances
**Cause:** Cache delay or permission issues
**Solution:** Refresh key list or check user permissions

#### Cannot Delete Key Pair

**Symptoms:** Deletion fails with error
**Cause:** Key in use by running instances
**Solution:** Key can be deleted even if in use (instances retain key)

### Debug Commands

- `openstack keypair list` - List all key pairs
- `openstack keypair show <name>` - Show key details
- `ssh-keygen -l -f <keyfile>` - Verify local key fingerprint
- Check logs in `~/.substation/logs/keypairs.log`

## Related Documentation

- [Module Catalog](./index.md)
- [Servers Module](./servers.md)
- [Security Groups Module](./securitygroups.md)
- [OpenStack Nova SSH Keys Documentation](https://docs.openstack.org/nova/latest/user/ssh.html)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `keypairs` |
| **Display Name** | SSH KeyPairs |
| **Version** | 1.0.0 |
| **Service** | Nova |
| **Category** | Security |
| **Deletion Priority** | 8 |
| **Load Order** | 15 |
| **Memory Usage** | ~1-2 MB |
| **CPU Impact** | Minimal |

---

*Last Updated: 2025-11-23*
*Documentation Version: 1.0.0*
