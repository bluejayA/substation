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
        searchQuery: String,
        scrollOffset: Int,
        selectedIndex: Int,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        let statusListView = createObjectStatusListView(containerName: containerName)
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: objects,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
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

        // Access Control Section
        if let metadata = metadata {
            var aclItems: [DetailItem?] = []

            if let readACL = metadata.readACL {
                aclItems.append(.field(label: "Read ACL", value: readACL, style: .secondary))
            } else {
                aclItems.append(.field(label: "Read ACL", value: "None (private)", style: .muted))
            }

            if let writeACL = metadata.writeACL {
                aclItems.append(.field(label: "Write ACL", value: writeACL, style: .secondary))
            } else {
                aclItems.append(.field(label: "Write ACL", value: "None (private)", style: .muted))
            }

            if let aclSection = DetailView.buildSection(title: "Access Control", items: aclItems, titleStyle: .accent) {
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
                width: 30,
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
    private static func createObjectStatusListView(containerName: String) -> StatusListView<SwiftObject> {
        let columns = [
            StatusListColumn<SwiftObject>(
                header: "Object Name",
                width: 40,
                getValue: { $0.fileName }
            ),
            StatusListColumn<SwiftObject>(
                header: "Size",
                width: 15,
                getValue: { $0.formattedSize },
                getStyle: { _ in .accent }
            ),
            StatusListColumn<SwiftObject>(
                header: "Content Type",
                width: 20,
                getValue: { $0.contentType ?? "Unknown" },
                getStyle: { _ in .secondary }
            ),
            StatusListColumn<SwiftObject>(
                header: "Last Modified",
                width: 20,
                getValue: { object in
                    object.lastModified?.formatted(date: .abbreviated, time: .shortened) ?? "N/A"
                }
            )
        ]

        return StatusListView(
            title: "Objects in Container: \(containerName)",
            columns: columns,
            getStatusIcon: { object in
                object.isLargeObject ? "[L]" : "[O]"
            },
            filterItems: { objects, query in
                guard let query = query, !query.isEmpty else { return objects }
                return objects.filter { $0.name?.localizedCaseInsensitiveContains(query) ?? false }
            },
            getItemID: { $0.id }
        )
    }

    // MARK: - Helper Functions

    static func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let tb = gb * 1024.0

        let size = Double(bytes)

        if size >= tb {
            return String(format: "%.2f TB", size / tb)
        } else if size >= gb {
            return String(format: "%.2f GB", size / gb)
        } else if size >= mb {
            return String(format: "%.2f MB", size / mb)
        } else if size >= kb {
            return String(format: "%.2f KB", size / kb)
        } else {
            return "\(bytes) B"
        }
    }
}
