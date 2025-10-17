import Foundation
import OSClient
import SwiftNCurses

struct VolumeBackupManagementView {
    // Text Constants
    private static let unnamedVolumeText = "Unnamed Volume"
    private static let errorPrefix = "Error: "
    private static let noVolumeSelectedError = "No volume selected"
    private static let loadingMessage = "Creating volume backup..."
    private static let createBackupTitle = "Create Volume Backup - "

    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: VolumeBackupManagementForm,
        formBuilderState: FormBuilderState
    ) async {
        await BaseViewComponents.clearArea(
            screen: screen,
            startRow: startRow - 1,
            startCol: startCol,
            width: width,
            height: height
        )

        guard let volume = form.selectedVolume else {
            let surface = SwiftNCurses.surface(from: screen)
            let errorBounds = Rect(x: startCol + 2, y: startRow + 2, width: 30, height: 1)
            await SwiftNCurses.render(
                Text("\(Self.errorPrefix)\(Self.noVolumeSelectedError)").error(),
                on: surface,
                in: errorBounds
            )
            return
        }

        // Loading indicator
        if form.isLoading {
            let surface = SwiftNCurses.surface(from: screen)
            let loadingBounds = Rect(x: startCol + 2, y: startRow + 2, width: 30, height: 1)
            await SwiftNCurses.render(Text(Self.loadingMessage).info(), on: surface, in: loadingBounds)
            return
        }

        // Build header info text
        let volumeName = volume.name ?? Self.unnamedVolumeText
        let headerText = "\(Self.createBackupTitle)\(volumeName)"

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

        // Display error or success message if present
        var messageRow = startRow
        if let errorMessage = form.errorMessage {
            let errorBounds = Rect(x: startCol + 2, y: messageRow, width: Int32(errorMessage.count + 10), height: 1)
            await SwiftNCurses.render(Text("\(Self.errorPrefix)\(errorMessage)").error(), on: surface, in: errorBounds)
            messageRow += 2
        }

        if let successMessage = form.successMessage {
            let successBounds = Rect(x: startCol + 2, y: messageRow, width: Int32(successMessage.count + 10), height: 1)
            await SwiftNCurses.render(Text("Success: \(successMessage)").success(), on: surface, in: successBounds)
            messageRow += 2
        }

        // Render the form
        let formRenderBounds = Rect(x: startCol, y: messageRow, width: width, height: height - (messageRow - startRow))
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: formRenderBounds)
    }
}
