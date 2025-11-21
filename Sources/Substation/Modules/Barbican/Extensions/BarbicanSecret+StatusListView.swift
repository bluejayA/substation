import Foundation
import OSClient
import SwiftNCurses

extension BarbicanViews {
    @MainActor
    static func createBarbicanSecretStatusListView() -> StatusListView<Secret> {
        return StatusListView<Secret>(
            title: "Secrets",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 20,
                    getValue: { secret in
                        secret.name ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "TYPE",
                    width: 12,
                    getValue: { secret in
                        secret.secretType ?? "opaque"
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 10,
                    getValue: { secret in
                        secret.status ?? "Unknown"
                    },
                    getStyle: { secret in
                        switch (secret.status ?? "Unknown").lowercased() {
                        case "active": return .success
                        case "error": return .error
                        case "build", "building": return .warning
                        default: return .info
                        }
                    }
                ),
                StatusListColumn(
                    header: "CREATED",
                    width: 16,
                    getValue: { secret in
                        if let created = secret.created {
                            return created.shortFormatted()
                        }
                        return "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "EXPIRATION",
                    width: 16,
                    getValue: { secret in
                        if let expiration = secret.expiration {
                            return expiration.shortFormatted()
                        }
                        return "Never"
                    },
                    getStyle: { secret in
                        if let expiration = secret.expiration {
                            return expiration < Date() ? .error : .warning
                        }
                        return .success
                    }
                )
            ],
            getStatusIcon: { secret in
                secret.status ?? "unknown"
            },
            filterItems: { secrets, query in
                guard let query = query, !query.isEmpty else { return secrets }
                return secrets.filter { secret in
                    (secret.name?.lowercased().contains(query.lowercased()) ?? false) ||
                    (secret.secretType?.lowercased().contains(query.lowercased()) ?? false)
                }
            }
        )
    }
}
