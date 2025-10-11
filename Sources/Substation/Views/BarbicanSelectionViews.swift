import Foundation
import SwiftTUI

struct BarbicanContentTypeSelectionView {
    @MainActor
    static func drawContentTypeSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        contentTypes: [SecretPayloadContentTypeWrapper],
        selectedIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        title: String = "Select Payload Content Type"
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let tabs = [
            FormSelectorTab<SecretPayloadContentTypeWrapper>(
                title: "Content Types",
                columns: [
                    FormSelectorColumn(header: "TYPE", width: 60) { wrapper in
                        wrapper.type.title.padding(toLength: 60, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]
        let selector = FormSelector(
            label: title, tabs: tabs, selectedTabIndex: 0, items: contentTypes,
            selectedItemIds: selectedIds, highlightedIndex: highlightedIndex, checkboxMode: .basic,
            scrollOffset: scrollOffset, searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width), maxHeight: Int(height), isActive: true
        )
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}

struct BarbicanEncodingSelectionView {
    @MainActor
    static func drawEncodingSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        encodings: [SecretPayloadContentEncodingWrapper],
        selectedIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        title: String = "Select Payload Content Encoding"
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let tabs = [
            FormSelectorTab<SecretPayloadContentEncodingWrapper>(
                title: "Encodings",
                columns: [
                    FormSelectorColumn(header: "ENCODING", width: 60) { wrapper in
                        wrapper.type.title.padding(toLength: 60, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]
        let selector = FormSelector(
            label: title, tabs: tabs, selectedTabIndex: 0, items: encodings,
            selectedItemIds: selectedIds, highlightedIndex: highlightedIndex, checkboxMode: .basic,
            scrollOffset: scrollOffset, searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width), maxHeight: Int(height), isActive: true
        )
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}

struct BarbicanSecretTypeSelectionView {
    @MainActor
    static func drawSecretTypeSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        secretTypes: [SecretTypeWrapper],
        selectedIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        title: String = "Select Secret Type"
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let tabs = [
            FormSelectorTab<SecretTypeWrapper>(
                title: "Secret Types",
                columns: [
                    FormSelectorColumn(header: "TYPE", width: 60) { wrapper in
                        wrapper.type.title.padding(toLength: 60, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]
        let selector = FormSelector(
            label: title, tabs: tabs, selectedTabIndex: 0, items: secretTypes,
            selectedItemIds: selectedIds, highlightedIndex: highlightedIndex, checkboxMode: .basic,
            scrollOffset: scrollOffset, searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width), maxHeight: Int(height), isActive: true
        )
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}

struct BarbicanAlgorithmSelectionView {
    @MainActor
    static func drawAlgorithmSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        algorithms: [SecretAlgorithmWrapper],
        selectedIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        title: String = "Select Algorithm"
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let tabs = [
            FormSelectorTab<SecretAlgorithmWrapper>(
                title: "Algorithms",
                columns: [
                    FormSelectorColumn(header: "ALGORITHM", width: 60) { wrapper in
                        wrapper.type.title.padding(toLength: 60, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]
        let selector = FormSelector(
            label: title, tabs: tabs, selectedTabIndex: 0, items: algorithms,
            selectedItemIds: selectedIds, highlightedIndex: highlightedIndex, checkboxMode: .basic,
            scrollOffset: scrollOffset, searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width), maxHeight: Int(height), isActive: true
        )
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}

struct BarbicanModeSelectionView {
    @MainActor
    static func drawModeSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        modes: [SecretModeWrapper],
        selectedIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        title: String = "Select Mode"
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let tabs = [
            FormSelectorTab<SecretModeWrapper>(
                title: "Modes",
                columns: [
                    FormSelectorColumn(header: "MODE", width: 60) { wrapper in
                        wrapper.type.title.padding(toLength: 60, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]
        let selector = FormSelector(
            label: title, tabs: tabs, selectedTabIndex: 0, items: modes,
            selectedItemIds: selectedIds, highlightedIndex: highlightedIndex, checkboxMode: .basic,
            scrollOffset: scrollOffset, searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width), maxHeight: Int(height), isActive: true
        )
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}

struct BarbicanBitLengthSelectionView {
    @MainActor
    static func drawBitLengthSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        bitLengths: [BitLengthOption],
        selectedIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        title: String = "Select Bit Length"
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let tabs = [
            FormSelectorTab<BitLengthOption>(
                title: "Bit Lengths",
                columns: [
                    FormSelectorColumn(header: "BIT LENGTH", width: 60) { option in
                        "\(option.value) bits".padding(toLength: 60, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]
        let selector = FormSelector(
            label: title, tabs: tabs, selectedTabIndex: 0, items: bitLengths,
            selectedItemIds: selectedIds, highlightedIndex: highlightedIndex, checkboxMode: .basic,
            scrollOffset: scrollOffset, searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width), maxHeight: Int(height), isActive: true
        )
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}
