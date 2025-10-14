import Foundation
import SwiftTUI
import OSClient

// MARK: - Swift Views

struct SwiftViews {

    // MARK: - Container List View

    @MainActor
    static func drawSwiftContainerList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        containers: [SwiftContainer],
        searchQuery: String,
        scrollOffset: Int,
        selectedIndex: Int,
        dataManager: DataManager? = nil,
        virtualScrollManager: VirtualScrollManager<SwiftContainer>? = nil,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        let statusListView = createContainerStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: containers,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            dataManager: dataManager,
            virtualScrollManager: virtualScrollManager,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Object List View

    @MainActor
    static func drawSwiftObjectList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        objects: [SwiftObject],
        containerName: String,
        currentPath: String,
        searchQuery: String,
        scrollOffset: Int,
        selectedIndex: Int,
        navState: SwiftNavigationState,
        dataManager: DataManager? = nil,
        virtualScrollManager: VirtualScrollManager<SwiftObject>? = nil,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        // Build tree structure from flat object list
        let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)

        // Apply search filter if present
        let filteredItems = SwiftTreeItem.filterItems(treeItems, query: searchQuery.isEmpty ? nil : searchQuery)

        Logger.shared.logDebug("Rendering Swift object list: \(filteredItems.count) items (from \(objects.count) objects)")

        let statusListView = createTreeItemStatusListView(navState: navState)
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: filteredItems,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            dataManager: dataManager,
            virtualScrollManager: nil, // Don't use virtual scroll manager for tree items
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Container Detail View

    @MainActor
    static func drawSwiftContainerDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        container: SwiftContainer,
        metadata: SwiftContainerMetadataResponse?,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Name", value: container.name),
            .field(label: "Object Count", value: "\(container.count)", style: .accent),
            .field(label: "Size", value: container.formattedSize, style: .secondary),
            DetailView.buildFieldItem(label: "Last Modified", value: container.lastModified?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Storage Analysis Section
        var analysisItems: [DetailItem] = []

        if container.count == 0 {
            analysisItems.append(.field(
                label: "Storage Status",
                value: "Empty container - No storage costs incurred",
                style: .info
            ))
            analysisItems.append(.field(
                label: "Recommendation",
                value: "Consider deleting if no longer needed",
                style: .muted
            ))
        } else {
            let avgSize = container.bytes / max(container.count, 1)
            let sizeStatus = avgSize > 10_000_000 ? "Large objects detected" : "Standard object sizes"
            let sizeStyle: TextStyle = avgSize > 10_000_000 ? .warning : .info

            analysisItems.append(.field(
                label: "Storage Efficiency",
                value: sizeStatus,
                style: sizeStyle
            ))

            if avgSize > 10_000_000 {
                analysisItems.append(.field(
                    label: "Recommendation",
                    value: "Large objects - Consider segmentation for better performance",
                    style: .muted
                ))
            }
        }

        // Access control analysis (basic check for Storage Analysis section)
        if let metadata = metadata {
            if metadata.readACL == nil && metadata.writeACL == nil {
                analysisItems.append(.field(
                    label: "Access Control",
                    value: "No ACLs configured - Private access only",
                    style: .info
                ))
            } else {
                analysisItems.append(.field(
                    label: "Access Control",
                    value: "Custom ACLs configured",
                    style: .accent
                ))
            }
        }

        sections.append(DetailSection(
            title: "Storage Analysis",
            items: analysisItems,
            titleStyle: .accent
        ))

        // Enhanced Access Control Section
        if let metadata = metadata {
            var aclItems: [DetailItem?] = []

            if let readACL = metadata.readACL {
                aclItems.append(.field(label: "Read ACL", value: readACL, style: .info))

                // Provide ACL interpretation
                if readACL.contains(".r:*") {
                    aclItems.append(.field(
                        label: "Read Access",
                        value: "Public - Anyone can read",
                        style: .warning
                    ))
                } else if readACL.contains(".rlistings") {
                    aclItems.append(.field(
                        label: "Read Access",
                        value: "Public listings enabled",
                        style: .warning
                    ))
                } else {
                    aclItems.append(.field(
                        label: "Read Access",
                        value: "Restricted to specified users/roles",
                        style: .info
                    ))
                }
            } else {
                aclItems.append(.field(
                    label: "Read ACL",
                    value: "Not set - Private access only",
                    style: .muted
                ))
            }

            if let writeACL = metadata.writeACL {
                aclItems.append(.field(label: "Write ACL", value: writeACL, style: .info))

                if writeACL.contains(".r:*") {
                    aclItems.append(.field(
                        label: "Write Access",
                        value: "Public - Anyone can write (DANGEROUS)",
                        style: .error
                    ))
                } else {
                    aclItems.append(.field(
                        label: "Write Access",
                        value: "Restricted to specified users/roles",
                        style: .info
                    ))
                }
            } else {
                aclItems.append(.field(
                    label: "Write ACL",
                    value: "Not set - Owner only",
                    style: .muted
                ))
            }

            if let aclSection = DetailView.buildSection(title: "Access Control", items: aclItems) {
                sections.append(aclSection)
            }

            // Metadata Section
            if !metadata.metadata.isEmpty {
                let metadataItems = metadata.metadata.sorted(by: { $0.key < $1.key }).map {
                    DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
                }
                sections.append(DetailSection(title: "Custom Metadata", items: metadataItems))
            }
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Container Details: \(container.name ?? "Unknown")",
            sections: sections,
            helpText: "Press ESC to return to container list",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }

    // MARK: - Object Detail View

    @MainActor
    static func drawSwiftObjectDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        object: SwiftObject,
        containerName: String,
        metadata: SwiftObjectMetadataResponse?,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Name", value: object.name),
            DetailView.buildFieldItem(label: "Container", value: containerName),
            .field(label: "Size", value: object.formattedSize, style: .accent),
            DetailView.buildFieldItem(label: "Content Type", value: object.contentType),
            DetailView.buildFieldItem(label: "Last Modified", value: object.lastModified?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // File Information Section
        var fileItems: [DetailItem?] = []

        if let ext = object.fileExtension {
            fileItems.append(.field(label: "File Extension", value: ext, style: .secondary))
        }

        if let hash = object.hash {
            fileItems.append(.field(label: "ETag (MD5)", value: hash, style: .muted))
        }

        if object.isLargeObject {
            fileItems.append(.field(label: "Object Type", value: "Large Object (Segmented)", style: .warning))
        } else {
            fileItems.append(.field(label: "Object Type", value: "Standard Object", style: .info))
        }

        if let fileSection = DetailView.buildSection(title: "File Information", items: fileItems) {
            sections.append(fileSection)
        }

        // File Analysis Section
        var analysisItems: [DetailItem] = []

        // Size analysis - provides estimates for download times and warnings for large files
        if object.bytes > 100_000_000 {
            analysisItems.append(.field(
                label: "Size Warning",
                value: "Large file - Download may take significant time",
                style: .warning
            ))

            let estimatedSeconds = object.bytes / 10_000_000 // Assume ~10MB/s
            analysisItems.append(.field(
                label: "Est. Download Time",
                value: "\(estimatedSeconds) seconds at 10MB/s",
                style: .muted
            ))
        } else if object.bytes > 10_000_000 {
            analysisItems.append(.field(
                label: "Size Status",
                value: "Medium file - Download should complete quickly",
                style: .info
            ))
        } else {
            analysisItems.append(.field(
                label: "Size Status",
                value: "Small file - Instant download",
                style: .info
            ))
        }

        // Content type analysis - provides insights about file type capabilities
        if let contentType = object.contentType {
            if contentType.hasPrefix("image/") {
                analysisItems.append(.field(
                    label: "File Type",
                    value: "Image file - Can be viewed/processed",
                    style: .info
                ))
            } else if contentType.hasPrefix("video/") {
                analysisItems.append(.field(
                    label: "File Type",
                    value: "Video file - Streaming capable",
                    style: .info
                ))
            } else if contentType.hasPrefix("text/") || contentType.contains("json") || contentType.contains("xml") {
                analysisItems.append(.field(
                    label: "File Type",
                    value: "Text-based file - Can be edited",
                    style: .info
                ))
            } else if contentType.contains("application/octet-stream") {
                analysisItems.append(.field(
                    label: "File Type",
                    value: "Binary file - Generic storage",
                    style: .muted
                ))
            }
        }

        // Metadata analysis - indicates organization status
        if let metadata = metadata {
            if !metadata.metadata.isEmpty {
                analysisItems.append(.field(
                    label: "Metadata Status",
                    value: "\(metadata.metadata.count) custom properties set",
                    style: .accent
                ))
            } else {
                analysisItems.append(.field(
                    label: "Metadata Status",
                    value: "No custom metadata - Consider adding for organization",
                    style: .muted
                ))
            }
        } else if object.metadata.isEmpty {
            analysisItems.append(.field(
                label: "Metadata Status",
                value: "No custom metadata - Consider adding for organization",
                style: .muted
            ))
        }

        sections.append(DetailSection(
            title: "File Analysis",
            items: analysisItems,
            titleStyle: .accent
        ))

        // Metadata Section
        if let metadata = metadata, !metadata.metadata.isEmpty {
            let metadataItems = metadata.metadata.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Custom Metadata", items: metadataItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Object Details: \(object.fileName)",
            sections: sections,
            helpText: "Press ESC to return to object list | D: Download | X: Delete",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }

    // MARK: - Container Create View

    @MainActor
    static func drawSwiftContainerCreate(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Create Swift Container",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit | ENTER: Create | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - Object Upload View

    @MainActor
    static func drawSwiftUpload(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState,
        uploadProgress: Double? = nil
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Upload Object to Swift",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        var components: [any Component] = [formBuilder.render()]

        // Show upload progress if uploading
        if let progress = uploadProgress {
            let progressPercent = Int(progress * 100)
            let progressText = Text("Uploading: \(progressPercent)%").accent()
            components.append(progressText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

            // Simple progress bar
            let barWidth = Int(width) - 4
            let filledWidth = Int(Double(barWidth) * progress)
            let progressBar = String(repeating: "=", count: filledWidth) + String(repeating: "-", count: barWidth - filledWidth)
            components.append(Text("[\(progressBar)]").info())
        }

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit | ENTER: Upload | ESC: Cancel").info()
        components.append(helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        let finalComponent = VStack(spacing: 0, children: components)

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - StatusListView Creators

    @MainActor
    private static func createContainerStatusListView() -> StatusListView<SwiftContainer> {
        let columns = [
            StatusListColumn<SwiftContainer>(
                header: "Container Name",
                width: 50,
                getValue: { $0.name ?? "Unknown" }
            ),
            StatusListColumn<SwiftContainer>(
                header: "Objects",
                width: 12,
                getValue: { "\($0.count)" },
                getStyle: { _ in .accent }
            ),
            StatusListColumn<SwiftContainer>(
                header: "Size",
                width: 15,
                getValue: { $0.formattedSize },
                getStyle: { _ in .secondary }
            ),
            StatusListColumn<SwiftContainer>(
                header: "Last Modified",
                width: 20,
                getValue: { container in
                    container.lastModified?.formatted(date: .abbreviated, time: .shortened) ?? "N/A"
                }
            )
        ]

        return StatusListView(
            title: "Swift Containers",
            columns: columns,
            getStatusIcon: { container in
                container.isEmpty ? "[E]" : "[+]"
            },
            filterItems: { containers, query in
                guard let query = query, !query.isEmpty else { return containers }
                return containers.filter { $0.name?.localizedCaseInsensitiveContains(query) ?? false }
            },
            getItemID: { $0.id }
        )
    }

    @MainActor
    private static func createTreeItemStatusListView(navState: SwiftNavigationState) -> StatusListView<SwiftTreeItem> {
        let title = navState.getTitle()

        let columns = [
            StatusListColumn<SwiftTreeItem>(
                header: "Name",
                width: 50,
                getValue: { $0.displayName }
            ),
            StatusListColumn<SwiftTreeItem>(
                header: "Size",
                width: 15,
                getValue: { $0.sizeDisplay },
                getStyle: { _ in .accent }
            ),
            StatusListColumn<SwiftTreeItem>(
                header: "Type",
                width: 20,
                getValue: {
                    switch $0 {
                    case .directory(_, let count, _):
                        return "Directory (\(count) items)"
                    case .object(let obj):
                        return obj.contentType ?? "Unknown"
                    }
                },
                getStyle: { item in
                    item.isDirectory ? .info : .secondary
                }
            ),
            StatusListColumn<SwiftTreeItem>(
                header: "Last Modified",
                width: 20,
                getValue: { item in
                    if let date = item.lastModified {
                        return date.formatted(date: .abbreviated, time: .shortened)
                    } else {
                        return "-"
                    }
                }
            )
        ]

        return StatusListView(
            title: title,
            columns: columns,
            getStatusIcon: { item in
                item.statusIcon
            },
            filterItems: { items, query in
                guard let query = query, !query.isEmpty else { return items }
                return SwiftTreeItem.filterItems(items, query: query)
            },
            getItemID: { $0.id }
        )
    }

    // MARK: - Container Metadata View

    @MainActor
    static func drawSwiftContainerMetadata(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Set Container Metadata",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit | ENTER: Save | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - Object Metadata View

    @MainActor
    static func drawSwiftObjectMetadata(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Set Object Metadata",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit | ENTER: Save | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - Directory Metadata View

    @MainActor
    static func drawSwiftDirectoryMetadata(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Set Directory Metadata",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit/Toggle | ENTER: Apply to All | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - Object Upload View

    @MainActor
    static func drawSwiftObjectUpload(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Upload Object to Container",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit | ENTER: Upload | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - Object Download View

    @MainActor
    static func drawSwiftContainerDownload(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Download Container",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit | ENTER: Download | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    @MainActor
    static func drawSwiftObjectDownload(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Download Object",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit | ENTER: Download | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    @MainActor
    static func drawSwiftDirectoryDownload(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formBuilderState: FormBuilderState
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Download Directory",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit/Toggle | ENTER: Download | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

}
