import Foundation
import OSClient

/// Cache operations coordinator
///
/// Provides cache clearing operations for the TUI.
/// Resource data is accessed through modules or CacheManager.
@MainActor
final class TUIResourceCache {
    private let resourceCache: OpenStackResourceCache

    init(resourceCache: OpenStackResourceCache) {
        self.resourceCache = resourceCache
    }

    // MARK: - Recommendations

    /// Set the recommendations refresh time
    ///
    /// - Parameter date: The refresh date
    func setRecommendationsRefreshTime(_ date: Date) {
        resourceCache.setRecommendationsRefreshTime(date)
    }

    // MARK: - Cache Operations

    /// Clear all cached resources
    func clearAll() async {
        await resourceCache.clearAll()
    }
}
