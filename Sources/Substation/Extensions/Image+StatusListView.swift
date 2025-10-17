import Foundation
import OSClient
import SwiftNCurses

extension ImageViews {
    @MainActor
    static func createImageStatusListView() -> StatusListView<Image> {
        return StatusListView<Image>(
            title: "Images",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 28,
                    getValue: { image in
                        image.name ?? "Unnamed"
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 20,
                    getValue: { image in
                        image.status ?? "Unknown"
                    },
                    getStyle: { image in
                        let status = image.status ?? "Unknown"
                        switch status.lowercased() {
                        case "active": return .success
                        case let s where s.contains("error"): return .error
                        default: return .accent
                        }
                    }
                ),
                StatusListColumn(
                    header: "VISIBILITY",
                    width: 12,
                    getValue: { image in
                        image.visibility ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "SIZE",
                    width: 10,
                    getValue: { image in
                        if let size = image.size {
                            let sizeGB = Double(size) / 1_073_741_824.0
                            return String(format: "%.2f GB", sizeGB)
                        }
                        return "Unknown"
                    }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { images, query in
                FilterUtils.filterImages(images, query: query)
            },
            getItemID: { image in image.id }
        )
    }
}
