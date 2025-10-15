# Object Storage Concepts

## Overview

OpenStack Swift (Object Storage) provides scalable, redundant storage for unstructured data. Substation implements comprehensive Swift integration with intelligent optimization, background operations, and robust error handling.

## Core Concepts

### Containers

Containers are the top-level organizational unit in Swift, similar to buckets in other object storage systems.

**Key Properties:**

- **Name**: Unique identifier within a project
- **Metadata**: Custom key-value pairs for container configuration
- **ACLs**: Access control lists for read/write permissions
- **Object Count**: Number of objects stored in the container
- **Total Bytes**: Combined size of all objects

**Container Operations in Substation:**

- Create/delete containers
- List objects with prefix filtering
- Set container metadata
- Configure web access (static website hosting)
- Download entire container contents

### Objects

Objects are the actual files stored in containers. Each object has a name (key) and data (value).

**Key Properties:**

- **Name**: Unique identifier within a container (can include path separators)
- **Content-Type**: MIME type of the stored data
- **Content-Length**: Size in bytes
- **ETAG**: MD5 hash of the object content
- **Last-Modified**: Timestamp of last modification
- **Metadata**: Custom key-value pairs attached to the object

**Object Naming:**

- Can include forward slashes to simulate directory structure
- Maximum length: 1024 bytes (UTF-8 encoded)
- Special characters are percent-encoded for safety
- Path traversal sequences (../) are rejected for security

### Metadata

Both containers and objects support custom metadata for storing additional information.

**Metadata Format:**

- Key: `X-Container-Meta-{name}` or `X-Object-Meta-{name}`
- Value: String (max 256 bytes per value)
- Use cases: Tags, categories, application-specific data

**Example Metadata:**

```
X-Container-Meta-Project: web-assets
X-Container-Meta-Environment: production
X-Object-Meta-Uploaded-By: john.doe
X-Object-Meta-Source: automated-backup
```

## ETAG and Content Verification

### What is ETAG?

ETAG (Entity Tag) is an MD5 hash of the object's content used for:

- **Content verification**: Ensure uploaded data matches original
- **Change detection**: Determine if object has been modified
- **Optimization**: Skip redundant uploads/downloads

### ETAG-Based Skip Optimization

One of Substation's most powerful features is ETAG-based skip optimization, which dramatically reduces bandwidth usage.

**How It Works:**

1. **Upload Scenario:**
   - Calculate MD5 hash of local file
   - Check if object exists in Swift with HEAD request
   - Compare local MD5 with remote ETAG
   - Skip upload if hashes match (file unchanged)
   - Upload only if hashes differ or object doesn't exist

2. **Download Scenario:**
   - Check if local file exists
   - Calculate MD5 hash of local file
   - Retrieve object ETAG from Swift
   - Skip download if hashes match (file already current)
   - Download only if hashes differ or file doesn't exist

**Benefits:**

- 50-90% bandwidth reduction for repeated operations
- Faster batch operations (only transfer changed files)
- Reduced server load
- Lower egress costs

**Implementation Details:**

```swift
// Check if upload needed
let localHash = try FileHashUtility.computeMD5(for: fileURL)
let remoteEtag = try await swift.getObjectMetadata(container: container, object: objectName)

if localHash == remoteEtag {
    // Skip upload - file unchanged
    tracker.fileCompleted(fileName, bytes: fileSize, skipped: true)
} else {
    // Proceed with upload
    try await swift.uploadObject(...)
    tracker.fileCompleted(fileName, bytes: fileSize, skipped: false)
}
```

### Streaming MD5 Computation

For memory efficiency, Substation computes MD5 hashes incrementally:

```swift
func computeMD5(for url: URL) throws -> String {
    let bufferSize = 1024 * 1024  // 1MB chunks
    var context = CC_MD5_CTX()
    CC_MD5_Init(&context)

    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }

    while autoreleasepool(invoking: {
        let data = file.readData(ofLength: bufferSize)
        if data.isEmpty { return false }
        data.withUnsafeBytes { bytes in
            CC_MD5_Update(&context, bytes.baseAddress, CC_LONG(data.count))
        }
        return true
    }) {}

    var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    CC_MD5_Final(&digest, &context)

    return digest.map { String(format: "%02hhx", $0) }.joined()
}
```

**Benefits:**

- Constant memory usage regardless of file size
- Can process multi-GB files without issues
- Progress can be reported during computation

## Error Handling and Retry Strategies

### Error Categories

Substation categorizes transfer errors for intelligent handling:

**Network Errors (Retryable):**

- Connection timeouts
- DNS resolution failures
- Temporary network unavailability
- Recommendation: "Check network connection and retry"

**Server Errors (Retryable):**

- HTTP 500-599 status codes
- Service temporarily unavailable
- Internal server errors
- Recommendation: "Server is experiencing issues, retry after a brief wait"

**Authentication Errors (Not Retryable):**

- Invalid credentials
- Expired tokens
- Permission denied
- Recommendation: "Check credentials and permissions"

**File System Errors (Not Retryable):**

- File not found
- Permission denied on local filesystem
- Disk full
- Recommendation: "Verify file path and permissions"

**Not Found Errors (Not Retryable):**

- Object doesn't exist
- Container doesn't exist
- Recommendation: "Object does not exist, verify object name"

### Error Aggregation

During batch operations, errors are tracked and summarized:

```swift
// Error tracking in SwiftTransferProgressTracker
private var errorsByCategory: [String: Int] = [:]
private var detailedErrors: [(file: String, category: String, message: String)] = []

// After operation completion
let summary = await tracker.getErrorSummary()
// Returns: ["Network Error": 3, "Not Found": 2]

let report = await tracker.getDetailedErrorReport()
// Returns formatted report with all error details
```

**Status Messages with Errors:**

```
Downloaded 95 objects (3 network errors, 2 not found)
Uploaded 150 objects (1 server error)
```

### Retry Logic

While automatic retry is not currently implemented, the `TransferError.isRetryable` property enables future retry mechanisms:

```swift
do {
    try await performTransfer()
} catch let error {
    let transferError = TransferError.from(error: error, context: "upload")

    if transferError.isRetryable {
        // Could implement exponential backoff retry
        // try await retryWithBackoff(operation)
    } else {
        // Fail immediately - no point retrying
        throw transferError
    }
}
```

## Background Operations

### Overview

Large transfer operations (container downloads, bulk uploads) run in the background to keep the UI responsive.

**Background Operation Properties:**

- **ID**: UUID for tracking
- **Type**: Upload, download, container download, directory download
- **Status**: Running, completed, failed, cancelled
- **Progress**: Completed count, total count, bytes transferred
- **Errors**: Aggregated error information
- **Start Time**: When operation began

### Operation Types

**Container Download:**

- Downloads all objects from a container
- Option to preserve directory structure or flatten
- ETAG-based skip optimization
- Concurrent downloads (max 10 simultaneous)
- Progress tracking per object

**Directory Download:**

- Downloads objects matching a prefix (simulated directory)
- Same features as container download
- Prefix-based filtering

**Object Upload:**

- Uploads single or multiple files
- Content-Type auto-detection
- ETAG-based skip optimization
- Progress tracking

**Bulk Upload:**

- Uploads entire local directories
- Recursive directory scanning
- Path preservation in object names
- Concurrent uploads

### Progress Tracking

The `SwiftTransferProgressTracker` actor provides thread-safe progress tracking:

```swift
actor SwiftTransferProgressTracker {
    // Track completed, failed, skipped counts
    // Track total bytes transferred
    // Track active file names
    // Aggregate errors by category

    func fileStarted(_ fileName: String)
    func fileCompleted(_ fileName: String, bytes: Int64, skipped: Bool)
    func fileFailed(_ fileName: String, error: TransferError?)
    func getProgress() -> TransferProgress
    func getErrorSummary() -> [String: Int]
    func getDetailedErrorReport() -> String
}
```

**TransferProgress Structure:**

```swift
struct TransferProgress: Sendable {
    let completed: Int      // Successfully transferred
    let failed: Int         // Failed transfers
    let skipped: Int        // Skipped (ETAG match)
    let bytes: Int64        // Total bytes transferred
    let failedFiles: [String]
    let active: Set<String> // Currently processing
    let errorSummary: [String: Int]
}
```

### Concurrency Control

To prevent overwhelming the server or network:

```swift
await withThrowingTaskGroup(of: Void.self) { group in
    for object in objects {
        // Limit concurrent operations
        if group.addTaskUnlessCancelled({
            try await downloadObject(object)
        }) {
            activeCount += 1
            if activeCount >= maxConcurrent {
                try await group.next()
                activeCount -= 1
            }
        }
    }
}
```

**Concurrency Limits:**

- Maximum 10 concurrent transfers
- Prevents network saturation
- Reduces server load
- Maintains responsiveness

## Path Utilities and Safety

### URL Encoding

Object names may contain special characters that need encoding:

```swift
// Encode object name preserving path structure
let encoded = SwiftStorageHelpers.encodeObjectName("dir/file with spaces.txt")
// Result: "dir/file%20with%20spaces.txt"

// Characters encoded: spaces, #, ?, &, =
// Characters preserved: forward slashes (/)
```

### Path Validation

Before operations, object names are validated for security and correctness:

```swift
let (valid, reason) = SwiftStorageHelpers.validateObjectName(objectName)

if !valid {
    throw TransferError.validation(reason: reason!)
}
```

**Validation Checks:**

1. Not empty
2. No path traversal sequences (../)
3. Does not start with /
4. No null bytes
5. No control characters
6. Length <= 1024 bytes

**Security Benefits:**

- Prevents path traversal attacks
- Ensures filesystem compatibility
- Validates input before API calls
- Protects against malicious object names

### Directory Structure Handling

Object names can simulate directories using forward slashes:

```swift
// Preserve directory structure
let destPath = SwiftStorageHelpers.buildDestinationPath(
    objectName: "logs/2024/01/app.log",
    destinationBase: "/downloads",
    preserveStructure: true
)
// Result: "/downloads/logs/2024/01/app.log"

// Flatten directory structure
let destPath = SwiftStorageHelpers.buildDestinationPath(
    objectName: "logs/2024/01/app.log",
    destinationBase: "/downloads",
    preserveStructure: false
)
// Result: "/downloads/app.log"
```

## Content Type Detection

Substation automatically detects content types based on file extensions:

```swift
let contentType = SwiftStorageHelpers.detectContentType(for: fileURL)
```

**Supported Categories:**

- **Text**: .txt, .html, .css, .json, .md, .yaml, .toml
- **Programming Languages**: .swift, .rs, .go, .py, .rb, .java, .c, .cpp
- **Images**: .jpg, .png, .gif, .svg, .webp, .heic, .heif
- **Video**: .mp4, .mov, .avi, .mkv, .webm
- **Audio**: .mp3, .wav, .flac, .aac, .ogg
- **Archives**: .zip, .tar, .gz, .7z, .rar
- **Documents**: .pdf, .doc, .docx, .xls, .xlsx, .ppt, .pptx

**Fallback:**

- Unknown extensions: `application/octet-stream`

**Content Type Validation:**

```swift
let isValid = SwiftStorageHelpers.validateContentType("text/plain")
// Validates format: type/subtype
// Checks valid type category
// Validates character set
```

## File Size and Transfer Rate Formatting

### File Size Formatting

Human-readable file size display with configurable precision:

```swift
let size = SwiftStorageHelpers.formatFileSize(1_536_000, precision: 2)
// Returns: "1.46 MB"

let size = SwiftStorageHelpers.formatFileSize(1_536_000, precision: 1)
// Returns: "1.5 MB"
```

**Supported Units:**

- Bytes: < 1 KB
- KB: 1024 bytes
- MB: 1024 KB
- GB: 1024 MB
- TB: 1024 GB

### Transfer Rate Formatting

Display transfer speeds during operations:

```swift
let rate = SwiftStorageHelpers.formatTransferRate(2_097_152.0, precision: 2)
// Returns: "2.00 MB/s"
```

**Use Cases:**

- Real-time progress updates
- Performance monitoring
- Bandwidth optimization feedback

## Best Practices

### Efficient Uploads

1. **Enable ETAG optimization**: Saves bandwidth on unchanged files
2. **Use batch operations**: Leverage concurrent uploads
3. **Set appropriate Content-Type**: Enables proper browser handling
4. **Add metadata**: Document source, purpose, ownership

### Efficient Downloads

1. **Enable ETAG optimization**: Skip downloading files you already have
2. **Preserve directory structure**: When you need it for organization
3. **Flatten structure**: When all files go to the same directory
4. **Use concurrent downloads**: For bulk operations

### Error Handling

1. **Check error categories**: Distinguish retryable from permanent errors
2. **Review error summaries**: Identify patterns in failures
3. **Use detailed error reports**: For debugging and troubleshooting
4. **Validate inputs**: Before starting operations

### Performance Optimization

1. **Leverage ETAG checks**: 50-90% bandwidth savings
2. **Use background operations**: Keep UI responsive during bulk transfers
3. **Monitor concurrent operations**: Don't exceed recommended limits
4. **Batch related operations**: Reduce API call overhead

## See Also

- [Object Storage Performance](../performance/object-storage.md) - Performance metrics and optimization
- [Object Storage Architecture](../architecture/object-storage.md) - System design and implementation
- [OpenStack Swift Reference](../reference/openstack/os-swift.md) - Swift service documentation
