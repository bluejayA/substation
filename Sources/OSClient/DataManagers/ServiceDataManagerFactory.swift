import Foundation
import MemoryKit

/// Factory for creating service-specific data managers with optimized caching and memory management
public actor ServiceDataManagerFactory {
    private let logger: any OpenStackClientLogger
    private let memoryManager: MemoryManager

    public init(logger: any OpenStackClientLogger, memoryManager: MemoryManager) {
        self.logger = logger
        self.memoryManager = memoryManager
    }

    /// Create a server data manager with optimized caching
    public func createServerDataManager(novaService: NovaService) -> ServerDataManager {
        return ServerDataManager(novaService: novaService, logger: logger, memoryManager: memoryManager)
    }

    /// Create a network data manager with optimized caching
    public func createNetworkDataManager(neutronService: NeutronService) -> NetworkDataManager {
        return NetworkDataManager(neutronService: neutronService, logger: logger, memoryManager: memoryManager)
    }

    /// Create a volume data manager with optimized caching
    public func createVolumeDataManager(cinderService: CinderService) -> VolumeDataManager {
        return VolumeDataManager(cinderService: cinderService, logger: logger, memoryManager: memoryManager)
    }

    /// Create an image data manager with optimized caching
    public func createImageDataManager(glanceService: GlanceService) -> ImageDataManager {
        return ImageDataManager(glanceService: glanceService, logger: logger, memoryManager: memoryManager)
    }
}