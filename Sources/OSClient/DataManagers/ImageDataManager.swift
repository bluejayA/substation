import Foundation
import MemoryKit

/// Data manager for image-related operations with MemoryKit integration
public actor ImageDataManager {
    private let glanceService: GlanceService
    private let logger: any OpenStackClientLogger
    private let memoryManager: MemoryManager

    public init(glanceService: GlanceService, logger: any OpenStackClientLogger, memoryManager: MemoryManager) {
        self.glanceService = glanceService
        self.logger = logger
        self.memoryManager = memoryManager
    }

    // MARK: - Image Operations

    /// List all images with caching (Glance format)
    public func listImages(forceRefresh: Bool = false) async throws -> [Image] {
        let cacheKey = "image_list"

        if !forceRefresh {
            if let cachedImages = await memoryManager.retrieve(forKey: cacheKey, as: [Image].self) {
                return cachedImages
            }
        }

        let images = try await glanceService.listImages()
        await memoryManager.store(images, forKey:cacheKey)

        for image in images {
            await memoryManager.store(image, forKey:"image_\(image.id)")
        }

        return images
    }

    /// Get a specific image with caching
    public func getImage(id: String, forceRefresh: Bool = false) async throws -> Image {
        let cacheKey = "image_\(id)"

        if !forceRefresh {
            if let cachedImage = await memoryManager.retrieve(forKey: cacheKey, as: Image.self) {
                return cachedImage
            }
        }

        let image = try await glanceService.getImage(id: id)
        await memoryManager.store(image, forKey:cacheKey)
        return image
    }

    /// Create a new image (placeholder - not fully implemented)
    public func createImage(name: String) async throws -> Image {
        // This would need a proper CreateImageRequest implementation
        // For now, just throw an error to indicate not implemented
        throw OpenStackError.authenticationFailed // Using an existing error as placeholder
    }

    /// Delete an image
    public func deleteImage(id: String) async throws {
        try await glanceService.deleteImage(id: id)
        await memoryManager.clearKey( "image_\(id)")
        await memoryManager.clearKey( "image_list")
    }

    // MARK: - Helper Methods

    /// Convert a Glance image to Nova image format
    private func convertImageToNovaImage(_ glanceImage: Image) -> Image {
        return Image(
            id: glanceImage.id,
            name: glanceImage.name,
            status: glanceImage.status,
            progress: nil,
            minRam: glanceImage.minRam,
            minDisk: glanceImage.minDisk,
            visibility: glanceImage.visibility,
            size: glanceImage.size,
            createdAt: glanceImage.createdAt,
            updatedAt: glanceImage.updatedAt,
            metadata: glanceImage.properties,
            server: nil,
            links: nil
        )
    }

    // MARK: - Cache Management

    /// Clear all cached data
    public func clearCache() async {
        await memoryManager.clearAll()
    }

    /// Get memory usage statistics
    public func getMemoryStats() async -> MemoryMetrics {
        return await memoryManager.getMetrics()
    }

    /// Handle memory pressure by clearing cache
    public func handleMemoryPressure() async {
        await clearCache()
    }
}