# Swift Object Storage Development Guide

## Architecture Overview

The Swift implementation follows the established patterns in OTUI with three main layers:

### 1. Service Layer (`Sources/OSClient/Services/SwiftService.swift`)

The `SwiftService` actor provides async/await methods for all Swift API operations.

```swift
public actor SwiftService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "object-store"

    // Container operations
    public func listContainers(...) async throws -> [SwiftContainer]
    public func createContainer(...) async throws
    public func getContainerMetadata(...) async throws -> SwiftContainerMetadataResponse

    // Object operations
    public func listObjects(...) async throws -> [SwiftObject]
    public func uploadObject(...) async throws
    public func downloadObject(...) async throws -> Data
    public func getObjectMetadata(...) async throws -> SwiftObjectMetadataResponse

    // Bulk operations
    public func bulkDelete(...) async throws -> BulkDeleteResponse
    public func bulkUpload(...) async throws -> BulkUploadResult
}
```

### 2. Model Layer (`Sources/OSClient/Models/SwiftModels.swift`)

All models conform to:

- `Codable` - JSON serialization
- `Sendable` - Thread safety
- `ResourceIdentifiable` - Search integration

Key models:

- `SwiftContainer` - Container representation
- `SwiftObject` - Object representation
- `CreateSwiftContainerRequest` - Container creation
- `UploadSwiftObjectRequest` - Object upload
- `SwiftContainerMetadataResponse` - Container metadata
- `SwiftObjectMetadataResponse` - Object metadata

### 3. View Layer (`Sources/Substation/Views/SwiftViews.swift`)

SwiftTUI-based views following the component pattern:

```swift
@MainActor
struct SwiftViews {
    static func drawSwiftContainerList(...) async
    static func drawSwiftObjectList(...) async
    static func drawSwiftContainerDetail(...) async
    static func drawSwiftObjectDetail(...) async
    static func drawSwiftContainerCreate(...) async
    static func drawSwiftUpload(...) async
}
```

## Key Patterns

### 1. HTTP Header-Based Metadata

Swift stores metadata in HTTP headers. Use `requestWithHeaders`:

```swift
let (_, headers) = try await core.requestWithHeaders(
    service: serviceName,
    method: "HEAD",
    path: "/container/object",
    expected: 200
)

// Extract metadata
var metadata: [String: String] = [:]
for (key, value) in headers {
    if key.lowercased().hasPrefix("x-object-meta-") {
        let metaKey = String(key.dropFirst("X-Object-Meta-".count))
        metadata[metaKey] = value
    }
}
```

### 2. Large Object Segmentation

Files > 5GB use Dynamic Large Objects:

```swift
private func uploadLargeObject(
    containerName: String,
    objectName: String,
    data: Data,
    contentType: String?,
    metadata: [String: String]
) async throws {
    // 1. Create segments container
    let segmentsContainer = "\(containerName)_segments"
    try await createContainer(request: CreateSwiftContainerRequest(name: segmentsContainer))

    // 2. Upload segments in parallel
    try await withThrowingTaskGroup(of: Void.self) { group in
        for segmentIndex in 0..<segmentCount {
            group.addTask {
                let segmentData = data.subdata(in: range)
                try await self.uploadObject(request: segmentRequest)
            }
        }
        try await group.waitForAll()
    }

    // 3. Create manifest
    try await core.requestVoid(
        service: serviceName,
        method: "PUT",
        path: manifestPath,
        headers: ["X-Object-Manifest": manifestPath],
        expected: 201
    )
}
```

### 3. Batch Operations

Integrate with `BatchOperationManager`:

```swift
// Define operation type in BatchOperationTypes.swift
case swiftObjectBulkUpload(operations: [SwiftObjectUploadOperation])

// Implement handler in BatchOperationManager.swift
private func executeSwiftObjectUpload(
    _ operation: ResourceDependencyResolver.PlannedOperation,
    execution: BatchOperationExecution
) async throws -> String {
    guard case .swiftObjectBulkUpload(let operations) = execution.type,
          let uploadOp = operations.first(where: { $0.objectName == operation.resourceIdentifier }) else {
        throw BatchOperationError.executionFailed("Swift upload operation not found")
    }

    let fileURL = URL(fileURLWithPath: uploadOp.localPath)
    let data = try Data(contentsOf: fileURL)

    let request = UploadSwiftObjectRequest(
        containerName: uploadOp.containerName,
        objectName: uploadOp.objectName,
        data: data,
        contentType: uploadOp.contentType,
        metadata: uploadOp.metadata
    )

    try await client.swift.uploadObject(request: request)
    return uploadOp.objectName
}
```

## Adding New Operations

### 1. Add Service Method

```swift
// In SwiftService.swift
public func copyObject(
    sourceContainer: String,
    sourceObject: String,
    destContainer: String,
    destObject: String
) async throws -> SwiftObject {
    let encodedSource = "\(sourceContainer)/\(sourceObject)".addingPercentEncoding(
        withAllowedCharacters: .urlPathAllowed
    ) ?? "\(sourceContainer)/\(sourceObject)"

    let headers = [
        "X-Copy-From": encodedSource
    ]

    let encodedDest = destContainer.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? destContainer
    let encodedDestObj = destObject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? destObject

    try await core.requestVoid(
        service: serviceName,
        method: "PUT",
        path: "/\(encodedDest)/\(encodedDestObj)",
        headers: headers,
        expected: 201
    )

    // Return new object details
    return try await getObject(containerName: destContainer, objectName: destObject)
}
```

### 2. Add View Method

```swift
// In SwiftViews.swift
static func drawSwiftObjectCopy(
    screen: OpaquePointer?,
    startRow: Int32,
    startCol: Int32,
    width: Int32,
    height: Int32,
    sourceObject: SwiftObject,
    sourceContainer: String,
    formBuilderState: FormBuilderState
) async {
    let surface = SwiftTUI.surface(from: screen)

    // Create form
    let fields = [
        FormField(name: "destination_container", type: .text, label: "Destination Container", required: true),
        FormField(name: "destination_object", type: .text, label: "Destination Object Name", required: true)
    ]

    await FormSelectorRenderer.drawForm(
        on: surface,
        startRow: startRow,
        startCol: startCol,
        width: width,
        height: height,
        title: "Copy Object: \(sourceObject.name)",
        fields: fields,
        state: formBuilderState
    )
}
```

### 3. Wire Up Navigation

```swift
// In MainPanelView.swift ViewMode extension
static func getTitle(for view: ViewMode) -> String {
    switch view {
    // ... existing cases ...
    case .swiftObjectCopy: return "Copy Object"
    }
}

// In draw method
case .swiftObjectCopy:
    if let object = tui.selectedResource as? SwiftObject {
        await SwiftViews.drawSwiftObjectCopy(
            screen: screen,
            startRow: mainStartRow,
            startCol: mainStartCol,
            width: mainWidth,
            height: mainHeight,
            sourceObject: object,
            sourceContainer: tui.previousResource as? String ?? "",
            formBuilderState: FormBuilderState(fields: [])
        )
    }
```

## Testing Guidelines

### Unit Tests

Test service methods with mock responses:

```swift
func testCopyObject() async throws {
    let mockCore = MockOpenStackClientCore()
    mockCore.mockResponse = (data: Data(), headers: [:])

    let service = SwiftService(core: mockCore)

    let result = try await service.copyObject(
        sourceContainer: "source",
        sourceObject: "file.txt",
        destContainer: "dest",
        destObject: "copy.txt"
    )

    XCTAssertEqual(result.name, "copy.txt")
}
```

### Integration Tests

Test with real OpenStack environment:

```swift
func testEndToEndUpload() async throws {
    let client = try await OSClient(
        config: OpenStackConfig(authURL: testAuthURL),
        credentials: .password(username: "test", password: "test", projectName: "test")
    )

    // Create container
    try await client.swift.createContainer(
        request: CreateSwiftContainerRequest(name: "test-container")
    )

    // Upload object
    let testData = "Hello, Swift!".data(using: .utf8)!
    try await client.swift.uploadObject(
        request: UploadSwiftObjectRequest(
            containerName: "test-container",
            objectName: "test.txt",
            data: testData,
            contentType: "text/plain"
        )
    )

    // Verify
    let objects = try await client.swift.listObjects(containerName: "test-container")
    XCTAssertEqual(objects.count, 1)
    XCTAssertEqual(objects[0].name, "test.txt")

    // Cleanup
    try await client.swift.deleteObject(containerName: "test-container", objectName: "test.txt")
    try await client.swift.deleteContainer(containerName: "test-container")
}
```

## Common Pitfalls

### 1. Metadata Headers

❌ Wrong:

```swift
headers["metadata-key"] = "value"
```

✅ Correct:

```swift
headers["X-Container-Meta-key"] = "value"  // For containers
headers["X-Object-Meta-key"] = "value"     // For objects
```

### 2. URL Encoding

❌ Wrong:

```swift
let path = "/\(container)/\(object)"
```

✅ Correct:

```swift
let encodedContainer = container.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? container
let encodedObject = object.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? object
let path = "/\(encodedContainer)/\(encodedObject)"
```

### 3. Empty Container Deletion

❌ Wrong:

```swift
try await deleteContainer(containerName: "test")
```

✅ Correct:

```swift
// Delete all objects first
let objects = try await listObjects(containerName: "test")
for object in objects {
    try await deleteObject(containerName: "test", objectName: object.name)
}
// Then delete container
try await deleteContainer(containerName: "test")
```

### 4. Large File Handling

❌ Wrong:

```swift
let data = try Data(contentsOf: largeFileURL)  // Loads entire file into memory
try await uploadObject(request: UploadSwiftObjectRequest(..., data: data))
```

✅ Correct:

```swift
let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64
if fileSize > largeObjectThreshold {
    try await uploadLargeObject(...)  // Automatic segmentation
} else {
    let data = try Data(contentsOf: fileURL)
    try await uploadObject(request: UploadSwiftObjectRequest(..., data: data))
}
```

## Performance Optimization

### 1. Concurrent Operations

```swift
// Bad: Sequential
for object in objects {
    try await downloadObject(containerName: container, objectName: object.name)
}

// Good: Concurrent with limit
try await withThrowingTaskGroup(of: Void.self) { group in
    var activeCount = 0
    var remaining = objects

    while !remaining.isEmpty || activeCount > 0 {
        while activeCount < maxConcurrency && !remaining.isEmpty {
            let object = remaining.removeFirst()
            activeCount += 1

            group.addTask {
                try await self.downloadObject(containerName: container, objectName: object.name)
            }
        }

        try await group.next()
        activeCount -= 1
    }
}
```

### 2. Caching

```swift
// Cache container list
private var containerCache: [SwiftContainer] = []
private var containerCacheTime: Date?
private let cacheTimeout: TimeInterval = 60.0

public func listContainers(limit: Int? = nil, marker: String? = nil) async throws -> [SwiftContainer] {
    if let cacheTime = containerCacheTime,
       Date().timeIntervalSince(cacheTime) < cacheTimeout,
       limit == nil, marker == nil {
        return containerCache
    }

    let containers = try await fetchContainers(limit: limit, marker: marker)

    if limit == nil && marker == nil {
        containerCache = containers
        containerCacheTime = Date()
    }

    return containers
}
```

### 3. Streaming Large Downloads

```swift
// For very large files, stream directly to disk
public func downloadObjectStreaming(
    containerName: String,
    objectName: String,
    destinationURL: URL
) async throws {
    // Use URLSession download task for streaming
    let request = try await buildRequest(containerName: containerName, objectName: objectName)

    let (tempURL, response) = try await URLSession.shared.download(for: request)
    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
}
```

## Swift API Reference

### Container Operations

- `GET /<api_version>/<account>` - List containers
- `HEAD /<api_version>/<account>/<container>` - Get container metadata
- `PUT /<api_version>/<account>/<container>` - Create container
- `POST /<api_version>/<account>/<container>` - Update container metadata
- `DELETE /<api_version>/<account>/<container>` - Delete container

### Object Operations

- `GET /<api_version>/<account>/<container>` - List objects
- `HEAD /<api_version>/<account>/<container>/<object>` - Get object metadata
- `GET /<api_version>/<account>/<container>/<object>` - Download object
- `PUT /<api_version>/<account>/<container>/<object>` - Upload object
- `POST /<api_version>/<account>/<container>/<object>` - Update object metadata
- `DELETE /<api_version>/<account>/<container>/<object>` - Delete object
- `COPY /<api_version>/<account>/<container>/<object>` - Copy object

### Bulk Operations

- `POST /<api_version>/<account>?bulk-delete` - Bulk delete objects
- `PUT /<api_version>/<account>/<container>/<object>` with `X-Object-Manifest` - Create large object

## Resources

- [OpenStack Swift API Documentation](https://docs.openstack.org/api-ref/object-store/)
