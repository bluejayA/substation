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

    /// Dynamic navigation context based on current mode and state
    var flavorSelectionNavigationContext: NavigationContext {
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
            maxIndex = max(0, filteredFlavors.count - 1)
        case .workloadBased:
            if serverCreateForm.selectedCategoryIndex != nil {
                maxIndex = max(0, 3 - 1)
            } else {
                let categories = WorkloadCategoryHelpers.generateFilteredWorkloadTypes(from: cachedFlavors)
                maxIndex = max(0, categories.count - 1)
            }
        }
        return .list(maxIndex: maxIndex)
    }

    internal func handleFlavorSelectionInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .flavorSelection else { return }

        // Step 1: Try common navigation (context-aware)
        if await handleFlavorSelectionNavigation(ch, screen: screen) {
            await self.draw(screen: screen)
            return
        }

        // Step 2: Handle ESC with custom logic
        if ch == Int32(27) {
            if await handleFlavorSelectionEscape(screen: screen) {
                await self.draw(screen: screen)
                return
            }
        }

        // Step 3: Handle view-specific keys
        await handleFlavorSelectionSpecificInput(ch, screen: screen)
    }

    /// Handle common navigation using context-aware navigation
    private func handleFlavorSelectionNavigation(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        let context = flavorSelectionNavigationContext
        switch context {
        case .list(let maxIndex):
            return await NavigationInputHandler.handleListNavigation(ch, maxIndex: maxIndex, tui: self)
        default:
            return false
        }
    }

    /// Handle ESC with multi-level navigation
    private func handleFlavorSelectionEscape(screen: OpaquePointer?) async -> Bool {
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
            return true
        } else {
            // Return to server create view
            changeView(to: .serverCreate, resetSelection: false)
            return true
        }
    }

    /// Handle view-specific input (mode switching and special behavior)
    private func handleFlavorSelectionSpecificInput(_ ch: Int32, screen: OpaquePointer?) async {
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

        case Int32(32): // SPACE - Select flavor or drill into category (context-dependent)
            await handleFlavorSelectionSpace(screen: screen)

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

        default:
            break
        }
    }

    /// Handle SPACE key behavior based on mode and state
    private func handleFlavorSelectionSpace(screen: OpaquePointer?) async {
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
    }
}
