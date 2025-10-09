import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
import MemoryKit

// MARK: - Flavor Selection Input Handler

@MainActor
extension TUI {

    internal func handleFlavorSelectionInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .flavorSelection else { return }

        switch ch {
        case Int32(9): // TAB - Switch between manual and workload-based modes
            serverCreateForm.toggleFlavorSelectionMode()
            serverCreateForm.selectedCategoryIndex = nil
            selectedIndex = 0
            scrollOffset = 0
            // Clear only the main panel area to remove artifacts before redrawing
            if let screen = screen {
                let surface = SwiftTUI.surface(from: screen)
                let sidebarWidth = LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols)
                let mainStartCol = sidebarWidth + 1
                let mainStartRow: Int32 = 2
                let mainWidth = max(10, screenCols - mainStartCol - 1)
                let mainHeight = max(5, screenRows - mainStartRow - 2)
                let mainBounds = Rect(x: mainStartCol, y: mainStartRow, width: mainWidth, height: mainHeight)
                await surface.fill(rect: mainBounds, character: " ", style: .secondary)
                SwiftTUI.refresh(WindowHandle(screen))
            }
            await self.draw(screen: screen)

        case Int32(32): // SPACE - Select flavor or drill into category
            switch serverCreateForm.flavorSelectionMode {
            case .manual:
                // Select the highlighted flavor
                let filteredFlavors: [Flavor]
                if let query = searchQuery, !query.isEmpty {
                    filteredFlavors = cachedFlavors.filter {
                        ($0.name?.localizedCaseInsensitiveContains(query) ?? false)
                    }.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
                } else {
                    filteredFlavors = cachedFlavors.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
                }
                if selectedIndex < filteredFlavors.count {
                    let selectedFlavor = filteredFlavors[selectedIndex]
                    serverCreateForm.selectedFlavorID = selectedFlavor.id
                }
            case .workloadBased:
                if serverCreateForm.selectedCategoryIndex == nil {
                    // In category list view - drill into the selected category
                    serverCreateForm.selectedCategoryIndex = selectedIndex
                    selectedIndex = 0
                    scrollOffset = 0
                    // Clear only the main panel area to remove artifacts before redrawing
                    if let screen = screen {
                        let surface = SwiftTUI.surface(from: screen)
                        let sidebarWidth = LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols)
                        let mainStartCol = sidebarWidth + 1
                        let mainStartRow: Int32 = 2
                        let mainWidth = max(10, screenCols - mainStartCol - 1)
                        let mainHeight = max(5, screenRows - mainStartRow - 2)
                        let mainBounds = Rect(x: mainStartCol, y: mainStartRow, width: mainWidth, height: mainHeight)
                        await surface.fill(rect: mainBounds, character: " ", style: .secondary)
                        SwiftTUI.refresh(WindowHandle(screen))
                    }
                } else {
                    // In category detail view - toggle selection of the highlighted flavor
                    // Use shared helper to generate filtered categories (matching view logic)
                    let categories = WorkloadCategoryHelpers.generateFilteredWorkloadTypes(from: cachedFlavors)

                    if let categoryIdx = serverCreateForm.selectedCategoryIndex, categoryIdx < categories.count {
                        let workloadType = categories[categoryIdx]
                        // Generate top 3 flavors for this category
                        let sortedFlavors = WorkloadCategoryHelpers.selectTopFlavorsForWorkload(cachedFlavors, workloadType: workloadType, count: 3)

                        if selectedIndex < sortedFlavors.count {
                            let selectedFlavor = sortedFlavors[selectedIndex]
                            // Toggle selection
                            if serverCreateForm.selectedFlavorID == selectedFlavor.id {
                                serverCreateForm.selectedFlavorID = nil
                            } else {
                                serverCreateForm.selectedFlavorID = selectedFlavor.id
                            }
                        }
                    }
                }
            }
            await self.draw(screen: screen)

        case Int32(10), Int32(13): // ENTER - Confirm selection and return
            needsRedraw = true
            switch serverCreateForm.flavorSelectionMode {
            case .manual:
                // Only allow confirmation if a flavor has been selected
                if serverCreateForm.selectedFlavorID != nil {
                    serverCreateForm.exitFlavorSelection()
                    changeView(to: .serverCreate, resetSelection: false)
                    await self.draw(screen: screen)
                }
            case .workloadBased:
                if serverCreateForm.selectedCategoryIndex != nil {
                    // In category detail view - confirm selection if a flavor has been selected
                    if serverCreateForm.selectedFlavorID != nil {
                        serverCreateForm.exitFlavorSelection()
                        changeView(to: .serverCreate, resetSelection: false)
                        await self.draw(screen: screen)
                    }
                } else {
                    // In category list view - do nothing on ENTER
                    break
                }
            }

        case Int32(27): // ESC - Cancel and return or go back to category list
            if serverCreateForm.flavorSelectionMode == .workloadBased && serverCreateForm.selectedCategoryIndex != nil {
                // In category detail view - go back to category list
                serverCreateForm.selectedCategoryIndex = nil
                selectedIndex = 0
                scrollOffset = 0
                // Clear only the main panel area to remove artifacts before redrawing
                if let screen = screen {
                    let surface = SwiftTUI.surface(from: screen)
                    let sidebarWidth = LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols)
                    let mainStartCol = sidebarWidth + 1
                    let mainStartRow: Int32 = 2
                    let mainWidth = max(10, screenCols - mainStartCol - 1)
                    let mainHeight = max(5, screenRows - mainStartRow - 2)
                    let mainBounds = Rect(x: mainStartCol, y: mainStartRow, width: mainWidth, height: mainHeight)
                    await surface.fill(rect: mainBounds, character: " ", style: .secondary)
                    SwiftTUI.refresh(WindowHandle(screen))
                }
                await self.draw(screen: screen)
            } else {
                // Return to server create view
                changeView(to: .serverCreate, resetSelection: false)
                await self.draw(screen: screen)
            }

        case 258: // DOWN - Navigate down
            let maxIndex: Int
            switch serverCreateForm.flavorSelectionMode {
            case .manual:
                let filteredFlavors: [Flavor]
                if let query = searchQuery, !query.isEmpty {
                    filteredFlavors = cachedFlavors.filter {
                        ($0.name?.localizedCaseInsensitiveContains(query) ?? false)
                    }.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
                } else {
                    filteredFlavors = cachedFlavors.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
                }
                maxIndex = filteredFlavors.count
            case .workloadBased:
                if serverCreateForm.selectedCategoryIndex != nil {
                    // In category detail view - 3 flavors max
                    maxIndex = 3
                } else {
                    // In category list view - use shared helper to count categories with flavors
                    let categories = WorkloadCategoryHelpers.generateFilteredWorkloadTypes(from: cachedFlavors)
                    maxIndex = categories.count
                }
            }

            if selectedIndex < maxIndex - 1 {
                selectedIndex += 1
                // Auto-scroll if needed
                if selectedIndex >= scrollOffset + 10 {
                    scrollOffset = selectedIndex - 9
                }
                await self.draw(screen: screen)
            }

        case 259: // UP - Navigate up
            if selectedIndex > 0 {
                selectedIndex -= 1
                // Auto-scroll if needed
                if selectedIndex < scrollOffset {
                    scrollOffset = selectedIndex
                }
                await self.draw(screen: screen)
            }

        default:
            // Handle search input
            if ch >= 32 && ch < 127 {
                let character = Character(UnicodeScalar(Int(ch))!)
                if searchQuery == nil {
                    searchQuery = String(character)
                } else {
                    searchQuery! += String(character)
                }
                selectedIndex = 0
                scrollOffset = 0
                await self.draw(screen: screen)
            } else if ch == 127 || ch == 8 { // BACKSPACE
                if let query = searchQuery, !query.isEmpty {
                    searchQuery = String(query.dropLast())
                    if searchQuery!.isEmpty {
                        searchQuery = nil
                    }
                    selectedIndex = 0
                    scrollOffset = 0
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
