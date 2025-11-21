import Foundation
import OSClient
import SwiftNCurses

struct SnapshotManagementView {
    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: SnapshotManagementForm,
        formBuilderState: FormBuilderState
    ) async {
        await BaseViewComponents.clearArea(
            screen: screen,
            startRow: startRow - 1,
            startCol: startCol,
            width: width,
            height: height
        )

        guard let server = form.selectedServer else {
            let surface = SwiftNCurses.surface(from: screen)
            let errorBounds = Rect(x: startCol + 2, y: startRow + 2, width: 30, height: 1)
            await SwiftNCurses.render(
                Text("Error: No server selected").error(),
                on: surface,
                in: errorBounds
            )
            return
        }

        // Build header info text
        let serverText = "Server: \(server.name ?? "Unknown")"
        let statusText = server.status != nil ? " | Status: \(server.status!)" : ""
        let headerText = "Create Server Snapshot - \(serverText)\(statusText)"

        // Build form fields with state
        let fields = form.buildFields(
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            activeFieldId: formBuilderState.getActiveFieldId(),
            formState: formBuilderState
        )

        let formBuilder = FormBuilder(
            title: headerText,
            fields: fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        let surface = SwiftNCurses.surface(from: screen)
        let formBounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: formBounds)
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: formBounds)
    }

    @MainActor
    static func drawServerSnapshotManagement(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: SnapshotManagementForm,
        formBuilderState: FormBuilderState
    ) async {
        await draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            form: form,
            formBuilderState: formBuilderState
        )
    }
}
