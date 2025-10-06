import Foundation
import OSClient
import SwiftTUI

extension KeyPairViews {
    @MainActor
    static func createKeyPairStatusListView() -> StatusListView<KeyPair> {
        return StatusListView<KeyPair>(
            title: "Key Pairs",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 30,
                    getValue: { keyPair in
                        keyPair.name ?? "Unnamed"
                    }
                ),
                StatusListColumn(
                    header: "FINGERPRINT",
                    width: 50,
                    getValue: { keyPair in
                        if let fingerprint = keyPair.fingerprint {
                            return fingerprint.count > 50 ? String(fingerprint.suffix(50)) : fingerprint
                        }
                        return "Unknown"
                    }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { keyPairs, query in
                FilterUtils.filterKeyPairs(keyPairs, query: query)
            }
        )
    }
}
