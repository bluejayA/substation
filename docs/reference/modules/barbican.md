# Barbican Module

## Overview

**Service:** OpenStack Barbican (Key Manager)
**Identifier:** `barbican`
**Version:** 1.0.0
**Location:** `/Sources/Substation/Modules/Barbican/`

The Barbican module provides secure key management capabilities for OpenStack Barbican service. It enables users to store, manage, and retrieve secrets including encryption keys, passwords, certificates, and other sensitive data. The module offers a comprehensive interface for secret lifecycle management with strong security controls and audit capabilities.

## Quick Reference

| Feature | Supported | Details |
|---------|-----------|---------|
| **List View** | Yes | Secret listing with type, status, and expiration info |
| **Detail View** | Yes | Comprehensive secret details with metadata and properties |
| **Create/Edit** | Yes | Secret creation with multiple payload types |
| **Batch Operations** | Yes | Bulk delete secrets |
| **Multi-Select** | Yes | Select multiple secrets for batch operations |
| **Search/Filter** | Yes | Search by name, type, or algorithm |
| **Auto-Refresh** | Yes | 60-second interval for secret list |
| **Health Monitoring** | Yes | Service availability checking |

## Dependencies

### Required Modules

This module has no required dependencies and can operate independently.

### Optional Modules

- **Volumes** - Integration for volume encryption key management
- **Servers** - SSH key and password management for instances

## Features

### Resource Management

- **Secret Storage**: Store passwords, keys, certificates, and arbitrary data
- **Secret Types**: Support for symmetric keys, public keys, private keys, certificates, passphrases, and opaque data
- **Encryption**: Automatic encryption at rest with key rotation
- **Access Control**: Project-scoped access with ACL support
- **Expiration Management**: Set expiration dates for time-limited secrets
- **Audit Trail**: Track secret access and modifications
- **Container Support**: Group related secrets in containers

### List Operations

The secret list view provides an overview of all stored secrets with filtering capabilities.

**Available Actions:**

- `Enter` - View detailed secret information
- `c` - Create new secret
- `d` - Delete selected secret(s)
- `r` - Refresh secret list
- `/` - Search secrets
- `Space` - Toggle multi-select mode

### Detail View

Displays comprehensive information about a selected secret including cryptographic details.

**Displayed Information:**

- **Basic Info**: Name, ID, status, type, algorithm
- **Cryptographic Details**: Algorithm, bit length, mode
- **Lifecycle**: Created date, expiration date, status
- **Content Encoding**: Base64, hex, or plaintext
- **Metadata**: Custom metadata and system properties
- **Access Info**: Creator, project scope, ACLs
- **Payload Info**: Content type and encoding

### Create/Edit Operations

Secret creation supports multiple payload types and cryptographic configurations.

**Form Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Secret identifier name |
| Secret Type | Select | Yes | symmetric, public, private, certificate, passphrase, opaque |
| Payload | Text/File | Yes | Secret content (base64 or plain) |
| Payload Content Type | Select | Yes | text/plain, application/octet-stream |
| Content Encoding | Select | Yes | base64, hex, or none |
| Algorithm | Select | Conditional | AES, RSA, etc. (for keys) |
| Bit Length | Integer | Conditional | Key size in bits |
| Mode | Select | Conditional | CBC, GCM, etc. (for symmetric) |
| Expiration | Date | No | Optional expiration date |

### Batch Operations

The module supports batch operations for efficient secret management.

**Supported Batch Actions:**

- **Bulk Delete**: Delete multiple secrets at once
- **Bulk Export**: Export selected secrets (planned)
- **Bulk Rotation**: Rotate multiple keys (planned)

## API Endpoints

### Primary Endpoints

- `GET /v1/secrets` - List all secrets
- `GET /v1/secrets/{secret_id}` - Get secret metadata
- `GET /v1/secrets/{secret_id}/payload` - Retrieve secret payload
- `POST /v1/secrets` - Store new secret
- `DELETE /v1/secrets/{secret_id}` - Delete secret
- `PUT /v1/secrets/{secret_id}` - Update secret metadata

### Secondary Endpoints

- `GET /v1/secret-stores` - List available secret stores
- `GET /v1/secrets/{secret_id}/metadata` - Get secret metadata
- `PUT /v1/secrets/{secret_id}/metadata` - Update metadata
- `GET /v1/quota` - Get quota information
- `POST /v1/containers` - Create secret container

## Configuration

### Module Settings

```swift
// Module initialization
let barbicanModule = BarbicanModule(tui: tui)

// Configuration
await barbicanModule.configure()

// Health check
let health = await barbicanModule.healthCheck()
```

### Performance Tuning

- **Cache TTL**: 60 seconds for secret list
- **Payload Retrieval**: On-demand only (never cached)
- **Metadata Cache**: 5 minutes for unchanged secrets

## Views

### Registered View Modes

#### Barbican Main View (`.barbican`)

**Purpose:** Main Barbican module dashboard and navigation hub

**Key Features:**

- Overview of secret counts by type
- Recent activity display
- Quick navigation to secrets
- Service health indicators

**Navigation:**

- **Enter from:** Main menu via `:barbican` command
- **Exit to:** Main menu or secrets list

#### Secret List (`.barbicanSecrets`)

**Purpose:** Display and manage all secrets in the project

**Key Features:**

- Type indicators (key, certificate, password icons)
- Expiration warnings
- Algorithm display
- Status indicators

**Navigation:**

- **Enter from:** Main menu, dashboard
- **Exit to:** Secret detail, create form, main menu

#### Secret Detail (`.barbicanSecretDetail`)

**Purpose:** Show comprehensive secret information

**Key Features:**

- Metadata display
- Cryptographic properties
- Audit information
- Expiration status

**Navigation:**

- **Enter from:** Secret list
- **Exit to:** Secret list

#### Secret Create (`.barbicanSecretCreate`)

**Purpose:** Form for storing new secrets

**Key Features:**

- Type-specific fields
- Encoding options
- Algorithm selection
- Expiration setting

**Navigation:**

- **Enter from:** Secret list
- **Exit to:** Secret list

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
| `c` | Create Secret | Secret List | Open secret creation form |
| `d` | Delete | Secret List | Delete selected secret(s) |
| `Space` | Multi-Select | Secret List | Toggle multi-selection mode |
| `e` | Export | Secret Detail | Export secret (if permitted) |
| `m` | Metadata | Secret Detail | Edit secret metadata |

## Data Provider

**Provider Class:** `BarbicanDataProvider`

### Caching Strategy

The module implements secure caching with automatic expiration. Secret metadata is cached but payloads are never cached for security reasons.

### Refresh Patterns

- **List Refresh**: Automatic every 60 seconds
- **Detail Refresh**: On-demand only
- **Payload Fetch**: Never cached, always fresh

### Performance Optimizations

- **Metadata Only**: List operations fetch only metadata
- **Lazy Payload**: Secret content retrieved only when needed
- **Batch Fetch**: Multiple secrets fetched in parallel

## Known Limitations

### Current Constraints

- **Payload Size**: Maximum secret size limited by Barbican configuration
- **Container UI**: Container management not fully implemented
- **ACLs**: Access control list management limited
- **Rotation**: Automatic key rotation not available in UI

### Planned Improvements

- Container management interface
- ACL configuration UI
- Secret sharing between projects
- Key rotation scheduling
- Certificate chain validation

## Examples

### Common Usage Scenarios

#### Storing an SSH Key

```
1. Press 'c' in secret list to create
2. Select "private" as secret type
3. Enter key name
4. Paste private key content
5. Set payload content type to "text/plain"
6. Select "RSA" as algorithm
7. Submit to store securely
```

#### Storing Database Password

```
1. Press 'c' to create new secret
2. Select "passphrase" as type
3. Enter descriptive name
4. Enter password as payload
5. Set optional expiration date
6. Submit to store
```

#### Storing TLS Certificate

```
1. Create new secret with 'c'
2. Select "certificate" type
3. Name it appropriately
4. Paste PEM-encoded certificate
5. Set content type to "text/plain"
6. Set encoding to "base64" if needed
7. Submit form
```

### Code Examples

#### Programmatic Access

```swift
// Store a secret
let secretRequest = SecretCreateRequest(
    name: "api-key",
    secretType: "passphrase",
    payload: "super-secret-key",
    payloadContentType: "text/plain"
)
let secret = await tui.client.createSecret(secretRequest)

// Retrieve secret payload
let payload = await tui.client.getSecretPayload(secretId: secret.id)
```

#### Custom Integration

```swift
// Rotate encryption keys
let oldSecret = await tui.client.getSecret(id: oldKeyId)
let newSecret = SecretCreateRequest(
    name: "\(oldSecret.name)-rotated",
    secretType: oldSecret.secretType,
    algorithm: oldSecret.algorithm,
    bitLength: oldSecret.bitLength
)
await tui.client.createSecret(newSecret)
```

## Troubleshooting

### Common Issues

#### Secret Creation Fails

**Symptoms:** Error when submitting secret form
**Cause:** Invalid payload encoding or size limit exceeded
**Solution:** Check encoding matches content, verify size limits

#### Cannot Retrieve Payload

**Symptoms:** Payload fetch returns error
**Cause:** Insufficient permissions or secret expired
**Solution:** Verify ACLs, check expiration date

#### Search Not Working

**Symptoms:** Search returns no results
**Cause:** Search limited to metadata fields
**Solution:** Search by name, type, or algorithm only

### Debug Commands

- Check Barbican service status in Health Dashboard
- Verify project quota usage
- Review secret ACLs and permissions
- Check secret expiration dates

## Related Documentation

- [Module Catalog](./index.md)
- [Volumes Module](./volumes.md) - For encryption key usage
- [Servers Module](./servers.md) - For SSH key management
- [OpenStack Barbican Documentation](https://docs.openstack.org/barbican/latest/)

## Module Metadata

| Property | Value |
|----------|-------|
| **Module Identifier** | `barbican` |
| **Display Name** | Key Manager (Barbican) |
| **Version** | 1.0.0 |
| **Service** | OpenStack Barbican |
| **Category** | Security |
| **Deletion Priority** | 10 |
| **Load Order** | 90 |
| **Memory Usage** | ~5 MB typical |
| **CPU Impact** | Minimal |

---

*Last Updated: January 2025*
*Documentation Version: 1.1.0*
