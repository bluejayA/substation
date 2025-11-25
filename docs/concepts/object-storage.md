# Object Storage Concepts

## Overview

Managing Swift object storage through web interfaces is an exercise in patience. Click to upload a file. Wait. Watch a progress bar that may or may not be accurate. Click another file. Repeat two hundred times. Hope nothing times out. We built Substation's object storage interface because we've lived through this pain and decided there had to be a better way.

OpenStack Swift provides scalable, redundant storage for unstructured data, but working with it efficiently requires tools that understand batch operations, intelligent caching, and the reality that network connections fail at the worst possible moments. Substation implements comprehensive Swift integration with ETAG-based optimization that can skip 50-90% of unnecessary transfers, background operations that keep your terminal responsive during massive uploads, and error handling that actually tells you what went wrong instead of "transfer failed."

## Core Concepts

### Containers

Containers are the top-level organizational unit in Swift, similar to buckets in other object storage systems. Think of them as the directories of the object storage world, except they can't be nested and you can make them serve websites if you're feeling adventurous.

Each container has a unique name within your project and carries metadata about what's inside. The name is its identifier, metadata provides custom key-value pairs for container configuration, and access control lists govern who can read or write. Containers track how many objects they hold and the total bytes consumed, which becomes surprisingly important when you're trying to figure out why your storage quota vanished.

In Substation, we give you full control over container operations. Create and delete containers with confirmation dialogs that prevent accidents. List objects with prefix filtering so you can find things in containers with thousands of files. Set container metadata to tag your storage with whatever organizational scheme makes sense this week. Configure web access for static website hosting when you need to turn a container into a CDN. Download entire container contents in the background while you work on something else.

### Objects

Objects are the actual files stored in containers. Each object has a name, which we call the key, and data, which is the value. Unlike traditional filesystems, there's no real directory structure here. Everything is flat. The appearance of directories is just object names with forward slashes in them, and Swift pretends along with you.

Object properties include the name, which must be unique within its container and can include path separators to simulate folder structure. The Content-Type tells Swift and browsers what kind of file this is. Content-Length tracks the size in bytes. The ETAG field holds an MD5 hash of the object content, which becomes critical for our optimization strategies. Last-Modified timestamps tell you when something changed, and custom metadata lets you attach arbitrary key-value pairs to objects.

When naming objects, you can include forward slashes to create the illusion of directory structure. Your object name can be up to 1024 bytes in UTF-8 encoding, though we enforce ASCII-only in this project. Special characters get percent-encoded for safety because URLs are involved. We explicitly reject path traversal sequences like "../" because we're not interested in security vulnerabilities, thanks.

### Metadata

Both containers and objects support custom metadata for storing additional information that doesn't fit anywhere else. Maybe you want to tag who uploaded something, or mark which environment a container belongs to, or note which automated process created a backup.

Metadata follows a specific format. Container metadata uses keys like "X-Container-Meta-Project" and object metadata uses "X-Object-Meta-Uploaded-By". Each value is a string limited to 256 bytes. Common use cases include tags, categories, and application-specific data that you need to track but don't want to encode in the object name.

Example metadata might look like this:

```
X-Container-Meta-Project: web-assets
X-Container-Meta-Environment: production
X-Object-Meta-Uploaded-By: john.doe
X-Object-Meta-Source: automated-backup
```

## ETAG and Content Verification

### What is ETAG?

ETAG stands for Entity Tag, and in Swift's case, it's an MD5 hash of the object's content. This seemingly simple field enables some of our most powerful optimizations. We use ETAGs for content verification to ensure uploaded data matches the original. We use them for change detection to determine if an object has been modified since we last saw it. Most importantly, we use them to skip redundant uploads and downloads, saving massive amounts of bandwidth.

### ETAG-Based Skip Optimization

Here's where Substation gets interesting. One of our most powerful features is ETAG-based skip optimization, which can reduce bandwidth usage by 50-90% in common scenarios. If you've ever watched a backup system re-upload gigabytes of unchanged files, you'll appreciate this.

For uploads, we calculate the MD5 hash of your local file first. Then we make a HEAD request to Swift to check if an object with that name exists. If it does, we compare the local MD5 with the remote ETAG. If the hashes match, the file hasn't changed, and we skip the upload entirely. If the hashes differ or the object doesn't exist, we proceed with the upload. Your status bar shows the file as "skipped" and you just saved the time and bandwidth of uploading a file that's already there.

For downloads, the process reverses. We check if a local file exists at the destination path. If it does, we calculate its MD5 hash. We retrieve the object's ETAG from Swift. If the hashes match, your local copy is current, and we skip the download. If they differ or the file doesn't exist locally, we proceed with the download.

The benefits are substantial. In typical scenarios where you're syncing directories or re-running backups, we've seen bandwidth reduction of 50-90%. Batch operations complete faster because we only transfer changed files. Server load decreases. Your egress costs drop. Everyone wins except your cloud provider's bandwidth billing department.

The implementation looks like this:

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

Computing MD5 hashes could be a memory disaster if we loaded entire files into RAM. A 10GB backup file would consume 10GB of memory just to hash it, which is obviously unacceptable. We use streaming MD5 computation instead, processing files in 1MB chunks.

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

This approach maintains constant memory usage regardless of file size. We can process multi-gigabyte files without issues, and we can report progress during computation, so you're not staring at a frozen interface wondering if the application crashed.

## Why Terminal-Based Object Storage Works Better

Web interfaces for object storage suffer from fundamental limitations. Browser upload APIs aren't designed for batch operations. Resuming failed transfers requires JavaScript gymnastics. Checking whether files need uploading at all requires making API calls that web interfaces rarely bother with. Progress tracking is approximate at best.

Terminal-based object storage in Substation solves these problems because we control the entire transfer pipeline. We can compute MD5 hashes before making any network requests. We can parallelize operations intelligently without browser concurrency limits. We can run transfers in the background while you work on other tasks. Error handling can be sophisticated because we're not limited by what a web form can display.

Most importantly, terminal-based object storage enables workflows that web interfaces make painful. Need to upload a directory tree with 500 files? One command. Want to download everything in a container? One command. Need to check if your local backups match what's in Swift without downloading anything? We hash both sides and compare. These operations that would take hours of clicking in a web interface become single commands that run in the background.

## Error Handling and Retry Strategies

### Error Categories

File transfers fail in various ways, and treating all errors the same leads to poor user experience. We categorize transfer errors so we can provide intelligent handling and useful recommendations.

Network errors are retryable and include connection timeouts, DNS resolution failures, and temporary network unavailability. When these occur, we recommend checking your network connection and retrying. The error might be transient.

Server errors are also retryable. HTTP status codes in the 500-599 range indicate that Swift is having a bad day. Service temporarily unavailable, internal server errors, and similar problems often resolve themselves. We recommend retrying after a brief wait.

Authentication errors are not retryable through simple retry logic. Invalid credentials, expired tokens, and permission denied errors require intervention. We recommend checking your credentials and permissions because retrying won't help.

File system errors are also not retryable automatically. File not found, permission denied on the local filesystem, and disk full errors require you to fix something before proceeding. We recommend verifying your file path and permissions.

Not found errors indicate that the object or container you're looking for doesn't exist. Retrying won't make it appear. We recommend verifying the object name and moving on.

### Error Aggregation

During batch operations involving hundreds or thousands of files, showing every individual error would flood your terminal with noise. We track errors and summarize them:

```swift
// Error tracking within Swift module handlers
private var errorsByCategory: [String: Int] = [:]
private var detailedErrors: [(file: String, category: String, message: String)] = []

// After operation completion
let summary = getErrorSummary()
// Returns: ["Network Error": 3, "Not Found": 2]

let report = getDetailedErrorReport()
// Returns formatted report with all error details
```

Status messages include error summaries so you can see at a glance what happened:

```
Downloaded 95 objects (3 network errors, 2 not found)
Uploaded 150 objects (1 server error)
```

If you need details, the detailed error report shows every file that failed and why. This balance between summary and detail means you get actionable information without drowning in logs.

### Retry Logic

Automatic retry is not currently implemented, but the foundation exists. The TransferError.isRetryable property enables future retry mechanisms:

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

When we implement automatic retry, it will use exponential backoff for retryable errors and fail fast for errors that won't resolve themselves.

## Background Operations

### Overview

Large transfer operations must run in the background to keep the UI responsive. Nobody wants to stare at a frozen terminal while 1000 files upload. Background operations in Substation handle container downloads, bulk uploads, and any transfer that might take more than a few seconds.

Each background operation has a UUID for tracking, a type indicating whether it's an upload or download operation, status showing whether it's running, completed, failed, or cancelled, progress information including completed count and bytes transferred, aggregated error information, and a start time so you can see how long it's been running.

### Operation Types

Container downloads pull all objects from a container with options to preserve directory structure or flatten everything into a single directory. ETAG-based skip optimization means we only download files that have changed or don't exist locally. Concurrent downloads, limited to 10 simultaneous transfers, speed up the process without overwhelming your network or Swift. Progress tracking shows you exactly which objects have completed.

Directory downloads work similarly but filter objects by prefix, simulating a directory download from what is fundamentally a flat namespace. Same features, different scope.

Object uploads handle single or multiple files with automatic Content-Type detection based on file extension. ETAG optimization prevents uploading files that already exist unchanged in Swift. Progress tracking keeps you informed.

Bulk uploads process entire local directories, recursively scanning for files and preserving the path structure in object names. Concurrent uploads and all the same optimizations apply at scale.

### Progress Tracking

Progress tracking provides thread-safe state management integrated within the Swift module form handlers. The conceptual architecture tracks completed, failed, and skipped counts. Total bytes transferred gives you a sense of scale. Active file names show what's currently processing. Errors are aggregated by category so you can see patterns.

```swift
// Conceptual design (integrated within Swift module handlers)
// Track completed, failed, skipped counts
// Track total bytes transferred
// Track active file names
// Aggregate errors by category

// Functions provided by form handlers:
// - fileStarted(_ fileName: String)
// - fileCompleted(_ fileName: String, bytes: Int64, skipped: Bool)
// - fileFailed(_ fileName: String, error: TransferError?)
// - getProgress() -> TransferProgress
// - getErrorSummary() -> [String: Int]
// - getDetailedErrorReport() -> String
```

The TransferProgress structure provides a snapshot of the operation state:

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

Running too many transfers simultaneously overwhelms networks and servers. We limit concurrent operations to prevent saturation:

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

We maintain a maximum of 10 concurrent transfers, which prevents network saturation, reduces server load, and maintains UI responsiveness even during massive operations.

## Path Utilities and Safety

### URL Encoding

Object names may contain spaces, special characters, and other elements that need encoding for URLs. Storage helper functionality integrated within the Swift module handles this:

```swift
// Encode object name preserving path structure (integrated in Swift module)
let encoded = encodeObjectName("dir/file with spaces.txt")
// Result: "dir/file%20with%20spaces.txt"

// Characters encoded: spaces, #, ?, &, =
// Characters preserved: forward slashes (/)
```

This ensures that object names translate correctly into Swift API requests while preserving the simulated directory structure.

### Path Validation

Before performing operations, we validate object names for security and correctness. The validation integrated in Swift module handlers checks multiple criteria:

```swift
// Validation integrated in Swift module handlers
let (valid, reason) = validateObjectName(objectName)

if !valid {
    throw TransferError.validation(reason: reason!)
}
```

Validation ensures that object names are not empty, contain no path traversal sequences like "../", don't start with forward slashes, contain no null bytes or control characters, and stay within the 1024-byte length limit.

These security checks prevent path traversal attacks where malicious object names try to write files outside intended directories. They ensure filesystem compatibility by rejecting characters that would cause problems. Input is validated before making API calls, catching problems early. The system is protected against malicious object names that might exploit edge cases.

### Directory Structure Handling

Object names simulate directories using forward slashes, and we provide options for how to handle this when downloading:

```swift
// Preserve directory structure
let destPath = buildDestinationPath(
    objectName: "logs/2024/01/app.log",
    destinationBase: "/downloads",
    preserveStructure: true
)
// Result: "/downloads/logs/2024/01/app.log"

// Flatten directory structure
let destPath = buildDestinationPath(
    objectName: "logs/2024/01/app.log",
    destinationBase: "/downloads",
    preserveStructure: false
)
// Result: "/downloads/app.log"
```

Preserving structure maintains organization. Flattening puts everything in one directory, which works when you just want all the files and don't care about the original layout.

## Content Type Detection

Substation automatically detects content types based on file extensions, setting appropriate MIME types for uploaded objects:

```swift
let contentType = detectContentType(for: fileURL)
```

We support broad categories covering most common file types. Text files include .txt, .html, .css, .json, .md, .yaml, and .toml. Programming language files cover .swift, .rs, .go, .py, .rb, .java, .c, and .cpp. Image formats include .jpg, .png, .gif, .svg, .webp, .heic, and .heif. Video formats handle .mp4, .mov, .avi, .mkv, and .webm. Audio files support .mp3, .wav, .flac, .aac, and .ogg. Archives include .zip, .tar, .gz, .7z, and .rar. Documents cover .pdf, .doc, .docx, .xls, .xlsx, .ppt, and .pptx.

For unknown extensions, we fall back to "application/octet-stream", which is the generic binary file type. Content type validation ensures that the detected types follow proper format with type and subtype, valid category, and acceptable character set.

## File Size and Transfer Rate Formatting

### File Size Formatting

Human-readable file size display makes progress information comprehensible. We format sizes with configurable precision:

```swift
let size = formatFileSize(1_536_000, precision: 2)
// Returns: "1.46 MB"

let size = formatFileSize(1_536_000, precision: 1)
// Returns: "1.5 MB"
```

Supported units range from bytes for values under 1 KB, through KB (1024 bytes), MB (1024 KB), GB (1024 MB), up to TB (1024 GB). We use binary units because storage systems work in powers of two, not powers of ten.

### Transfer Rate Formatting

Display transfer speeds during operations to provide feedback on network performance:

```swift
let rate = formatTransferRate(2_097_152.0, precision: 2)
// Returns: "2.00 MB/s"
```

This enables real-time progress updates, performance monitoring to identify bottlenecks, and feedback on whether bandwidth optimization is working as expected.

## Best Practices

### Efficient Uploads

Enable ETAG optimization to save bandwidth on unchanged files. The performance impact is dramatic for recurring uploads. Use batch operations to leverage concurrent uploads, which dramatically outperforms individual file transfers. Set appropriate Content-Type headers so browsers and CDNs handle your files correctly. Add metadata to document source, purpose, and ownership, making future maintenance easier.

### Efficient Downloads

Enable ETAG optimization to skip downloading files you already have, saving time and bandwidth. Preserve directory structure when you need it for organization, matching the source layout. Flatten structure when all files go to the same directory and you don't care about paths. Use concurrent downloads for bulk operations to maximize throughput.

### Error Handling

Check error categories to distinguish retryable errors from permanent failures that need intervention. Review error summaries to identify patterns in failures, which might indicate systemic problems. Use detailed error reports for debugging and troubleshooting specific files. Validate inputs before starting operations to catch problems early.

### Performance Optimization

Leverage ETAG checks for 50-90% bandwidth savings on typical workloads. Use background operations to keep the UI responsive during bulk transfers. Monitor concurrent operations and don't exceed recommended limits, which could overwhelm your network. Batch related operations to reduce API call overhead.

## Advanced Object Operations

### Bulk Delete Operations

Deleting objects one at a time is tedious and slow. Swift supports bulk delete operations that remove multiple objects in a single API request, dramatically improving efficiency for cleanup tasks.

```swift
public func bulkDelete(request: BulkDeleteRequest) async throws -> BulkDeleteResponse
```

The bulk delete feature allows deleting up to hundreds of objects in one operation. A single API call replaces what would otherwise be hundreds of individual DELETE requests, reducing network overhead and latency. The response provides detailed status including the number of objects successfully deleted and any errors encountered. The system supports both container-scoped deletion and full-path deletion modes.

The response includes numberDeleted showing how many objects were successfully removed, numberNotFound indicating how many objects didn't exist (not necessarily an error), an errors array detailing any failed deletions, responseStatus with the HTTP status of the bulk operation, and responseBody containing additional response details.

Performance benefits are significant. Bulk delete is dramatically faster than individual DELETE operations for large-scale cleanup. Reduced API call overhead means one call instead of N calls for N objects. Lower latency benefits container emptying operations, which must remove all objects before deleting the container itself.

In Substation, bulk delete integrates into the object list view. Select multiple objects, press the Del key to initiate bulk delete, confirm in a dialog showing the object count, and watch progress in the status bar. Much better than clicking delete buttons individually.

### Object Copy Operations

Copying objects server-side, without downloading and re-uploading, saves enormous amounts of time and bandwidth. Swift's copy operation handles this elegantly:

```swift
public func copyObject(request: CopySwiftObjectRequest) async throws
```

Server-side copy means no data transfers to your client. Copy within the same container or across containers with equal ease. Optionally preserve metadata or replace it during the copy. Rename objects during the copy operation, which combined with deleting the source effectively renames objects.

Request parameters include sourceContainer and sourceObject identifying what to copy, destinationContainer and destinationObject specifying where it goes (and the destination name can differ from source), optional metadata to apply, and freshMetadata flag controlling whether to preserve or replace metadata.

Metadata handling provides flexibility. By default, source object metadata is preserved. Setting freshMetadata to false and providing new metadata adds or updates specific keys. Setting freshMetadata to true replaces all metadata with the provided values, discarding the source metadata.

Performance benefits are compelling. No bandwidth usage since this is a server-side operation. Instant copy regardless of object size, even for multi-gigabyte files. No temporary storage needed on your local system. This approach is ideal for object versioning and backup workflows.

Common use cases include creating backups before modification, renaming objects by copying to a new name and deleting the source, duplicating objects across containers for different access policies, and creating working copies for testing without affecting production objects.

### Container Web Hosting

Containers can serve as static website hosts, providing public HTTP access to objects without requiring authentication. This turns Swift into a simple CDN or static site host.

Containers support access control through readACL and writeACL headers. For public read access, set "X-Container-Read: .r:*,.rlistings" where ".r:*" allows read access to all users and ".rlistings" enables directory-style listings. For specific referrer access, use "X-Container-Read: .r:.example.com" to restrict access to specific domains. For project-based access, "X-Container-Read: project-id:user-id" grants access to specific OpenStack users or projects.

Web hosting configuration follows a simple pattern. Set the container read ACL for public access. Upload index.html as the default landing page. Upload error.html for 404 handling if your Swift deployment supports it. Upload static assets like CSS, JavaScript, and images. Objects become accessible at URLs following the pattern: swift.example.com/v1/AUTH_project/container/object.

Common web hosting scenarios include static website hosting for documentation or marketing sites, CDN origin storage feeding content delivery networks, public file distribution for downloads, documentation hosting for API references and guides, and asset delivery for applications that need reliable static file serving.

Container metadata responses include readACL showing the current read access control list and writeACL showing the current write access control list, so you can verify configuration.

Security considerations matter when making containers public. Public containers expose all objects to the internet without authentication required for reads. Consider object naming carefully because the names are visible. Don't put sensitive data in object names. Use temporary URLs for time-limited access instead of full public exposure. Monitor bandwidth usage for public containers, which can be exploited for bandwidth consumption attacks.

## See Also

- [Object Storage Performance](../performance/object-storage.md) - Performance metrics and optimization
- [Object Storage Architecture](../architecture/object-storage.md) - System design and implementation
- [OpenStack Swift Reference](../reference/openstack/os-swift.md) - Swift service documentation
